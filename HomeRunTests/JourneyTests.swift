import Foundation
import Testing
@testable import HomeRun

struct JourneyTests {
    @Test func aPublishedTripReachesTheAssignedRunner() async throws {
        let db = AppDatabase.testingStore()
        let maya = try await signIn(db, email: "maya@demo.local", password: "demo")
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let alex = try await signIn(db, email: "alex@demo.local", password: "demo")
        let avery = try await signIn(db, email: "avery@demo.local", password: "demo")

        let departure = ISO8601DateFormatter().string(from: DemoClock.now.addingTimeInterval(36 * 3_600))
        let trip: Trip = try await send(db, "trips", method: "POST", token: jordan.token, body: [
            "trip": [
                "origin_city": "El Paso",
                "origin_lat": 31.7619,
                "origin_lng": -106.4850,
                "destination_city": "College Station",
                "destination_lat": 30.615,
                "destination_lng": -96.341,
                "departure_at": departure,
                "max_orders": 1,
                "notes": "Journey test",
                "status": "scheduled",
            ],
            "stops": [],
        ])

        let visible: [Trip] = try await send(db, "trips", token: maya.token, query: ["city": "El Paso"])
        let listed = try #require(visible.first { $0.id == trip.id })
        #expect(listed.driver?.displayName == "Jordan Ellis")
        #expect(listed.status == "scheduled")

        let draft: Trip = try await send(db, "trips", method: "POST", token: jordan.token, body: [
            "trip": [
                "origin_city": "El Paso",
                "origin_lat": 31.7619,
                "origin_lng": -106.4850,
                "destination_city": "College Station",
                "destination_lat": 30.615,
                "destination_lng": -96.341,
                "departure_at": departure,
                "max_orders": 2,
                "status": "draft",
            ],
            "stops": [],
        ])
        let stillVisible: [Trip] = try await send(db, "trips", token: maya.token, query: ["city": "El Paso"])
        #expect(!stillVisible.contains { $0.id == draft.id })

        await #expect(throws: APIError.self) {
            try await postOrder(db, token: jordan.token, trip: trip, key: "own-trip", item: "Rice bowl", quantity: 1)
        }

        let order = try await postOrder(db, token: maya.token, trip: trip, key: "maya-rice", item: "Rice bowl", quantity: 2)
        #expect(order.lines?.first?.name == "Rice bowl")
        #expect(order.lines?.first?.quantity == 2)
        #expect(order.itemSummary == "2× Rice bowl")
        #expect(order.driverId == jordan.user.id)

        let jordanInbox: [Order] = try await send(db, "orders", token: jordan.token, query: ["role": "driver"])
        let latest = jordanInbox.filter { $0.status == .requested }
        #expect(latest.first?.id == order.id)
        #expect(latest.first?.lines?.first?.name == "Rice bowl")

        let averyInbox: [Order] = try await send(db, "orders", token: avery.token, query: ["role": "driver"])
        #expect(!averyInbox.contains { $0.id == order.id })

        let competing = try await postOrder(db, token: alex.token, trip: trip, key: "alex-snack", item: "Snack bundle", quantity: 1)
        let accepted: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": order.id], body: ["status": "accepted"])
        #expect(accepted.status == .accepted)
        await #expect(throws: APIError.self) {
            let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": competing.id], body: ["status": "accepted"])
        }

        let customer: OrderEnvelope = try await send(db, "orders", token: maya.token, query: ["id": order.id])
        #expect(customer.order?.status == .accepted)

        let before: InboxCount = try await send(db, "inbox-count", token: jordan.token)
        let _: MessageList = try await send(db, "messages", method: "POST", token: maya.token, body: ["order_id": order.id, "body": "Reference is on the bag."])
        let mid: InboxCount = try await send(db, "inbox-count", token: jordan.token)
        #expect(mid.messages == before.messages + 1)
        let _: MessageList = try await send(db, "messages", token: jordan.token, query: ["order": order.id])
        let after: InboxCount = try await send(db, "inbox-count", token: jordan.token)
        #expect(after.messages == before.messages)

        let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": order.id], body: ["status": "restaurant_confirmed"])
        let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": order.id], body: ["status": "picked_up"])
        let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": order.id], body: ["status": "on_the_way"])
        let arriving: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": order.id], body: ["status": "arriving"])
        #expect(arriving.confirmationPin == nil)
        let withCode: OrderEnvelope = try await send(db, "orders", token: maya.token, query: ["id": order.id])
        let pin = try #require(withCode.order?.confirmationPin)
        await #expect(throws: APIError.self) {
            let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": order.id], body: ["status": "delivered", "pin": "0000"])
        }
        let delivered: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": order.id], body: ["status": "delivered", "pin": pin])
        #expect(delivered.status == .delivered)
        #expect(delivered.runnerShareCents == 640)

        let ledger: LedgerList = try await send(db, "ledger", token: jordan.token, query: ["order": order.id])
        #expect(ledger.entries.filter { $0.kind == "earning" }.count == 1)
        #expect(ledger.entries.filter { $0.kind == "delivery-capture" }.count == 1)

        let url = await db.testingLocation()
        let reopened = AppDatabase.reopenTestingStore(at: url)
        let kept: OrderEnvelope = try await send(reopened, "orders", token: maya.token, query: ["id": order.id])
        #expect(kept.order?.lines?.first?.name == "Rice bowl")
        #expect(kept.order?.status == .delivered)
    }

    @Test func bookmarksAndTripEditsUseTheSameStore() async throws {
        let db = AppDatabase.testingStore()
        let maya = try await signIn(db, email: "maya@demo.local", password: "demo")
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let saved: SavedPlaceList = try await send(db, "saved-places", method: "POST", token: maya.token, body: [
            "place_id": "sample:bayou",
            "name": "Bayou Bowl Kitchen",
            "address": "Sample address",
            "lat": 29.76,
            "lng": -95.36,
            "city": "Houston",
        ])
        #expect(saved.places.count == 1)
        let removed: SavedPlaceList = try await send(db, "saved-places", method: "POST", token: maya.token, body: [
            "place_id": "sample:bayou",
            "name": "Bayou Bowl Kitchen",
            "lat": 29.76,
            "lng": -95.36,
        ])
        #expect(removed.places.isEmpty)
        struct Ack: Decodable { var ok: Bool }
        let _: Ack = try await send(db, "demo-reset", method: "POST", token: maya.token)
        let afterReset: SavedPlaceList = try await send(db, "saved-places", token: maya.token)
        #expect(afterReset.places.isEmpty)

        let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": "demo-trip-jordan"], body: [
            "notes": "Window seat",
            "max_orders": 4,
        ])
        let mine: [Trip] = try await send(db, "trips", token: jordan.token, query: ["mine": "1"])
        #expect(mine.first { $0.id == "demo-trip-jordan" }?.notes == "Window seat")

        let _: Profile = try await send(db, "preferences", method: "PATCH", token: jordan.token, body: ["notify": false])
        let before: InboxCount = try await send(db, "inbox-count", token: jordan.token)
        let trip = try #require(mine.first { $0.id == "demo-trip-jordan" })
        _ = try await postOrder(db, token: maya.token, trip: trip, key: "quiet", item: "Sandwich box", quantity: 1)
        let after: InboxCount = try await send(db, "inbox-count", token: jordan.token)
        #expect(after.notices == before.notices)
    }

    private func signIn(_ db: AppDatabase, email: String, password: String) async throws -> AuthResponse {
        try await send(db, "signin", method: "POST", body: ["email": email, "password": password])
    }

    private func postOrder(_ db: AppDatabase, token: String, trip: Trip, key: String, item: String, quantity: Int) async throws -> Order {
        try await send(db, "orders", method: "POST", token: token, body: [
            "trip_id": trip.id,
            "restaurant_name": "Bayou Bowl Kitchen",
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
            "pickup_reference": "HR-JOURNEY",
            "operation_key": key,
            "lines": [[
                "id": key,
                "name": item,
                "quantity": quantity,
                "weight_pounds": 2,
                "weight_confirmed": true,
                "bulky": false,
                "fragile": false,
            ]],
        ])
    }

    private func send<T: Decodable>(_ db: AppDatabase, _ action: String, method: String = "GET", token: String? = nil, query: [String: String] = [:], body: [String: Any]? = nil) async throws -> T {
        let payload = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        let data = try await db.perform(action: action, method: method, query: query, body: payload, token: token)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}
