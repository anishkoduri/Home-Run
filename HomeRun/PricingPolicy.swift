import Foundation

/// Authoritative demo delivery fee. Amounts are USD cents. Views display this result; they do not recompute it.
enum PricingPolicy {
    static let version = "demo-2026-10-scale"
    /// Runner's minimum for making the stop, before the 60% scale. The customer pays the scaled amount plus 15%.
    static let stopCents = 200
    /// Runner pay is 60% of the stop, distance, time, weight, and waiting total.
    static let quoteScaleBasisPoints = 6_000
    /// 15% of the runner's time-and-distance amount. Not a flat fee.
    static let markupBasisPoints = 1_500
    static let baseCents = stopCents
    /// Shared-stop discount is defined and kept off. Turning it on would change quoted totals.
    static let sharedStopDiscountCents = 200
    static let sharedStopDiscountEnabled = false

    struct Input: Equatable {
        var extraMeters: Double
        var extraSeconds: Double
        var weightPounds: Double?
        var weightConfirmed: Bool
        var bulky: Bool
        var agreedWaitingMinutes: Int
    }

    struct Quote: Equatable {
        var version: String
        var baseCents: Int
        var routeCents: Int
        var weightCents: Int
        var waitingCents: Int
        var bulkyCents: Int
        var totalCents: Int
        var runnerShareCents: Int

        var dollars: Double { Double(totalCents) / 100 }
    }

    enum Outcome: Equatable {
        case quoted(Quote)
        case manualReview(String)
    }

    static func evaluate(_ input: Input) -> Outcome {
        let meters = max(0, input.extraMeters)
        let seconds = max(0, input.extraSeconds)
        guard input.weightConfirmed, let pounds = input.weightPounds, pounds >= 0, pounds <= 50 else {
            return .manualReview(input.weightPounds.map { $0 > 50 ? "Over 50 lb needs a reviewed price." : "Confirm the weight before a price can be set." } ?? "Confirm the weight before a price can be set.")
        }
        guard input.agreedWaitingMinutes >= 0 else {
            return .manualReview("Waiting time has to be zero or more.")
        }
        if input.extraSeconds > 30 * 60 {
            return .manualReview("More than 30 extra minutes needs a reviewed price.")
        }

        let miles = Decimal(meters) / Decimal(string: "1609.344")!
        let minutes = Decimal(seconds) / 60
        // $0.40 per extra mile and $0.15 per extra minute. This is the detour, not the whole intercity drive.
        let routeCents = halfUp(miles * 40) + halfUp(minutes * 15)
        let weightCents: Int
        if pounds <= 10 { weightCents = 0 }
        else if pounds <= 25 { weightCents = 200 }
        else { weightCents = 400 }
        let extraWait = max(0, input.agreedWaitingMinutes - 5)
        let waitingCents = extraWait * 10
        let bulkyCents = input.bulky ? 400 : 0
        let raw = stopCents + routeCents + weightCents + waitingCents + bulkyCents
        let runner = scaled(raw)
        return .quoted(Quote(
            version: version,
            baseCents: stopCents,
            routeCents: routeCents,
            weightCents: weightCents,
            waitingCents: waitingCents,
            bulkyCents: bulkyCents,
            totalCents: markedUp(runner),
            runnerShareCents: runner
        ))
    }

    /// Sixty percent of a component total, rounded to the nearest cent.
    static func scaled(_ cents: Int) -> Int {
        (max(0, cents) * quoteScaleBasisPoints + 5_000) / 10_000
    }

    /// Customer total is the runner amount plus 15%, rounded to the nearest cent.
    static func markedUp(_ runnerCents: Int) -> Int {
        (max(0, runnerCents) * (10_000 + markupBasisPoints) + 5_000) / 10_000
    }

    static func halfUp(_ value: Decimal) -> Int {
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}

enum DemoClock {
    private static let key = "homerun.demoNow"

    static var now: Date {
        if let stored = UserDefaults.standard.string(forKey: key), let date = Format.parse(stored) {
            return date
        }
        return Date()
    }

    static func advance(by seconds: TimeInterval) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        UserDefaults.standard.set(formatter.string(from: now.addingTimeInterval(seconds)), forKey: key)
    }

    static func chicago(_ days: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let day = calendar.date(byAdding: .day, value: days, to: now) ?? now
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        parts.timeZone = calendar.timeZone
        return calendar.date(from: parts) ?? day
    }
}
