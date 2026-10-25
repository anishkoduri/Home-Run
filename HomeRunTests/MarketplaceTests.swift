import Foundation
import Testing
@testable import HomeRun

struct MarketplaceTests {
    @Test func aRequestCanBePostedWithoutARunner() async throws {
        let db = AppDatabase.testingStore()
        let anish = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let posted: Order = try await send(db, "orders", method: "POST", token: anish.token, body: sample(key: "open-1"))
        #expect(posted.driverId.isEmpty)
        #expect(posted.status == .requested)
        #expect(posted.quoteState == "preliminary")
        let market: [Order] = try await send(db, "orders", token: jordan.token, query: ["role": "available"])
        #expect(market.contains { $0.id == posted.id })
        let own: [Order] = try await send(db, "orders", token: anish.token, query: ["role": "available"])
        #expect(!own.contains { $0.id == posted.id })
    }

    @Test func oneClaimHoldsTheRequestUntilTheCustomerApproves() async throws {
        let db = AppDatabase.testingStore()
        let anish = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let avery = try await signIn(db, email: "avery@demo.local", password: "demo")
        let posted: Order = try await send(db, "orders", method: "POST", token: anish.token, body: sample(key: "open-2"))
        let offer: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": posted.id], body: [
            "offer": "submit",
            "extra_meters": 2_000,
            "extra_seconds": 180,
            "distance_kind": "geographic",
            "incremental": false,
        ])
        #expect(offer.offerRunnerId == "demo-jordan")
        #expect(offer.driverId.isEmpty)
        #expect(offer.quoteCents == nil)
        let blocked = try? await send(db, "orders", method: "PATCH", token: avery.token, query: ["id": posted.id], body: [
            "offer": "submit",
            "extra_meters": 2_000,
            "extra_seconds": 180,
            "distance_kind": "geographic",
        ]) as Order
        #expect(blocked == nil)
        let approved: Order = try await send(db, "orders", method: "PATCH", token: anish.token, query: ["id": posted.id], body: ["offer_decision": "approve"])
        #expect(approved.driverId == "demo-jordan")
        #expect(approved.status == .accepted)
        #expect(approved.feeLockedCents == approved.quoteCents)
        let hidden: [Order] = try await send(db, "orders", token: avery.token, query: ["role": "available"])
        #expect(!hidden.contains { $0.id == posted.id })
    }

    @Test func aRequestCannotNameARunner() async throws {
        let db = AppDatabase.testingStore()
        let anish = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        var body = sample(key: "named-runner")
        body["trip_id"] = "demo-trip-jordan"
        await #expect(throws: APIError.self) {
            let _: Order = try await send(db, "orders", method: "POST", token: anish.token, body: body)
        }
    }

    @Test func aCustomerCannotClaimTheirOwnRequest() async throws {
        let db = AppDatabase.testingStore()
        let anish = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        let posted: Order = try await send(db, "orders", method: "POST", token: anish.token, body: sample(key: "open-3"))
        let claimed = try? await send(db, "orders", method: "PATCH", token: anish.token, query: ["id": posted.id], body: [
            "offer": "submit",
            "extra_meters": 100,
            "extra_seconds": 30,
            "distance_kind": "geographic",
        ]) as Order
        #expect(claimed == nil)
    }

    @Test func incrementalDistanceIsNotTheWholeDrive() {
        let extra = RequestRanking.incrementalMeters(originLat: 29.76, originLng: -95.37, pickupLat: 29.77, pickupLng: -95.38, dropoffLat: 30.62, dropoffLng: -96.34)
        let whole = RequestRanking.geographicMeters(29.76, -95.37, 30.62, -96.34)
        #expect(extra < whole / 2)
        #expect(RequestRanking.distanceCaption(kind: "geographic").contains("not a driving route"))
    }

    @Test func closestUsesGeographicDistanceAndFallsBackWithoutAnOrigin() {
        var near = order("near", created: "2026-10-25T01:00:00Z")
        near.restaurantLat = 29.77
        near.restaurantLng = -95.37
        var far = order("far", created: "2026-10-25T02:00:00Z")
        far.restaurantLat = 32.78
        far.restaurantLng = -96.80
        let origin = RequestRanking.Origin(lat: 29.76, lng: -95.37, label: "Houston", source: "manual")
        #expect(RequestRanking.closest([far, near], origin: origin).map(\.id) == ["near", "far"])
        #expect(RequestRanking.closest([far, near], origin: nil).map(\.id) == ["far", "near"])
    }

    @Test func recommendedPrefersTheSelectedArea() {
        var local = order("local", created: "2026-10-25T01:00:00Z")
        local.pickupCity = "Houston"
        local.restaurantLat = 29.76
        local.restaurantLng = -95.37
        var away = order("away", created: "2026-10-25T01:00:00Z")
        away.pickupCity = "Dallas"
        away.restaurantLat = 32.78
        away.restaurantLng = -96.80
        let origin = RequestRanking.Origin(lat: 29.76, lng: -95.37, label: "Houston", source: "manual")
        let ranked = RequestRanking.recommended([away, local], origin: origin, area: "Houston", now: Date(timeIntervalSince1970: 1_761_000_000))
        #expect(ranked.map(\.id) == ["local", "away"])
        let weights = RequestRanking.weights
        #expect(abs((weights.route + weights.effort + weights.window + weights.handling + weights.payout + weights.freshness) - 1) < 0.001)
    }

    @Test("A city filter shows only pickups from that city", arguments: [
        ("Houston", "demo-open-houston-agas", "demo-open-dallas-traderjoes"),
        ("Dallas", "demo-open-dallas-traderjoes", "demo-open-austin-home"),
        ("Austin", "demo-open-austin-home", "demo-open-houston-agas"),
    ])
    func cityFilterShowsOnlyThatCity(city: String, shown: String, hidden: String) async throws {
        let db = AppDatabase.testingStore()
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let rows: [Order] = try await send(db, "orders", token: jordan.token, query: ["role": "available", "city": city])
        #expect(rows.contains { $0.id == shown })
        #expect(rows.allSatisfy { $0.pickupCity?.caseInsensitiveCompare(city) == .orderedSame })
        #expect(!rows.contains { $0.id == hidden })
    }

    @Test func eachCityHasACoupleOfRequestsAndRunners() async throws {
        let db = AppDatabase.testingStore()
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let trips: [Trip] = try await send(db, "trips", token: jordan.token, query: ["limit": "20"])
        for city in ["Houston", "Dallas", "Austin"] {
            let rows: [Order] = try await send(db, "orders", token: jordan.token, query: ["role": "available", "city": city])
            #expect(rows.count >= 2)
            #expect(rows.allSatisfy { $0.pickupCity?.caseInsensitiveCompare(city) == .orderedSame })
            let runners = Set(trips.filter { $0.originCity == city && $0.status == "scheduled" }.map(\.driverId))
            #expect(runners.count >= 2)
        }
    }

    @Test func anOpenRequestStaysVisibleWhenTheAreaIsNotAPickupCity() async throws {
        let db = AppDatabase.testingStore()
        let anish = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let posted: Order = try await send(db, "orders", method: "POST", token: anish.token, body: sample(key: "open-city"))
        let houston: [Order] = try await send(db, "orders", token: jordan.token, query: ["role": "available", "city": "Houston"])
        #expect(houston.contains { $0.id == posted.id })
        let device: [Order] = try await send(db, "orders", token: jordan.token, query: ["role": "available", "city": "Current location"])
        #expect(device.contains { $0.id == posted.id })
        let dallas: [Order] = try await send(db, "orders", token: jordan.token, query: ["role": "available", "city": "Dallas"])
        #expect(!dallas.contains { $0.id == posted.id })
    }

    @Test func aPayoutEstimateExistsWithoutTheRunnerLocation() {
        let pickup = order("pay", created: "2026-10-25T01:00:00Z")
        let preview = RequestRanking.payoutPreview(pickup, origin: nil)
        #expect(preview.shareCents == 240)
        #expect(preview.customerCents == PricingPolicy.markedUp(preview.shareCents))
        #expect(preview.customerCents == 276)
        #expect(preview.caption.contains("not included"))
        let origin = RequestRanking.Origin(lat: 29.76, lng: -95.37, label: "Houston", source: "manual")
        let near = RequestRanking.payoutPreview(pickup, origin: origin)
        #expect(near.meters < 20_000)
        #expect(near.customerCents == PricingPolicy.markedUp(near.shareCents))
    }

    @Test func latestUsesTheTimestampAndThenTheId() {
        let older = order("a", created: "2026-10-25T01:00:00Z")
        let newer = order("b", created: "2026-10-25T02:00:00Z")
        let tie = order("c", created: "2026-10-25T02:00:00Z")
        let sorted = RequestRanking.latest([older, tie, newer]).map(\.id)
        #expect(sorted == ["c", "b", "a"])
    }

    private func sample(key: String) -> [String: Any] {
        [
            "restaurant_name": "Personal item",
            "restaurant_address": "1200 Main St, Houston, TX",
            "restaurant_lat": 29.75,
            "restaurant_lng": -95.36,
            "destination_type": "campus",
            "destination_label": "Memorial Student Center",
            "destination_lat": 30.612,
            "destination_lng": -96.341,
            "pickup_kind": "personal",
            "request_text": "Black backpack with a red tag",
            "item_quantity": "1",
            "contact_label": "Anish",
            "pickup_window": "This afternoon",
            "pickup_city": "Houston",
            "location_resolved": true,
            "weight_pounds": 8,
            "weight_confirmed": true,
            "operation_key": key,
        ]
    }

    private func order(_ id: String, created: String) -> Order {
        Order(
            id: id, tripId: "", customerId: "c", driverId: "", restaurantName: "Bag", restaurantLat: 29.7, restaurantLng: -95.3,
            destinationType: "campus", destinationLabel: "Campus", destinationLat: 30.6, destinationLng: -96.3,
            confirmationPin: nil, pinAttempts: 0, pickupName: nil, status: .requested, createdAt: created, updatedAt: created
        )
    }

    private func signIn(_ db: AppDatabase, email: String, password: String) async throws -> AuthResponse {
        try await send(db, "signin", method: "POST", body: ["email": email, "password": password])
    }

    private func send<T: Decodable>(_ db: AppDatabase, _ action: String, method: String = "GET", token: String? = nil, query: [String: String] = [:], body: [String: Any]? = nil) async throws -> T {
        let payload = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        let data = try await db.perform(action: action, method: method, query: query, body: payload, token: token)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}
