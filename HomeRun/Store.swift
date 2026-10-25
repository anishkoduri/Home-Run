import CryptoKit
import Foundation

actor AppDatabase {
    static let shared = AppDatabase()

    private struct StoredUser: Codable {
        var id: String
        var email: String
        var passwordHash: String
        var passwordSalt: String
        var displayName: String
        var avatarUrl: String?
        var paymentHandle: String?
        var createdAt: String
        var intent: String?
    }

    private struct Session: Codable {
        var token: String
        var userId: String
    }

    private struct Database: Codable {
        var users: [StoredUser]
        var sessions: [Session]
        var trips: [Trip]
        var orders: [Order]
    }

    private static let active: Set<OrderStatus> = [.accepted, .restaurantConfirmed, .pickedUp, .onTheWay, .delivered]
    private var db: Database

    private init() {
        db = Self.load()
        guard !db.users.contains(where: { $0.email == "1" }) else { return }
        let salt = UUID().uuidString
        db.users.append(StoredUser(
            id: UUID().uuidString,
            email: "1",
            passwordHash: Self.hash("1", salt: salt),
            passwordSalt: salt,
            displayName: "1",
            avatarUrl: nil,
            paymentHandle: nil,
            createdAt: Self.stamp(),
            intent: AccountUse.both.rawValue
        ))
        try? save()
    }

    func perform(action: String, method: String, query: [String: String], body: Data?, token: String?) async throws -> Data {
        let payload = try Self.object(body)
        switch (action, method) {
        case ("signup", "POST"):
            return try encode(signUp(payload))
        case ("signin", "POST"):
            return try encode(signIn(payload))
        default:
            break
        }

        let user = try user(for: token)
        switch (action, method) {
        case ("signout", "POST"):
            db.sessions.removeAll { $0.token == token }
            try save()
            return try encode(Okay(ok: true))
        case ("session", "GET"):
            return try encode(SessionPayload(user: SessionUser(id: user.id, email: user.email), profile: profile(user)))
        case ("attention", "GET"):
            let rows = db.orders
                .filter { ($0.customerId == user.id || $0.driverId == user.id) && ($0.status == .requested || $0.status == .accepted) }
                .map { Attention(status: $0.status.rawValue, customerId: $0.customerId, driverId: $0.driverId) }
            return try encode(rows)
        case ("profile", "PATCH"):
            let name = try required(payload["display_name"], max: 60, message: "Your name can't be empty.")
            guard let index = db.users.firstIndex(where: { $0.id == user.id }) else {
                throw APIError(message: "Your profile couldn't be loaded.")
            }
            db.users[index].displayName = name
            db.users[index].paymentHandle = text(payload["payment_handle"], max: 60)
            try save()
            return try encode(profile(db.users[index]))
        case ("trips", "GET"):
            return try encode(listTrips(user: user, query: query))
        case ("trips", "POST"):
            return try encode(try createTrip(user: user, body: payload))
        case ("trips", "PATCH"):
            guard let id = query["id"] else { throw APIError(message: "Missing trip.", code: "bad_request") }
            try patchTrip(user: user, id: id, body: payload)
            return try encode(Okay(ok: true))
        case ("orders", "GET"):
            if let id = query["id"] {
                let order = db.orders.first { $0.id == id && ($0.customerId == user.id || $0.driverId == user.id) }
                return try encode(OrderBox(order: order.map(presented)))
            }
            let driver = query["role"] == "driver"
            let orders = db.orders
                .filter { driver ? $0.driverId == user.id : $0.customerId == user.id }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(100)
                .map(presented)
            return try encode(Array(orders))
        case ("orders", "POST"):
            return try encode(try createOrder(user: user, body: payload))
        case ("orders", "PATCH"):
            guard let id = query["id"] else { throw APIError(message: "Missing order.", code: "bad_request") }
            return try encode(try patchOrder(user: user, id: id, body: payload))
        default:
            throw APIError(message: "Unknown action", code: "not_found")
        }
    }

    private func signUp(_ body: [String: Any]) throws -> AuthPayload {
        let email = try required(body["email"], max: 120, message: "Enter an email.").lowercased()
        guard email.contains("@") else { throw APIError(message: "Enter a valid email.", code: "bad_request") }
        let password = body["password"] as? String ?? ""
        guard password.count >= 8 else { throw APIError(message: "Use a password with at least 8 characters.", code: "bad_request") }
        guard !db.users.contains(where: { $0.email == email }) else {
            throw APIError(message: "An account with that email already exists.", code: "bad_request")
        }
        let fallback = email.split(separator: "@").first.map(String.init) ?? "Student"
        let user = StoredUser(
            id: UUID().uuidString,
            email: email,
            passwordHash: "",
            passwordSalt: UUID().uuidString,
            displayName: text(body["display_name"], max: 60) ?? String(fallback.prefix(60)),
            avatarUrl: nil,
            paymentHandle: nil,
            createdAt: Self.stamp(),
            intent: ["order", "deliver", "both"].contains(text(body["intent"], max: 20) ?? "") ? text(body["intent"], max: 20) : AccountUse.both.rawValue
        )
        var stored = user
        stored.passwordHash = Self.hash(password, salt: stored.passwordSalt)
        db.users.append(stored)
        return try issue(stored)
    }

    private func signIn(_ body: [String: Any]) throws -> AuthPayload {
        let email = try required(body["email"], max: 120, message: "Enter an email.").lowercased()
        let password = body["password"] as? String ?? ""
        guard let user = db.users.first(where: { $0.email == email }),
              Self.hash(password, salt: user.passwordSalt) == user.passwordHash else {
            throw APIError(message: "Email or password is incorrect.", code: "unauthenticated")
        }
        return try issue(user)
    }

    private func issue(_ user: StoredUser) throws -> AuthPayload {
        let token = UUID().uuidString + UUID().uuidString
        db.sessions.append(Session(token: token, userId: user.id))
        try save()
        return AuthPayload(token: token, user: SessionUser(id: user.id, email: user.email), profile: profile(user))
    }

    private func user(for token: String?) throws -> StoredUser {
        guard let token, let session = db.sessions.first(where: { $0.token == token }),
              let user = db.users.first(where: { $0.id == session.userId }) else {
            throw APIError(message: "Your session expired. Sign in again.", code: "unauthenticated")
        }
        return user
    }

    private func listTrips(user: StoredUser, query: [String: String]) -> [Trip] {
        let mine = query["mine"] == "1"
        var trips = db.trips.filter { trip in
            if mine { return trip.driverId == user.id }
            return trip.status == "scheduled" && (Self.parse(trip.departureAt) ?? .distantPast) >= Date()
        }
        if !mine, let city = query["city"], !city.isEmpty {
            trips = trips.filter { $0.originCity == city }
        }
        trips.sort { (Self.parse($0.departureAt) ?? .distantPast) < (Self.parse($1.departureAt) ?? .distantPast) }
        if mine { trips.reverse() }
        let limit = min(Int(query["limit"] ?? "") ?? 50, 100)
        return trips.prefix(limit).map(presented)
    }

    private func createTrip(user: StoredUser, body: [String: Any]) throws -> Trip {
        guard let draft = body["trip"] as? [String: Any] else {
            throw APIError(message: "Choose where you're driving from.", code: "bad_request")
        }
        let departure = try required(draft["departure_at"], max: 40, message: "Departure must be in the future.")
        guard let when = Self.parse(departure), when.timeIntervalSinceNow > -5 * 60 else {
            throw APIError(message: "Departure must be in the future.", code: "bad_request")
        }
        let maxOrders = Int(Self.number(draft["max_orders"]) ?? -1)
        guard (1...6).contains(maxOrders) else { throw APIError(message: "A trip can take 1 to 6 orders.", code: "bad_request") }
        let trip = Trip(
            id: UUID().uuidString,
            driverId: user.id,
            originCity: try required(draft["origin_city"], max: 80, message: "Choose where you're driving from."),
            originLat: try coordinate(draft["origin_lat"], "Origin location is missing."),
            originLng: try coordinate(draft["origin_lng"], "Origin location is missing."),
            destinationCity: text(draft["destination_city"], max: 80) ?? Places.destination.name,
            destinationLat: try coordinate(draft["destination_lat"], "Destination location is missing."),
            destinationLng: try coordinate(draft["destination_lng"], "Destination location is missing."),
            departureAt: Self.plain.string(from: when),
            maxOrders: maxOrders,
            notes: text(draft["notes"], max: 280),
            status: "scheduled",
            createdAt: Self.stamp(),
            driver: nil,
            stops: try stops(body["stops"], tripId: nil),
            activeOrders: 0
        )
        var saved = trip
        saved.stops = (trip.stops ?? []).enumerated().map { index, stop in
            var copy = stop
            copy.id = copy.id ?? UUID().uuidString
            copy.tripId = trip.id
            copy.stopOrder = index
            return copy
        }
        db.trips.append(saved)
        try save()
        return presented(saved)
    }

    private func stops(_ value: Any?, tripId: String?) throws -> [TripStop] {
        let rows = (value as? [[String: Any]] ?? []).prefix(10)
        return try rows.enumerated().map { index, stop in
            TripStop(
                id: UUID().uuidString,
                tripId: tripId,
                placeId: text(stop["place_id"], max: 200),
                restaurantName: try required(stop["restaurant_name"], max: 120, message: "Each stop needs a restaurant name."),
                address: text(stop["address"], max: 200),
                lat: try coordinate(stop["lat"], "A stop is missing its location."),
                lng: try coordinate(stop["lng"], "A stop is missing its location."),
                stopOrder: index
            )
        }
    }

    private func patchTrip(user: StoredUser, id: String, body: [String: Any]) throws {
        guard let index = db.trips.firstIndex(where: { $0.id == id && $0.driverId == user.id }) else {
            throw APIError(message: "Trip not found.", code: "not_found")
        }
        let status = text(body["status"], max: 20)
        guard status == "cancelled" || status == "completed" else {
            throw APIError(message: "That trip update isn't allowed.", code: "bad_request")
        }
        guard db.trips[index].status == "scheduled" else {
            throw APIError(message: "This trip is already closed.", code: "bad_request")
        }
        db.trips[index].status = status ?? db.trips[index].status
        try save()
    }

    private func createOrder(user: StoredUser, body: [String: Any]) throws -> Order {
        guard let tripId = text(body["trip_id"], max: 80), let trip = db.trips.first(where: { $0.id == tripId }) else {
            throw APIError(message: "Trip not found.", code: "bad_request")
        }
        guard user.id != trip.driverId else {
            throw APIError(message: "You cannot request delivery on your own trip.", code: "bad_request")
        }
        guard trip.status == "scheduled", (Self.parse(trip.departureAt) ?? .distantPast) >= Date() else {
            throw APIError(message: "This trip is no longer accepting requests.", code: "bad_request")
        }
        let destinationType = text(body["destination_type"], max: 20)
        guard destinationType == "campus" || destinationType == "address" else {
            throw APIError(message: "Choose a campus meetup or a street address.", code: "bad_request")
        }
        let placeSource = text(body["place_source"], max: 20)
        let estimateSource = text(body["estimate_source"], max: 20)
        let stamp = Self.stamp()
        let order = Order(
            id: UUID().uuidString,
            tripId: trip.id,
            customerId: user.id,
            driverId: trip.driverId,
            restaurantPlaceId: text(body["restaurant_place_id"], max: 200),
            restaurantName: try required(body["restaurant_name"], max: 120, message: "Choose a restaurant."),
            restaurantAddress: text(body["restaurant_address"], max: 200),
            restaurantLat: try coordinate(body["restaurant_lat"], "Restaurant location is missing."),
            restaurantLng: try coordinate(body["restaurant_lng"], "Restaurant location is missing."),
            restaurantWebsite: website(body["restaurant_website"]),
            placeSource: placeSource == "google" || placeSource == "osm" ? placeSource : nil,
            destinationType: destinationType ?? "campus",
            destinationLabel: try required(body["destination_label"], max: 160, message: "Choose a handoff spot."),
            destinationLat: try coordinate(body["destination_lat"], "Handoff location is missing."),
            destinationLng: try coordinate(body["destination_lng"], "Handoff location is missing."),
            detourMinutes: Self.number(body["detour_minutes"]),
            deliveryFee: Self.number(body["delivery_fee"]),
            estimateSource: ["google", "osrm", "straight_line"].contains(estimateSource ?? "") ? estimateSource : nil,
            estimatedArrivalAt: text(body["estimated_arrival_at"], max: 40),
            customerNote: text(body["customer_note"], max: 500),
            pickupName: nil,
            restaurantOrderNumber: nil,
            pickupReadyAt: nil,
            pickupInstructions: nil,
            status: .requested,
            cancelledBy: nil,
            acceptedAt: nil,
            restaurantOrderConfirmedAt: nil,
            pickedUpAt: nil,
            onTheWayAt: nil,
            deliveredAt: nil,
            declinedAt: nil,
            cancelledAt: nil,
            createdAt: stamp,
            updatedAt: stamp,
            trip: nil,
            driver: nil,
            customer: nil
        )
        db.orders.append(order)
        try save()
        return presented(order)
    }

    private func patchOrder(user: StoredUser, id: String, body: [String: Any]) throws -> Order {
        guard let index = db.orders.firstIndex(where: { $0.id == id }) else {
            throw APIError(message: "Order not found.", code: "not_found")
        }
        var order = db.orders[index]
        let isDriver = user.id == order.driverId
        let isCustomer = user.id == order.customerId
        guard isDriver || isCustomer else { throw APIError(message: "Not your order.", code: "forbidden") }

        let editingDelivery = ["destination_type", "destination_label", "destination_lat", "destination_lng", "customer_note"].contains { body.keys.contains($0) }
        if editingDelivery {
            guard isCustomer, order.status == .requested else {
                throw APIError(message: "Delivery details can only be edited by the customer before acceptance.", code: "forbidden")
            }
            if body.keys.contains("destination_type") { order.destinationType = try required(body["destination_type"], max: 20, message: "Choose a handoff spot.") }
            if body.keys.contains("destination_label") { order.destinationLabel = try required(body["destination_label"], max: 160, message: "Choose a handoff spot.") }
            if body.keys.contains("destination_lat") { order.destinationLat = try coordinate(body["destination_lat"], "Handoff location is missing.") }
            if body.keys.contains("destination_lng") { order.destinationLng = try coordinate(body["destination_lng"], "Handoff location is missing.") }
            if body.keys.contains("customer_note") { order.customerNote = text(body["customer_note"], max: 500) }
        }

        let editingPickup = ["pickup_name", "restaurant_order_number", "pickup_ready_at", "pickup_instructions"].contains { body.keys.contains($0) }
        if editingPickup {
            guard isCustomer, order.status == .accepted || order.status == .restaurantConfirmed else {
                throw APIError(message: "Pickup details can only be added by the customer after the driver accepts.", code: "forbidden")
            }
            if body.keys.contains("pickup_name") { order.pickupName = text(body["pickup_name"], max: 80) }
            if body.keys.contains("restaurant_order_number") { order.restaurantOrderNumber = text(body["restaurant_order_number"], max: 60) }
            if body.keys.contains("pickup_ready_at") { order.pickupReadyAt = text(body["pickup_ready_at"], max: 40) }
            if body.keys.contains("pickup_instructions") { order.pickupInstructions = text(body["pickup_instructions"], max: 500) }
        }

        if let status = text(body["status"], max: 40), status != order.status.rawValue {
            guard let next = OrderStatus(rawValue: status) else {
                throw APIError(message: "That status isn't recognized.", code: "bad_request")
            }
            let stamp = Self.stamp()
            switch (order.status, next, isDriver, isCustomer) {
            case (.requested, .accepted, true, _):
                let load = db.orders.filter { $0.tripId == order.tripId && $0.id != order.id && Self.active.contains($0.status) }.count
                let cap = db.trips.first { $0.id == order.tripId }?.maxOrders ?? 0
                guard load < cap else { throw APIError(message: "This trip is already at its order limit.", code: "bad_request") }
                order.status = next
                order.acceptedAt = stamp
            case (.requested, .declined, true, _):
                order.status = next
                order.declinedAt = stamp
            case (.accepted, .restaurantConfirmed, _, true):
                guard order.pickupName != nil, order.pickupReadyAt != nil else {
                    throw APIError(message: "Pickup name and ready time are required.", code: "bad_request")
                }
                order.status = next
                order.restaurantOrderConfirmedAt = stamp
            case (.restaurantConfirmed, .pickedUp, true, _):
                order.status = next
                order.pickedUpAt = stamp
            case (.pickedUp, .onTheWay, true, _):
                order.status = next
                order.onTheWayAt = stamp
            case (.onTheWay, .delivered, true, _):
                order.status = next
                order.deliveredAt = stamp
            case (.requested, .cancelled, _, true), (.accepted, .cancelled, _, true), (.restaurantConfirmed, .cancelled, _, true),
                 (.accepted, .cancelled, true, _), (.restaurantConfirmed, .cancelled, true, _):
                order.status = next
                order.cancelledAt = stamp
                order.cancelledBy = user.id
            default:
                throw APIError(message: "Invalid status change from \(order.status.rawValue) to \(status) for this account.", code: "forbidden")
            }
        }

        order.updatedAt = Self.stamp()
        db.orders[index] = order
        try save()
        return presented(order)
    }

    private func presented(_ trip: Trip) -> Trip {
        var copy = trip
        copy.stops = (trip.stops ?? []).sorted { $0.stopOrder < $1.stopOrder }
        copy.driver = db.users.first { $0.id == trip.driverId }.map(profile)
        copy.activeOrders = db.orders.filter { $0.tripId == trip.id && Self.active.contains($0.status) }.count
        return copy
    }

    private func presented(_ order: Order) -> Order {
        var copy = order
        if let trip = db.trips.first(where: { $0.id == order.tripId }) { copy.trip = presented(trip) }
        copy.driver = db.users.first { $0.id == order.driverId }.map(profile)
        copy.customer = db.users.first { $0.id == order.customerId }.map(profile)
        return copy
    }

    private func profile(_ user: StoredUser) -> Profile {
        Profile(id: user.id, displayName: user.displayName, avatarUrl: user.avatarUrl, paymentHandle: user.paymentHandle, createdAt: user.createdAt, intent: user.intent)
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try Self.snake.encode(value)
    }

    private static func object(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        let value = try JSONSerialization.jsonObject(with: data)
        return value as? [String: Any] ?? [:]
    }

    private static func load() -> Database {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Database.self, from: data) else {
            return Database(users: [], sessions: [], trips: [], orders: [])
        }
        return decoded
    }

    private func save() throws {
        var snapshot = db
        for index in snapshot.trips.indices {
            snapshot.trips[index].driver = nil
            snapshot.trips[index].activeOrders = nil
        }
        for index in snapshot.orders.indices {
            snapshot.orders[index].trip = nil
            snapshot.orders[index].driver = nil
            snapshot.orders[index].customer = nil
        }
        let directory = Self.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.fileEncoder.encode(snapshot).write(to: Self.fileURL, options: .atomic)
        db = snapshot
        for index in db.trips.indices {
            db.trips[index].stops = snapshot.trips[index].stops
        }
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HomeRun", isDirectory: true)
            .appendingPathComponent("store.json")
    }

    private static func hash(_ password: String, salt: String) -> String {
        SHA256.hash(data: Data((salt + password).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func stamp() -> String { plain.string(from: Date()) }

    private static func parse(_ value: String) -> Date? {
        fractional.date(from: value) ?? plain.date(from: value)
    }

    private static func number(_ value: Any?) -> Double? {
        if value is NSNull { return nil }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private func text(_ value: Any?, max: Int) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(max))
    }

    private func required(_ value: Any?, max: Int, message: String) throws -> String {
        guard let text = text(value, max: max) else { throw APIError(message: message, code: "bad_request") }
        return text
    }

    private func coordinate(_ value: Any?, _ message: String) throws -> Double {
        guard let number = Self.number(value) else { throw APIError(message: message, code: "bad_request") }
        return number
    }

    private func website(_ value: Any?) -> String? {
        guard let site = text(value, max: 300), site.lowercased().hasPrefix("http://") || site.lowercased().hasPrefix("https://") else { return nil }
        return site
    }

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let snake: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private static let fileEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

private struct AuthPayload: Encodable {
    var token: String
    var user: SessionUser
    var profile: Profile
}

private struct SessionPayload: Encodable {
    var user: SessionUser
    var profile: Profile
}

private struct Attention: Encodable {
    var status: String
    var customerId: String
    var driverId: String
}

private struct OrderBox: Encodable {
    var order: Order?
}

private struct Okay: Encodable {
    var ok: Bool
}
