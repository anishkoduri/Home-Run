import Foundation
import Testing
@testable import HomeRun

@Suite(.serialized)
struct TripEditTests {
    @Test func stopsReorderAndAcceptedStopsStay() async throws {
        let db = AppDatabase.testingStore()
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let maya = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        let mine: [Trip] = try await send(db, "trips", token: jordan.token, query: ["mine": "1"])
        let houston = try #require(mine.first { $0.id == "demo-trip-jordan" })
        let first: [String: Any] = ["id": "stop-a", "restaurant_name": "First Kitchen", "lat": houston.originLat, "lng": houston.originLng, "place_id": "sample:first"]
        let second: [String: Any] = ["id": "stop-b", "restaurant_name": "Second Kitchen", "lat": houston.originLat + 0.01, "lng": houston.originLng, "place_id": "sample:second"]
        let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": houston.id], body: ["stops": [first, second]])
        let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": houston.id], body: ["stops": [second, first]])
        let reordered: [Trip] = try await send(db, "trips", token: jordan.token, query: ["mine": "1"])
        #expect(reordered.first { $0.id == houston.id }?.stops?.map(\.restaurantName) == ["Second Kitchen", "First Kitchen"])

        let open = try await post(db, token: maya.token, trip: houston, key: "open-quote", placeId: "sample:first", name: "First Kitchen")
        let extra: [String: Any] = ["id": "stop-c", "restaurant_name": "Third Kitchen", "lat": houston.originLat + 0.02, "lng": houston.originLng, "place_id": "sample:third"]
        let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": houston.id], body: ["stops": [second, first, extra]])
        let customerOrders: [Order] = try await send(db, "orders", token: maya.token)
        #expect(customerOrders.first { $0.id == open.id }?.quoteState == "expired")
        let ledger: LedgerList = try await send(db, "ledger", token: maya.token, query: ["order": open.id])
        #expect(ledger.entries.contains { $0.kind == "release" && $0.orderId == open.id })

        let held = try await post(db, token: maya.token, trip: houston, key: "held-quote", placeId: "sample:first", name: "First Kitchen")
        let accepted: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": held.id], body: ["status": "accepted"])
        #expect(accepted.status == .accepted)
        await #expect(throws: APIError.self) {
            let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": houston.id], body: ["stops": [second, extra]])
        }
        let still: [Order] = try await send(db, "orders", token: maya.token)
        #expect(still.first { $0.id == held.id }?.status == .accepted)
        #expect(still.first { $0.id == held.id }?.deliveryFee == 8)
        let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": houston.id], body: ["stops": [second, first, extra]])
        let kept: [Trip] = try await send(db, "trips", token: jordan.token, query: ["mine": "1"])
        #expect(kept.first { $0.id == houston.id }?.stops?.contains { $0.placeId == "sample:first" } == true)
    }

    @Test func anEditedOccurrenceStaysDistinct() async throws {
        let db = AppDatabase.testingStore()
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let _: Ack = try await send(db, "recurrence", method: "POST", token: jordan.token, body: ["trip_id": "demo-trip-jordan", "cadence": "weekly"])
        let generated = try await occurrences(db, token: jordan.token)
        #expect(generated.count >= 2)
        let edited = try #require(generated.first)
        let other = try #require(generated.dropFirst().first)
        let later = ISO8601DateFormatter().string(from: DemoClock.now.addingTimeInterval(20 * 86_400))
        let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": edited.id], body: [
            "notes": "Only this date",
            "departure_at": later,
            "scope": "occurrence",
        ])
        let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": "demo-trip-jordan"], body: [
            "notes": "Series note",
            "scope": "series",
        ])
        let after = try await occurrences(db, token: jordan.token)
        #expect(after.first { $0.id == edited.id }?.notes == "Only this date")
        #expect(after.first { $0.id == edited.id }?.occurrenceEdited == true)
        #expect(after.first { $0.id == other.id }?.notes == "Series note")
        #expect(after.first { $0.id == other.id }?.occurrenceEdited != true)
        let source: [Trip] = try await send(db, "trips", token: jordan.token, query: ["mine": "1"])
        #expect(source.first { $0.id == "demo-trip-jordan" }?.notes == "Series note")
        let _: Ack = try await send(db, "recurrence", method: "POST", token: jordan.token, body: ["trip_id": "demo-trip-jordan", "cadence": "weekly"])
        let again = try await occurrences(db, token: jordan.token)
        #expect(again.filter { $0.templateId == edited.templateId }.count == 1)
        await #expect(throws: APIError.self) {
            let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": edited.id], body: ["scope": "series", "notes": "Should fail"])
        }
    }

    @Test func scenarioSetupsLeaveSharedRecords() async throws {
        defer {
            DemoRouteFixture.set("")
            DemoRouteFixture.setSamples(false)
        }
        let db = AppDatabase.testingStore()
        let maya = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        let dinner: ScenarioPrep = try await send(db, "demo-scenario", method: "POST", token: maya.token, body: ["scenario": 1])
        #expect(dinner.city == "Houston")
        let houston: [Trip] = try await send(db, "trips", token: jordan.token, query: ["mine": "1"])
        #expect(houston.first { $0.id == "demo-trip-jordan" }?.stops?.first?.placeId == "sample:bayou-bowl")

        let race: ScenarioPrep = try await send(db, "demo-scenario", method: "POST", token: maya.token, body: ["scenario": 7])
        #expect(race.title.contains("last pickup"))
        let requests: [Order] = try await send(db, "orders", token: jordan.token, query: ["role": "driver"])
        let pending = requests.filter { $0.id == "demo-order-race-maya" || $0.id == "demo-order-race-alex" }
        #expect(pending.count == 2)
        let first = try #require(pending.first)
        let second = try #require(pending.dropFirst().first)
        let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": first.id], body: ["status": "accepted"])
        await #expect(throws: APIError.self) {
            let _: Order = try await send(db, "orders", method: "PATCH", token: jordan.token, query: ["id": second.id], body: ["status": "accepted"])
        }
        let ledger: LedgerList = try await send(db, "ledger", token: jordan.token)
        let captures = ledger.entries.filter { $0.kind == "delivery-capture" && pending.map(\.id).contains($0.orderId) }
        #expect(captures.count == 1)

        let plans: ScenarioPrep = try await send(db, "demo-scenario", method: "POST", token: maya.token, body: ["scenario": 6])
        #expect(plans.scenario == 6)
        let _: Ack = try await send(db, "trips", method: "PATCH", token: jordan.token, query: ["id": "demo-trip-jordan"], body: ["status": "cancelled"])
        let customer: [Order] = try await send(db, "orders", token: maya.token)
        let cancelled = try #require(customer.first { $0.id == "demo-order-plans" })
        #expect(cancelled.status == .cancelled)
        let refunds: LedgerList = try await send(db, "ledger", token: maya.token, query: ["order": cancelled.id])
        #expect(refunds.entries.contains { $0.kind == "delivery-refund" && $0.cents == 800 })
        #expect(!refunds.entries.contains { $0.kind == "merchandise-refund" })

        let made: ScenarioPrep = try await send(db, "demo-scenario", method: "POST", token: maya.token, body: ["scenario": 8])
        #expect(made.instructions.contains("Taylor Brooks"))
        let history: [Order] = try await send(db, "orders", token: maya.token)
        #expect(history.contains { $0.id == "demo-order-delivered" && $0.status == .delivered })

        let empty: ScenarioPrep = try await send(db, "demo-scenario", method: "POST", token: maya.token, body: ["scenario": 5])
        #expect(empty.city == "San Antonio")
        let listed: [Trip] = try await send(db, "trips", token: maya.token, query: ["city": "San Antonio"])
        #expect(listed.isEmpty)
    }

    @Test func everyScenarioPreparesASharedRecord() async throws {
        let terms = ["demo-maya", "demo-jordan", "demo-avery", "demo-sam", "demo-alex", "demo-taylor"].map { "homerun.terms.\($0)" }
        let saved = Dictionary(uniqueKeysWithValues: terms.map { ($0, UserDefaults.standard.string(forKey: $0)) })
        defer {
            DemoRouteFixture.set("")
            DemoRouteFixture.setSamples(false)
            for (key, value) in saved {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
        }
        let db = AppDatabase.testingStore()
        let maya = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        for number in 1...10 {
            let prep: ScenarioPrep = try await send(db, "demo-scenario", method: "POST", token: maya.token, body: ["scenario": number])
            #expect(prep.scenario == number)
            #expect(prep.instructions.isEmpty == false)
        }
        let offline: ScenarioPrep = try await send(db, "demo-scenario", method: "POST", token: maya.token, body: ["scenario": 10])
        #expect(offline.forceSamples)
        #expect(offline.fixture == "review")
        let welcome: ScenarioPrep = try await send(db, "demo-scenario", method: "POST", token: maya.token, body: ["scenario": 9])
        #expect(welcome.clearTerms)
        #expect(UserDefaults.standard.string(forKey: "homerun.terms.demo-maya") == nil)
    }

    private func occurrences(_ db: AppDatabase, token: String) async throws -> [Trip] {
        let mine: [Trip] = try await send(db, "trips", token: token, query: ["mine": "1"])
        return mine.filter { $0.templateId?.hasPrefix("demo-trip-jordan|") == true }
    }

    private func post(_ db: AppDatabase, token: String, trip: Trip, key: String, placeId: String, name: String) async throws -> Order {
        try await send(db, "orders", method: "POST", token: token, body: [
            "trip_id": trip.id,
            "restaurant_place_id": placeId,
            "restaurant_name": name,
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
            "pickup_reference": "HR-EDIT",
            "operation_key": key,
            "lines": [[
                "id": key,
                "name": "Rice bowl",
                "quantity": 1,
                "weight_pounds": 2,
                "weight_confirmed": true,
                "bulky": false,
                "fragile": false,
            ]],
        ])
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

private struct Ack: Decodable { var ok: Bool }
