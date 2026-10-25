import Foundation

/// Runner discovery order. Weights live here so the ranking can be tested without a view.
enum RequestRanking {
    static let holdSeconds: TimeInterval = 15 * 60

    struct Weights: Equatable {
        var route = 0.35
        var effort = 0.20
        var window = 0.15
        var handling = 0.10
        var payout = 0.10
        var freshness = 0.10
    }

    static let weights = Weights()

    struct Origin: Equatable {
        var lat: Double
        var lng: Double
        var label: String
        /// "device" or "manual". Never describe a manual pin as the runner's GPS location.
        var source: String
    }

    static func latest(_ orders: [Order]) -> [Order] {
        orders.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.id > rhs.id
        }
    }

    static func closest(_ orders: [Order], origin: Origin?) -> [Order] {
        guard let origin else { return latest(orders) }
        return orders.sorted { lhs, rhs in
            let left = geographicMeters(origin.lat, origin.lng, lhs.restaurantLat, lhs.restaurantLng)
            let right = geographicMeters(origin.lat, origin.lng, rhs.restaurantLat, rhs.restaurantLng)
            if left != right { return left < right }
            return lhs.id < rhs.id
        }
    }

    /// Higher score is a better fit. Ineligible rows must already be removed.
    static func recommended(_ orders: [Order], origin: Origin?, area: String, now: Date) -> [Order] {
        orders.sorted { lhs, rhs in
            let left = score(lhs, origin: origin, area: area, now: now)
            let right = score(rhs, origin: origin, area: area, now: now)
            if left != right { return left > right }
            return lhs.id < rhs.id
        }
    }

    static func score(_ order: Order, origin: Origin?, area: String, now: Date) -> Double {
        let route = (order.pickupCity ?? "").caseInsensitiveCompare(area) == .orderedSame ? 1.0 : 0.35
        let meters = origin.map { geographicMeters($0.lat, $0.lng, order.restaurantLat, order.restaurantLng) } ?? 50_000
        let effort = 1 / (1 + meters / 10_000)
        let window = (order.pickupWindowLabel?.isEmpty == false) ? 1.0 : 0.4
        let pounds = order.weightPounds ?? 8
        let handling = pounds <= 25 && order.bulkyItem != true ? 1.0 : 0.45
        let payoutCents = Double(order.offerShareCents ?? order.runnerShareCents ?? 400)
        let payout = min(1, (payoutCents / max(meters, 500)) / 0.05)
        let age = max(0, now.timeIntervalSince(Format.parse(order.createdAt) ?? now))
        let freshness = 1 / (1 + age / 3_600)
        return weights.route * route
            + weights.effort * effort
            + weights.window * window
            + weights.handling * handling
            + weights.payout * payout
            + weights.freshness * freshness
    }

    static func geographicMeters(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let earth = 6_371_000.0
        let p1 = lat1 * .pi / 180
        let p2 = lat2 * .pi / 180
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(p1) * cos(p2) * sin(dLng / 2) * sin(dLng / 2)
        return earth * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Extra distance versus an already committed origin-to-dropoff line. This is not a driving route.
    static func incrementalMeters(originLat: Double, originLng: Double, pickupLat: Double, pickupLng: Double, dropoffLat: Double, dropoffLng: Double) -> Double {
        let direct = geographicMeters(originLat, originLng, dropoffLat, dropoffLng)
        let via = geographicMeters(originLat, originLng, pickupLat, pickupLng) + geographicMeters(pickupLat, pickupLng, dropoffLat, dropoffLng)
        return max(0, via - direct)
    }

    /// A named city shows only pickups in that city. A blank filter, or a label that is not a city, shows every open request.
    static func matchesPickupCity(_ order: Order, filter: String) -> Bool {
        guard let place = Places.city(named: filter) else { return true }
        return order.pickupCity?.caseInsensitiveCompare(place.name) == .orderedSame
    }

    static func distanceCaption(kind: String) -> String {
        kind == "road" ? "Road distance" : "Approximate geographic distance, not a driving route"
    }

    struct PayoutPreview: Equatable {
        var shareCents: Int
        var customerCents: Int
        var meters: Double
        var seconds: Double
        var caption: String
    }

    /// Short local pickup used before a runner's location is known. Not the intercity drive.
    static let preliminaryMeters = 2 * 1_609.344
    static let preliminarySeconds = 8 * 60.0

    static func quoted(meters: Double, seconds: Double, pounds: Double, bulky: Bool) -> (share: Int, customer: Int)? {
        let capped = min(max(pounds, 0), 50)
        guard case .quoted(let quote) = PricingPolicy.evaluate(.init(
            extraMeters: max(0, meters),
            extraSeconds: min(max(0, seconds), 29 * 60),
            weightPounds: capped,
            weightConfirmed: true,
            bulky: bulky,
            agreedWaitingMinutes: 0
        )) else { return nil }
        return (quote.runnerShareCents, quote.totalCents)
    }

    /// A runner-facing estimate that always has a dollar amount. It is not a locked fee.
    static func payoutPreview(_ order: Order, origin: Origin?) -> PayoutPreview {
        let fromRunner = origin != nil
        let raw: Double
        if let origin {
            raw = incrementalMeters(
                originLat: origin.lat, originLng: origin.lng,
                pickupLat: order.restaurantLat, pickupLng: order.restaurantLng,
                dropoffLat: order.destinationLat, dropoffLng: order.destinationLng
            )
        } else {
            raw = preliminaryMeters
        }
        let meters = max(raw, 0)
        let seconds = min(fromRunner ? meters / 12 : preliminarySeconds, 29 * 60)
        let assumed = order.weightPounds == nil
        let pounds = min(max(order.weightPounds ?? 8, 0), 50)
        let priced = quoted(meters: meters, seconds: seconds, pounds: pounds, bulky: order.bulkyItem == true)
        let share = priced?.share ?? PricingPolicy.stopCents
        let customer = priced?.customer ?? PricingPolicy.markedUp(share)
        var caption = fromRunner
            ? "Estimated from the extra distance off your route. Approximate geographic distance, not a driving route."
            : "Preliminary estimate for a short local pickup. Your location is not included."
        if assumed { caption += " Assumes about 8 lb." }
        return PayoutPreview(shareCents: share, customerCents: customer, meters: meters, seconds: seconds, caption: caption)
    }
}
