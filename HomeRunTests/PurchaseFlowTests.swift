import Foundation
import Testing
@testable import HomeRun

struct PurchaseFlowTests {
    @Test func customerPaysTheStoreAndDeliveryStaysSeparate() async throws {
        let db = AppDatabase.testingStore()
        let maya = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let trips: [Trip] = try await send(db, "trips", token: jordan.token, query: ["mine": "1"])
        let trip = try #require(trips.first { $0.id == "demo-trip-jordan" })
        let ready = try #require(Self.pickupDate(before: trip.departureAt))

        let created = try await postPickup(db, token: maya.token, trip: trip, key: "customer-paid", kind: "merchant", ready: ready)
        #expect(created.orderingModel == "customer_paid")
        #expect(created.merchandiseCents == nil)
        #expect(created.quoteCents == 800)
        #expect(created.runnerShareCents == 640)
        #expect(created.itemSummary == "Two takeout bags: one rice bowl and one sandwich.")

        let accepted: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": created.id], body: ["status": "accepted"])
        #expect(accepted.status == .accepted)
        #expect(accepted.handoffSubmittedAt == nil)

        let confirmed: Order = try await send(db, "orders", method: "PATCH", token: maya.token, query: ["id": created.id], body: [
            "handoff_submit": true,
            "request_text": "Two takeout bags: one rice bowl and one sandwich.",
            "pickup_name": "Anish Koduri",
            "reference_missing": false,
            "restaurant_order_number": "B12",
            "pickup_window": "30 minutes before departure",
            "pickup_ready_at": ready,
            "pickup_instructions": "Counter under the name Anish.",
        ])
        #expect(confirmed.status == .restaurantConfirmed)
        #expect(confirmed.handoffSubmittedAt != nil)
        #expect(confirmed.pickupName == "Anish Koduri")

        await #expect(throws: APIError.self) {
            let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": created.id], body: ["status": "picked_up"])
        }
        let reviewed: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": created.id], body: ["details_decision": "received"])
        #expect(reviewed.detailsReviewedAt != nil)
        let picked: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": created.id], body: [
            "status": "picked_up",
            "collection_confirmed": true,
        ])
        #expect(picked.status == .pickedUp)
        let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": created.id], body: ["status": "on_the_way"])
        let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": created.id], body: ["status": "arriving"])
        let shown: OrderEnvelope = try await send(db, "orders", token: maya.token, query: ["id": created.id])
        let pin = try #require(shown.order?.confirmationPin)
        let delivered: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": created.id], body: ["status": "delivered", "pin": pin])
        #expect(delivered.runnerShareCents == 640)
        #expect(delivered.itemSummary == "Two takeout bags: one rice bowl and one sandwich.")

        let ledger: LedgerList = try await send(db, "ledger", token: jordan.token, query: ["order": created.id])
        #expect(ledger.entries.filter { $0.kind == "earning" }.map(\.cents) == [640])
        #expect(!ledger.entries.contains { $0.kind.hasPrefix("merchandise") })

        let home = try await postPickup(db, token: maya.token, trip: trip, key: "personal-item", kind: "personal", ready: ready)
        #expect(home.orderingModel == "personal")
        #expect(home.merchandiseCents == nil)
        #expect(home.contactLabel == "Roommate Jordan")

        let history: [Order] = try await send(db, "orders", token: maya.token)
        let older = try #require(history.first { $0.id == "demo-order-delivered" })
        #expect(older.orderingModel == "runner_purchase")
        let oldLedger: LedgerList = try await send(db, "ledger", token: maya.token, query: ["order": older.id])
        #expect(oldLedger.entries.contains { $0.kind == "merchandise-reimburse" && $0.cents == 2_400 })
        #expect(oldLedger.entries.contains { $0.kind == "earning" && $0.cents == 640 })
    }

    private func postPickup(_ db: AppDatabase, token: String, trip: Trip, key: String, kind: String, ready: String) async throws -> Order {
        var body: [String: Any] = [
            "trip_id": trip.id,
            "restaurant_name": kind == "personal" ? "Sample house — not a real address" : "Bayou Bowl Kitchen",
            "restaurant_lat": trip.originLat,
            "restaurant_lng": trip.originLng,
            "place_source": "sample",
            "destination_type": "campus",
            "destination_label": "Campus Library Plaza — demo location",
            "destination_lat": 30.618,
            "destination_lng": -96.338,
            "estimate_source": "osrm",
            "extra_meters": 0,
            "extra_seconds": 0,
            "weight_pounds": 5,
            "weight_confirmed": true,
            "request_text": kind == "personal" ? "Black backpack with a red luggage tag, one bag." : "Two takeout bags: one rice bowl and one sandwich.",
            "pickup_kind": kind,
            "pickup_window": "30 minutes before departure",
            "pickup_ready_at": ready,
            "operation_key": key,
        ]
        if kind == "personal" {
            body["contact_label"] = "Roommate Jordan"
            body["access_instructions"] = "Front entrance. Fictional sample point."
            body["item_quantity"] = "One bag"
        }
        return try await send(db, "orders", method: "POST", token: token, body: body)
    }

    private static func pickupDate(before departure: String) -> String? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = fractional.date(from: departure) ?? plain.date(from: departure) else { return nil }
        return plain.string(from: date.addingTimeInterval(-1_800))
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
