import Foundation
import Testing
@testable import HomeRun

struct VisionCorrectionsTests {
    @Test func cityPickerStaysClosedUntilAsked() {
        #expect(CityPickerGate.opens(userTappedControl: false, actionNeedsCity: false, cityConfirmed: false) == false)
        #expect(CityPickerGate.opens(userTappedControl: false, actionNeedsCity: false, cityConfirmed: true) == false)
        #expect(CityPickerGate.opens(userTappedControl: true, actionNeedsCity: false, cityConfirmed: true))
        #expect(CityPickerGate.opens(userTappedControl: false, actionNeedsCity: true, cityConfirmed: false))
        #expect(CityPickerGate.opens(userTappedControl: false, actionNeedsCity: true, cityConfirmed: true) == false)
    }

    @Test func customerTripCopyDoesNotTalkAboutSpots() {
        let trip = Trip(
            id: "t", driverId: "demo-jordan", originCity: "Houston", originLat: 1, originLng: 1,
            destinationCity: "College Station", destinationLat: 2, destinationLng: 2,
            departureAt: "2026-10-26T16:00:00", maxOrders: 4, notes: nil, status: "scheduled",
            createdAt: "2026-10-25T00:00:00", activeOrders: 1
        )
        #expect(!TripCopy.requestsOpen(trip).localizedCaseInsensitiveContains("spot"))
        #expect(TripCopy.requestsOpen(trip) == "Requests open")
        #expect(TripCopy.pickupLimit(trip) == "Pickup limit 1 of 4")
    }

    @Test func editorialOrderOnlyAppliesToEmptyBrowse() {
        let trader = place("tj", "Trader Joe's", outside: false)
        let aga = place("aga", "Aga's Restaurant & Catering", outside: false)
        let heb = place("heb", "H-E-B", outside: false)
        let away = place("away", "Trader Joe's", outside: true)
        let dallas = [heb, trader]
        let houston = [heb, aga, trader]

        let stores = DiscoveryCuration.order(dallas, city: "Dallas", query: "", category: "groceries")
        #expect(stores.map(\.placeId) == ["tj", "heb"])

        let food = DiscoveryCuration.order(houston, city: "Houston", query: "", category: "food")
        #expect(food.first?.placeId == "aga")
        #expect(!food.map(\.placeId).prefix(1).contains("tj"))

        let all = DiscoveryCuration.order(houston, city: "Houston", query: "", category: "all")
        #expect(all.map(\.placeId).prefix(2) == ["tj", "aga"])

        let typed = DiscoveryCuration.order(houston, city: "Houston", query: "H-E-B", category: "all")
        #expect(typed.map(\.placeId) == ["heb", "aga", "tj"])
        #expect(DiscoveryCuration.promotedIDs(in: typed, city: "Houston", query: "H-E-B", category: "all").isEmpty)

        let outsider = DiscoveryCuration.order([away, heb], city: "Dallas", query: "", category: "stores")
        #expect(outsider.map(\.placeId) == ["away", "heb"])

        let otherCity = DiscoveryCuration.order([aga, heb], city: "Dallas", query: "", category: "food")
        #expect(otherCity.map(\.placeId) == ["aga", "heb"])
    }

    @Test func seededDemoEmailIsThePrimaryProfileOnly() async throws {
        let db = AppDatabase.testingStore()
        let primary = try await signIn(db, email: "anishkoduri@tamu.edu", password: "demo")
        #expect(primary.user.email == "anishkoduri@tamu.edu")
        let jordan = try await signIn(db, email: "jordan@demo.local", password: "demo")
        #expect(jordan.user.email == "jordan@demo.local")
        let old = try? await signIn(db, email: "maya@demo.local", password: "demo")
        #expect(old == nil)
    }

    private func place(_ id: String, _ name: String, outside: Bool) -> Place {
        Place(placeId: id, name: name, address: "1 Main", lat: 29.7, lng: -95.3, outsideCity: outside)
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
