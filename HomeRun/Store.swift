import CryptoKit
import Foundation
import UIKit

actor AppDatabase {
    static let shared = AppDatabase(storageURL: AppDatabase.defaultStorageURL)

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
        var notify: Bool? = nil
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
        var messages: [OrderMessage]?
        var ledger: [LedgerEntry]?
        var notices: [AppNotice]?
        var savedRequests: [SavedRequest]?
        var supportCases: [SupportCase]?
        var savedPlaces: [SavedPlace]?
    }

    private static let active: Set<OrderStatus> = [.accepted, .restaurantConfirmed, .pickedUp, .onTheWay, .arriving, .delivered]
    private var db: Database
    private let storageURL: URL

    static func testingStore() -> AppDatabase {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("homerun-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return AppDatabase(storageURL: folder.appendingPathComponent("store.json"))
    }

    static func reopenTestingStore(at url: URL) -> AppDatabase {
        AppDatabase(storageURL: url)
    }

    func testingLocation() -> URL { storageURL }

    private init(storageURL: URL) {
        self.storageURL = storageURL
        db = Self.load(from: storageURL)
        seedDemoIfNeeded()
        if let index = db.users.firstIndex(where: { $0.id == "demo-maya" }), db.users[index].displayName != "Anish Koduri" {
            db.users[index].displayName = "Anish Koduri"
            try? save()
        }
        let limits: [String: (Double, Double)] = [
            "demo-trip-jordan": (50, 50),
            "demo-trip-jordan-later": (50, 50),
            "demo-trip-avery": (50, 60),
            "demo-trip-sam": (60, 75),
        ]
        var changed = false
        for index in db.trips.indices {
            if let cap = limits[db.trips[index].id], db.trips[index].maxItemPounds == nil {
                db.trips[index].maxItemPounds = cap.0
                db.trips[index].maxTotalPounds = cap.1
                db.trips[index].allowsCustom = db.trips[index].id == "demo-trip-sam"
                changed = true
            }
            if db.trips[index].maxDetourMinutes == nil {
                switch db.trips[index].id {
                case "demo-trip-jordan", "demo-trip-jordan-later":
                    db.trips[index].maxDetourMinutes = 30
                    db.trips[index].maxDetourMiles = 15
                    changed = true
                case "demo-trip-avery":
                    db.trips[index].maxDetourMinutes = 20
                    db.trips[index].maxDetourMiles = 15
                    changed = true
                case "demo-trip-sam":
                    db.trips[index].maxDetourMinutes = 45
                    db.trips[index].maxDetourMiles = 25
                    changed = true
                default:
                    break
                }
            }
        }
        if !db.users.contains(where: { $0.id == "demo-taylor" }) {
            db.users.append(StoredUser(id: "demo-taylor", email: "taylor@demo.local", passwordHash: Self.hash("demo", salt: "demo-taylor"), passwordSalt: "demo-taylor", displayName: "Taylor Brooks", avatarUrl: nil, paymentHandle: nil, createdAt: Self.stamp(), intent: AccountUse.order.rawValue))
            changed = true
        }
        if seedHistoryIfNeeded() { changed = true }
        for index in db.orders.indices where db.orders[index].orderingModel == nil && db.orders[index].merchandiseCents != nil {
            db.orders[index].orderingModel = "runner_purchase"
            changed = true
        }
        if changed { try? save() }
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
        case ("recurrence", "POST"):
            guard let id = text(payload["trip_id"], max: 80) else { throw APIError(message: "Choose a trip.", code: "bad_request") }
            try repeatTrip(user: user, id: id, cadence: text(payload["cadence"], max: 20) ?? "weekly")
            return try encode(Okay(ok: true))
        case ("orders", "GET"):
            if remindMissingHandoff(for: user) { try? save() }
            if let id = query["id"] {
                let order = db.orders.first { $0.id == id && ($0.customerId == user.id || $0.driverId == user.id) }
                return try encode(OrderBox(order: order.map { presented($0, viewer: user) }))
            }
            let driver = query["role"] == "driver"
            let orders = db.orders
                .filter { driver ? $0.driverId == user.id : $0.customerId == user.id }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(100)
                .map { presented($0, viewer: user) }
            return try encode(Array(orders))
        case ("orders", "POST"):
            return try encode(try createOrder(user: user, body: payload))
        case ("orders", "PATCH"):
            guard let id = query["id"] else { throw APIError(message: "Missing order.", code: "bad_request") }
            return try encode(try patchOrder(user: user, id: id, body: payload))
        case ("messages", "GET"):
            guard let id = query["order"] else { throw APIError(message: "Missing order.", code: "bad_request") }
            return try encode(MessageList(messages: messages(for: id, user: user)))
        case ("messages", "POST"):
            return try encode(try postMessage(user: user, body: payload))
        case ("demo-actors", "GET"):
            return try encode(DemoActorList(actors: demoActors()))
        case ("demo-actor", "POST"):
            guard let id = text(payload["id"], max: 40) else {
                throw APIError(message: "Choose a demo person.", code: "bad_request")
            }
            return try encode(try switchDemo(id))
        case ("notices", "GET"):
            let rows = (db.notices ?? []).filter { $0.recipientId == user.id }.sorted { $0.createdAt > $1.createdAt }
            return try encode(NoticeList(notices: rows))
        case ("notices", "PATCH"):
            try markNotices(user: user, body: payload)
            return try encode(Okay(ok: true))
        case ("saved-requests", "GET"):
            let rows = (db.savedRequests ?? []).filter { $0.customerId == user.id && $0.status != "deleted" }
            return try encode(SavedRequestList(requests: rows))
        case ("saved-requests", "POST"):
            return try encode(try saveRequest(user: user, body: payload))
        case ("saved-requests", "PATCH"):
            return try encode(try updateSavedRequest(user: user, body: payload))
        case ("saved-places", "GET"):
            let rows = (db.savedPlaces ?? []).filter { $0.userId == user.id }
            return try encode(SavedPlaceList(places: rows))
        case ("saved-places", "POST"):
            return try encode(try togglePlace(user: user, body: payload))
        case ("preferences", "PATCH"):
            guard let index = db.users.firstIndex(where: { $0.id == user.id }) else {
                throw APIError(message: "Your profile couldn't be loaded.")
            }
            if payload["notify"] != nil {
                let value = (payload["notify"] as? Bool) ?? (payload["notify"] as? NSNumber)?.boolValue ?? true
                db.users[index].notify = value
            }
            try save()
            return try encode(profile(db.users[index]))
        case ("demo-delete", "POST"):
            try deleteDemoAccount(user: user)
            return try encode(Okay(ok: true))
        case ("support", "GET"):
            return try encode(SupportList(cases: supportCases(for: user)))
        case ("support", "POST"):
            return try encode(try openCase(user: user, body: payload))
        case ("support", "PATCH"):
            return try encode(try updateCase(user: user, body: payload))
        case ("ledger", "GET"):
            return try encode(LedgerList(entries: ledger(for: user, orderId: query["order"])))
        case ("support-refund", "POST"):
            guard let id = text(payload["order_id"], max: 80) else { throw APIError(message: "Choose an order.", code: "bad_request") }
            try supportRefund(user: user, orderId: id)
            return try encode(Okay(ok: true))
        case ("payout", "POST"):
            try simulatePayout(user: user)
            return try encode(Okay(ok: true))
        case ("demo-reset", "POST"):
            try resetDemo(user: user)
            return try encode(Okay(ok: true))
        case ("demo-publish", "POST"):
            let city = try required(payload["city"], max: 80, message: "Choose a city.")
            try publishMatchingTrip(city: city)
            return try encode(Okay(ok: true))
        case ("demo-scenario", "POST"):
            let number = Int(Self.number(payload["scenario"]) ?? 0)
            return try encode(try prepareScenario(user: user, number: number))
        case ("inbox-count", "GET"):
            return try encode(inboxCount(for: user))
        case ("attachment", "GET"):
            guard let id = query["id"] else { throw APIError(message: "Missing order.", code: "bad_request") }
            return try encode(attachment(for: user, orderId: id))
        case ("draft", "GET"):
            return try encode(loadDraft(userId: user.id))
        case ("draft", "POST"):
            try saveDraft(user: user, body: payload)
            return try encode(Okay(ok: true))
        case ("draft", "DELETE"):
            removeDraft(userId: user.id)
            return try encode(Okay(ok: true))
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
            return trip.status == "scheduled" && (Self.parse(trip.departureAt) ?? .distantPast) >= DemoClock.now
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
        guard let when = Self.parse(departure), when.timeIntervalSince(DemoClock.now) > -5 * 60 else {
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
            status: text(draft["status"], max: 20) == "draft" ? "draft" : "scheduled",
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
        matchSavedRequests(to: saved)
        try save()
        return presented(saved)
    }

    private func stops(_ value: Any?, tripId: String?) throws -> [TripStop] {
        let rows = (value as? [[String: Any]] ?? []).prefix(10)
        return try rows.enumerated().map { index, stop in
            TripStop(
                id: text(stop["id"], max: 80) ?? UUID().uuidString,
                tripId: tripId,
                placeId: text(stop["place_id"], max: 200),
                restaurantName: try required(stop["restaurant_name"], max: 120, message: "Each stop needs a restaurant name."),
                address: text(stop["address"], max: 200),
                lat: try coordinate(stop["lat"], "A stop is missing its location."),
                lng: try coordinate(stop["lng"], "A stop is missing its location."),
                stopOrder: index,
                kind: text(stop["kind"], max: 20) ?? "pickup",
                available: flag(stop["available"]) ?? true,
                arrivesAt: text(stop["arrives_at"], max: 40)
            )
        }
    }

    private func repeatTrip(user: StoredUser, id: String, cadence: String) throws {
        guard let source = db.trips.first(where: { $0.id == id && $0.driverId == user.id }) else {
            throw APIError(message: "Choose one of your trips.", code: "not_found")
        }
        guard cadence == "weekly" || cadence == "biweekly" else {
            throw APIError(message: "Choose weekly or every other week.", code: "bad_request")
        }
        let step = cadence == "weekly" ? 7 : 14
        guard let start = Self.parse(source.departureAt) else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .current
        let horizon = DemoClock.now.addingTimeInterval(28 * 86_400)
        guard var cursor = calendar.date(byAdding: .day, value: step, to: start) else {
            throw APIError(message: "That local departure time doesn't exist. Choose another time.", code: "bad_request")
        }
        while cursor <= horizon {
            let key = "\(source.id)|\(cadence)|\(Self.plain.string(from: cursor))"
            if !db.trips.contains(where: { $0.templateId == key }) {
                var copy = source
                copy.id = UUID().uuidString
                copy.departureAt = Self.plain.string(from: cursor)
                copy.status = "draft"
                copy.recurrence = cadence
                copy.templateId = key
                copy.occurrenceEdited = nil
                copy.createdAt = Self.stamp()
                copy.stops = (source.stops ?? []).enumerated().map { index, stop in
                    var item = stop
                    item.id = UUID().uuidString
                    item.tripId = copy.id
                    item.stopOrder = index
                    return item
                }
                db.trips.append(copy)
            }
            guard let next = calendar.date(byAdding: .day, value: step, to: cursor) else { break }
            cursor = next
        }
        if let index = db.trips.firstIndex(where: { $0.id == source.id }) {
            db.trips[index].recurrence = cadence
        }
        try save()
    }

    private func patchTrip(user: StoredUser, id: String, body: [String: Any]) throws {
        guard let index = db.trips.firstIndex(where: { $0.id == id && $0.driverId == user.id }) else {
            throw APIError(message: "Trip not found.", code: "not_found")
        }
        if body.keys.contains("notes") {
            db.trips[index].notes = text(body["notes"], max: 280)
        }
        let routeChanged = try applyTripEdits(index: index, body: body)
        if routeChanged { expireRequestedQuotes(tripId: id) }
        if db.trips[index].templateId != nil, body.keys.contains(where: { !["status", "scope"].contains($0) }) {
            db.trips[index].occurrenceEdited = true
        }
        if text(body["scope"], max: 20) == "series" {
            guard db.trips[index].templateId == nil else {
                throw APIError(message: "Edit the original trip to change the series. This date stays separate.", code: "bad_request")
            }
            copySeries(from: id)
        }
        guard body.keys.contains("status") else {
            try save()
            return
        }
        let status = text(body["status"], max: 20) ?? db.trips[index].status
        let current = db.trips[index].status
        switch (current, status) {
        case ("draft", "scheduled"):
            db.trips[index].status = "scheduled"
            matchSavedRequests(to: db.trips[index])
        case ("scheduled", "requests_closed"):
            db.trips[index].status = "requests_closed"
        case ("requests_closed", "scheduled"):
            guard (Self.parse(db.trips[index].departureAt) ?? .distantPast) >= DemoClock.now else {
                throw APIError(message: "This trip has already departed.", code: "bad_request")
            }
            db.trips[index].status = "scheduled"
        case ("scheduled", "in_progress"), ("requests_closed", "in_progress"):
            db.trips[index].status = "in_progress"
        case ("in_progress", "completed"), ("scheduled", "completed"), ("requests_closed", "completed"):
            let unresolved = db.orders.contains { $0.tripId == id && ($0.status == .accepted || $0.status == .restaurantConfirmed || $0.status == .pickedUp || $0.status == .onTheWay || $0.status == .arriving) }
            guard !unresolved else {
                throw APIError(message: "Finish or resolve every accepted pickup before completing the trip.", code: "bad_request")
            }
            db.trips[index].status = "completed"
        case (_, "cancelled") where current != "completed" && current != "cancelled":
            db.trips[index].status = "cancelled"
            let tripId = db.trips[index].id
            for orderIndex in db.orders.indices where db.orders[orderIndex].tripId == tripId {
                let orderStatus = db.orders[orderIndex].status
                guard orderStatus == .requested || orderStatus == .accepted || orderStatus == .restaurantConfirmed else { continue }
                let effect = DemoRules.cancellationEffect(status: orderStatus, orderingModel: db.orders[orderIndex].orderingModel)
                db.orders[orderIndex].status = .cancelled
                db.orders[orderIndex].cancelledAt = Self.stamp()
                db.orders[orderIndex].cancelledBy = user.id
                if orderStatus == .restaurantConfirmed && db.orders[orderIndex].isRunnerPurchase {
                    let delivery = db.orders[orderIndex].quoteCents ?? 0
                    postLedger(orderId: db.orders[orderIndex].id, kind: "refund", cents: delivery, key: "refund:\(db.orders[orderIndex].id)")
                    let goods = db.orders[orderIndex].actualMerchandiseCents ?? db.orders[orderIndex].merchandiseCents ?? 0
                    if goods > 0 {
                        postLedger(orderId: db.orders[orderIndex].id, kind: "merchandise-unrefunded", cents: goods, key: "merchandise-unrefunded:\(db.orders[orderIndex].id)")
                    }
                    notify(recipient: db.orders[orderIndex].customerId, type: "cancellation", orderId: db.orders[orderIndex].id, title: "Trip cancelled", body: "The simulated delivery fee was refunded. The merchant purchase is not automatically refunded.")
                } else if effect == "release" {
                    releaseBoth(db.orders[orderIndex])
                    notify(recipient: db.orders[orderIndex].customerId, type: "cancellation", orderId: db.orders[orderIndex].id, title: "Trip cancelled", body: "The request was released before acceptance. Nothing was captured.")
                } else if effect == "refund" {
                    refundUnpurchased(db.orders[orderIndex])
                    notify(recipient: db.orders[orderIndex].customerId, type: "cancellation", orderId: db.orders[orderIndex].id, title: "Trip cancelled", body: "The runner cancelled before buying. The simulated merchandise and delivery amounts were refunded.")
                }
            }
        default:
            throw APIError(message: "That trip update isn't allowed.", code: "bad_request")
        }
        try save()
    }

    private func applyTripEdits(index: Int, body: [String: Any]) throws -> Bool {
        let id = db.trips[index].id
        let status = db.trips[index].status
        if status == "completed" || status == "cancelled" {
            let structural = body.keys.contains { !["notes", "status", "scope"].contains($0) }
            if structural { throw APIError(message: "This trip is already finished.", code: "bad_request") }
            return false
        }
        var routeChanged = false
        if body["max_orders"] != nil {
            let cap = Int(Self.number(body["max_orders"]) ?? -1)
            let taken = committedCount(id)
            guard (1...6).contains(cap), cap >= taken else {
                throw APIError(message: "Capacity has to stay between the reserved pickups and 6.", code: "bad_request")
            }
            db.trips[index].maxOrders = cap
        }
        if let cityName = text(body["origin_city"], max: 80) {
            guard let city = Places.city(named: cityName) else {
                throw APIError(message: "That city isn't in the demo list.", code: "bad_request")
            }
            if hasCommitment(id), city.name != db.trips[index].originCity {
                throw APIError(message: "Accepted pickups keep this origin.", code: "bad_request")
            }
            if city.name != db.trips[index].originCity {
                db.trips[index].originCity = city.name
                db.trips[index].originLat = city.lat
                db.trips[index].originLng = city.lng
                routeChanged = true
            }
        }
        if body["departure_at"] != nil {
            let raw = try required(body["departure_at"], max: 40, message: "Departure needs a time.")
            guard let when = Self.parse(raw), when >= DemoClock.now else {
                throw APIError(message: "Departure has to stay in the future.", code: "bad_request")
            }
            let stored = Self.plain.string(from: when)
            if stored != db.trips[index].departureAt {
                if hasCommitment(id) { throw APIError(message: "Accepted pickups keep this departure.", code: "bad_request") }
                db.trips[index].departureAt = stored
                routeChanged = true
            }
        }
        if body.keys.contains("cutoff_at") {
            let next: String?
            if let raw = text(body["cutoff_at"], max: 40) {
                guard let cutoff = Self.parse(raw), let departure = Self.parse(db.trips[index].departureAt), cutoff < departure else {
                    throw APIError(message: "The cutoff has to be before departure.", code: "bad_request")
                }
                next = Self.plain.string(from: cutoff)
            } else {
                next = nil
            }
            if next != db.trips[index].cutoffAt {
                if hasCommitment(id) { throw APIError(message: "Accepted pickups keep this cutoff.", code: "bad_request") }
                db.trips[index].cutoffAt = next
                routeChanged = true
            }
        }
        if body.keys.contains("eta_at") {
            let next: String?
            if let raw = text(body["eta_at"], max: 40) {
                guard let eta = Self.parse(raw), let departure = Self.parse(db.trips[index].departureAt), eta > departure else {
                    throw APIError(message: "Arrival has to be after departure.", code: "bad_request")
                }
                next = Self.plain.string(from: eta)
            } else {
                next = nil
            }
            if next != db.trips[index].etaAt {
                if hasCommitment(id) { throw APIError(message: "Accepted pickups keep this arrival.", code: "bad_request") }
                db.trips[index].etaAt = next
            }
        }
        if body["max_detour_minutes"] != nil || body["max_detour_miles"] != nil || body["max_item_pounds"] != nil || body["max_total_pounds"] != nil || body["allows_custom"] != nil {
            if hasCommitment(id) { throw APIError(message: "Accepted pickups keep these limits.", code: "bad_request") }
            if let minutes = Self.number(body["max_detour_minutes"]), minutes != db.trips[index].maxDetourMinutes {
                guard minutes >= 0 else { throw APIError(message: "Extra minutes can't be negative.", code: "bad_request") }
                db.trips[index].maxDetourMinutes = minutes
                routeChanged = true
            }
            if let miles = Self.number(body["max_detour_miles"]), miles != db.trips[index].maxDetourMiles {
                guard miles >= 0 else { throw APIError(message: "Extra miles can't be negative.", code: "bad_request") }
                db.trips[index].maxDetourMiles = miles
                routeChanged = true
            }
            if let item = Self.number(body["max_item_pounds"]), item != db.trips[index].maxItemPounds {
                guard item > 0 else { throw APIError(message: "The item weight limit has to be positive.", code: "bad_request") }
                db.trips[index].maxItemPounds = item
                routeChanged = true
            }
            if let total = Self.number(body["max_total_pounds"]), total != db.trips[index].maxTotalPounds {
                guard total > 0 else { throw APIError(message: "The total weight limit has to be positive.", code: "bad_request") }
                db.trips[index].maxTotalPounds = total
                routeChanged = true
            }
            if let custom = flag(body["allows_custom"]), custom != db.trips[index].allowsCustom {
                db.trips[index].allowsCustom = custom
                routeChanged = true
            }
        }
        if body["stops"] != nil {
            let next = try stops(body["stops"], tripId: id)
            try validateStops(next, trip: db.trips[index])
            let previous = db.trips[index].stops ?? []
            if !sameRoute(previous, next) {
                try protectCommittedStops(previous: previous, next: next, tripId: id)
                db.trips[index].stops = next
                routeChanged = true
            }
        }
        if let cutoff = db.trips[index].cutoffAt, let departure = Self.parse(db.trips[index].departureAt), let cut = Self.parse(cutoff), cut >= departure {
            throw APIError(message: "The cutoff has to be before departure.", code: "bad_request")
        }
        return routeChanged
    }

    private func committedCount(_ tripId: String) -> Int {
        db.orders.filter { $0.tripId == tripId && Self.active.contains($0.status) }.count
    }

    private func hasCommitment(_ tripId: String) -> Bool { committedCount(tripId) > 0 }

    private func validateStops(_ rows: [TripStop], trip: Trip) throws {
        guard rows.count <= 8 else { throw APIError(message: "A trip can list up to 8 stops.", code: "bad_request") }
        let allowance = (trip.maxDetourMiles ?? 40) + 1
        for stop in rows {
            guard abs(stop.lat) <= 90, abs(stop.lng) <= 180 else {
                throw APIError(message: "A stop is missing its location.", code: "bad_request")
            }
            if milesFromCorridor(lat: stop.lat, lng: stop.lng, trip: trip) > allowance {
                throw APIError(message: "\(stop.restaurantName) is farther than this trip's extra miles.", code: "bad_request")
            }
            if stop.available == false, db.orders.contains(where: { $0.tripId == trip.id && Self.active.contains($0.status) && stopMatches(stop, order: $0) }) {
                throw APIError(message: "A stop with an accepted pickup has to stay available.", code: "bad_request")
            }
        }
    }

    private func protectCommittedStops(previous: [TripStop], next: [TripStop], tripId: String) throws {
        let committed = db.orders.filter { $0.tripId == tripId && Self.active.contains($0.status) }
        for order in committed {
            guard let kept = previous.first(where: { stopMatches($0, order: order) }) else { continue }
            guard next.contains(where: { stopMatches($0, order: order) || $0.id == kept.id }) else {
                throw APIError(message: "\(order.restaurantName) is already accepted. That stop stays on the trip.", code: "bad_request")
            }
        }
    }

    private func stopMatches(_ stop: TripStop, order: Order) -> Bool {
        if let place = order.restaurantPlaceId, let stopPlace = stop.placeId, place == stopPlace { return true }
        guard stop.restaurantName.caseInsensitiveCompare(order.restaurantName) == .orderedSame else { return false }
        return abs(stop.lat - order.restaurantLat) < 0.02 && abs(stop.lng - order.restaurantLng) < 0.02
    }

    private func sameRoute(_ previous: [TripStop], _ next: [TripStop]) -> Bool {
        guard previous.count == next.count else { return false }
        return zip(previous, next).allSatisfy { old, new in
            old.id == new.id && old.placeId == new.placeId && old.restaurantName == new.restaurantName && old.lat == new.lat && old.lng == new.lng && old.available == new.available && old.arrivesAt == new.arrivesAt
        }
    }

    private func milesFromCorridor(lat: Double, lng: Double, trip: Trip) -> Double {
        let mid = (trip.originLat + trip.destinationLat) / 2 * .pi / 180
        func project(_ lat: Double, _ lng: Double) -> (Double, Double) {
            (lng * 69.172 * cos(mid), lat * 69.0)
        }
        let start = project(trip.originLat, trip.originLng)
        let end = project(trip.destinationLat, trip.destinationLng)
        let point = project(lat, lng)
        let dx = end.0 - start.0
        let dy = end.1 - start.1
        let length = dx * dx + dy * dy
        let t = length == 0 ? 0 : max(0, min(1, ((point.0 - start.0) * dx + (point.1 - start.1) * dy) / length))
        return hypot(point.0 - (start.0 + t * dx), point.1 - (start.1 + t * dy))
    }

    private func expireRequestedQuotes(tripId: String) {
        for index in db.orders.indices where db.orders[index].tripId == tripId && db.orders[index].status == .requested {
            if db.orders[index].quoteState == "quoted" || db.orders[index].quoteState == "customer_approval" {
                postLedger(orderId: db.orders[index].id, kind: "release", cents: db.orders[index].quoteCents ?? db.orders[index].previousQuoteCents ?? 0, key: "release:\(db.orders[index].id)")
                if let goods = db.orders[index].merchandiseCents, goods > 0 {
                    postLedger(orderId: db.orders[index].id, kind: "merchandise-release", cents: goods, key: "merchandise-release:\(db.orders[index].id)")
                }
            }
            db.orders[index].quoteState = "expired"
            db.orders[index].deliveryFee = nil
            db.orders[index].counterCents = nil
            notify(recipient: db.orders[index].customerId, type: "quote", orderId: db.orders[index].id, title: "Quote expired", body: "The trip changed. Submit a new request. Nothing was captured.")
        }
    }

    private func copySeries(from sourceId: String) {
        guard let source = db.trips.first(where: { $0.id == sourceId }) else { return }
        let prefix = "\(sourceId)|"
        for index in db.trips.indices {
            guard db.trips[index].templateId?.hasPrefix(prefix) == true else { continue }
            guard db.trips[index].occurrenceEdited != true else { continue }
            guard !hasCommitment(db.trips[index].id) else { continue }
            let childId = db.trips[index].id
            db.trips[index].notes = source.notes
            db.trips[index].maxOrders = source.maxOrders
            db.trips[index].maxDetourMinutes = source.maxDetourMinutes
            db.trips[index].maxDetourMiles = source.maxDetourMiles
            db.trips[index].maxItemPounds = source.maxItemPounds
            db.trips[index].maxTotalPounds = source.maxTotalPounds
            db.trips[index].allowsCustom = source.allowsCustom
            db.trips[index].stops = (source.stops ?? []).enumerated().map { offset, stop in
                var copy = stop
                copy.id = UUID().uuidString
                copy.tripId = childId
                copy.stopOrder = offset
                return copy
            }
            expireRequestedQuotes(tripId: childId)
        }
    }

    private func createOrder(user: StoredUser, body: [String: Any]) throws -> Order {
        guard let tripId = text(body["trip_id"], max: 80), let trip = db.trips.first(where: { $0.id == tripId }) else {
            throw APIError(message: "Trip not found.", code: "bad_request")
        }
        guard user.id != trip.driverId else {
            throw APIError(message: "You cannot request delivery on your own trip.", code: "bad_request")
        }
        guard trip.status == "scheduled", (Self.parse(trip.departureAt) ?? .distantPast) >= DemoClock.now else {
            throw APIError(message: "This trip is no longer accepting requests.", code: "bad_request")
        }
        if let cap = trip.maxDetourMinutes, let extra = Self.number(body["extra_seconds"]), extra / 60 > cap {
            throw APIError(message: "That stop is over this trip's detour time.", code: "bad_request")
        }
        if let cap = trip.maxDetourMiles, let meters = Self.number(body["extra_meters"]), meters / 1609.344 > cap {
            throw APIError(message: "That stop is over this trip's detour distance.", code: "bad_request")
        }
        let destinationType = text(body["destination_type"], max: 20)
        guard destinationType == "campus" || destinationType == "address" else {
            throw APIError(message: "Choose a campus meetup or a street address.", code: "bad_request")
        }
        let placeSource = text(body["place_source"], max: 20)
        let estimateSource = text(body["estimate_source"], max: 20)
        let parsedLines = orderLines(body["lines"])
        var pricingBody = body
        if !parsedLines.isEmpty {
            let confirmed = parsedLines.allSatisfy { $0.weightConfirmed && ($0.weightPounds ?? 0) > 0 }
            let total = parsedLines.reduce(0.0) { $0 + (($1.weightPounds ?? 0) * Double($1.quantity)) }
            pricingBody["weight_pounds"] = total
            pricingBody["weight_confirmed"] = confirmed
            pricingBody["bulky"] = parsedLines.contains { $0.bulky }
        }
        let priced = Self.price(pricingBody)
        let stamp = Self.stamp()
        let reference = text(body["pickup_reference"], max: 80) ?? "Customer order"
        let operationKey = text(body["operation_key"], max: 80)
        if let operationKey, let existing = db.orders.first(where: { $0.operationKey == operationKey && $0.customerId == user.id }) {
            return presented(existing, viewer: user)
        }
        var order = Order(
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
            placeSource: ["google", "osm", "sample"].contains(placeSource ?? "") ? placeSource : nil,
            destinationType: destinationType ?? "campus",
            destinationLabel: try required(body["destination_label"], max: 160, message: "Choose a handoff spot."),
            destinationLat: try coordinate(body["destination_lat"], "Handoff location is missing."),
            destinationLng: try coordinate(body["destination_lng"], "Handoff location is missing."),
            detourMinutes: Self.number(body["detour_minutes"]),
            deliveryFee: priced.fee,
            estimateSource: ["google", "osrm", "straight_line", "fixture"].contains(estimateSource ?? "") ? estimateSource : nil,
            estimatedArrivalAt: text(body["estimated_arrival_at"], max: 40),
            customerNote: text(body["customer_note"], max: 500),
            itemSummary: parsedLines.isEmpty ? text(body["item_summary"], max: 200) : parsedLines.map { "\($0.quantity)× \($0.name)" }.joined(separator: ", "),
            quoteCents: priced.total,
            runnerShareCents: priced.share,
            quoteState: priced.state,
            confirmationPin: nil,
            pinAttempts: 0,
            pickupName: reference,
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
        order.operationKey = operationKey
        order.weightPounds = Self.number(pricingBody["weight_pounds"])
        order.lines = parsedLines.isEmpty ? nil : parsedLines
        let kind = text(body["pickup_kind"], max: 20)
        let personal = kind == "personal" || flag(body["personal_item"]) == true
        order.personalItem = personal
        if let requestText = text(body["request_text"], max: 800) {
            order.itemSummary = requestText
        }
        if parsedLines.isEmpty {
            guard !(order.itemSummary ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw APIError(message: "Add pickup details.", code: "bad_request")
            }
            order.orderingModel = personal ? "personal" : "customer_paid"
            order.merchandiseCents = nil
            order.contactLabel = text(body["contact_label"], max: 80)
            order.accessInstructions = text(body["access_instructions"], max: 500)
            order.pickupWindowLabel = text(body["pickup_window"], max: 120)
            order.itemQuantity = text(body["item_quantity"], max: 40)
            order.fragile = flag(body["fragile"])
            order.bulkyItem = flag(body["bulky"])
            if personal {
                guard order.contactLabel != nil else {
                    throw APIError(message: "Add who will meet the runner. A phone number is not required.", code: "bad_request")
                }
                guard order.pickupWindowLabel != nil else {
                    throw APIError(message: "Choose when the item will be ready.", code: "bad_request")
                }
            } else if flag(body["already_ordered"]) == true {
                try storeHandoff(&order, body: body, trip: trip, creating: true)
                order.alreadyOrdered = true
            }
            if let encoded = text(body["screenshot_base64"], max: 12_000_000) {
                order.screenshotName = try storeScreenshot(encoded, orderId: order.id)
            }
            if order.handoffSubmittedAt == nil { order.pickupName = nil }
        }
        order.purchaseState = nil
        if let departure = Self.parse(trip.departureAt) {
            let deadline = DemoRules.quoteDeadline(submitted: DemoClock.now, cutoff: departure)
            order.quoteExpiresAt = Self.plain.string(from: deadline)
        }
        db.orders.append(order)
        if order.quoteState == "quoted", let cents = order.quoteCents {
            postLedger(orderId: order.id, kind: "delivery-authorize", cents: cents, key: "delivery-authorize:\(order.id)")
            if order.isRunnerPurchase, let goods = order.merchandiseCents, goods > 0 {
                postLedger(orderId: order.id, kind: "merchandise-authorize", cents: goods, key: "merchandise-authorize:\(order.id)")
            }
            let noun = order.orderingModel == "personal" ? "A personal-item pickup" : order.restaurantName
            notify(recipient: order.driverId, type: "request", orderId: order.id, title: "New pickup request", body: "\(noun) is waiting for you.")
        }
        try save()
        return presented(order, viewer: user)
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

        let editingPickup = flag(body["handoff_submit"]) != true && ["pickup_name", "restaurant_order_number", "pickup_ready_at", "pickup_instructions"].contains { body.keys.contains($0) }
        if editingPickup {
            guard isCustomer, order.status == .accepted || order.status == .restaurantConfirmed else {
                throw APIError(message: "Pickup details can only be added by the customer after the driver accepts.", code: "forbidden")
            }
            if body.keys.contains("pickup_name") { order.pickupName = text(body["pickup_name"], max: 80) }
            if body.keys.contains("restaurant_order_number") { order.restaurantOrderNumber = text(body["restaurant_order_number"], max: 60) }
            if body.keys.contains("pickup_ready_at") { order.pickupReadyAt = text(body["pickup_ready_at"], max: 40) }
            if body.keys.contains("pickup_instructions") { order.pickupInstructions = text(body["pickup_instructions"], max: 500) }
        }

        if body.keys.contains("counter_cents") {
            guard isDriver, order.status == .requested || order.quoteState == "review" else {
                throw APIError(message: "A counteroffer is only available on an open request.", code: "bad_request")
            }
            let cents = Int(Self.number(body["counter_cents"]) ?? 0)
            guard DemoRules.counterofferAllowed(cents) else {
                throw APIError(message: "Offer a delivery fee from $1 to $250.", code: "bad_request")
            }
            guard let reason = text(body["counter_reason"], max: 200) else {
                throw APIError(message: "Add a reason for the new price.", code: "bad_request")
            }
            try enforceLimits(order)
            let cutoff = db.trips.first { $0.id == order.tripId }.flatMap { Self.parse($0.departureAt) } ?? DemoClock.now.addingTimeInterval(15 * 60)
            order.previousQuoteCents = order.quoteCents
            order.counterCents = cents
            order.counterReason = reason
            order.counterExpiresAt = Self.plain.string(from: DemoRules.quoteDeadline(submitted: DemoClock.now, cutoff: cutoff))
            order.quoteState = "customer_approval"
            notify(recipient: order.customerId, type: "counteroffer", orderId: order.id, title: "New price to review", body: reason)
        }

        if text(body["counter_decision"], max: 20) == "accept" {
            guard isCustomer, order.quoteState == "customer_approval", let cents = order.counterCents else {
                throw APIError(message: "There isn't a price waiting for you.", code: "bad_request")
            }
            if let expiry = order.counterExpiresAt, let when = Self.parse(expiry), when < DemoClock.now {
                order.quoteState = "expired"
                db.orders[index] = order
                try save()
                throw APIError(message: "That price expired.", code: "bad_request")
            }
            try enforceLimits(order)
            let load = db.orders.filter { $0.tripId == order.tripId && $0.id != order.id && Self.active.contains($0.status) }.count
            let cap = db.trips.first { $0.id == order.tripId }?.maxOrders ?? 0
            guard load < cap else { throw APIError(message: "This trip is already at its order limit.", code: "bad_request") }
            postLedger(orderId: order.id, kind: "release", cents: order.previousQuoteCents ?? 0, key: "release-counter:\(order.id)")
            order.quoteCents = cents
            order.runnerShareCents = DemoRules.runnerShare(of: cents)
            order.deliveryFee = Double(cents) / 100
            order.quoteState = "quoted"
            order.status = .accepted
            order.acceptedAt = Self.stamp()
            postLedger(orderId: order.id, kind: "capture", cents: cents, key: "capture:\(order.id)")
            if order.isRunnerPurchase, let goods = order.merchandiseCents, goods > 0 {
                postLedger(orderId: order.id, kind: "merchandise-capture", cents: goods, key: "merchandise-capture:\(order.id)")
            }
            notify(recipient: order.driverId, type: "counteroffer", orderId: order.id, title: "Price approved", body: "The customer approved the new delivery fee.")
        }

        if text(body["counter_decision"], max: 20) == "decline" {
            guard isCustomer, order.quoteState == "customer_approval" else {
                throw APIError(message: "There isn't a price waiting for you.", code: "bad_request")
            }
            order.quoteState = order.previousQuoteCents == nil ? "review" : "quoted"
            order.counterCents = nil
            notify(recipient: order.driverId, type: "counteroffer", orderId: order.id, title: "Price declined", body: "The customer kept the earlier terms.")
        }

        if isDriver, let minutes = Self.number(body["delay_minutes"]), minutes > 0, minutes <= 180 {
            let reason = text(body["delay_reason"], max: 160) ?? "The runner updated the arrival window."
            order.customerNote = reason
            notify(recipient: order.customerId, type: "delay", orderId: order.id, title: "Arrival updated", body: "About \(Int(minutes)) more minutes. \(reason)")
        }

        if flag(body["handoff_submit"]) == true {
            guard isCustomer else { throw APIError(message: "Only the customer can add pickup confirmation.", code: "forbidden") }
            guard order.usesCustomerHandoff else { throw APIError(message: "This order uses an earlier purchase record.", code: "bad_request") }
            let trip = db.trips.first { $0.id == order.tripId }
            try storeHandoff(&order, body: body, trip: trip, creating: false)
        }

        if text(body["details_decision"], max: 20) == "received" {
            guard isDriver, order.usesCustomerHandoff, order.handoffComplete else {
                throw APIError(message: "Pickup details are not ready to review.", code: "bad_request")
            }
            guard order.pendingReadyAt == nil, order.placeChangePending != true else {
                throw APIError(message: "Agree on the changed time or branch before marking the details received.", code: "bad_request")
            }
            order.detailsReviewedAt = Self.stamp()
            order.detailsChangedAt = nil
            if order.status == .accepted { order.status = .restaurantConfirmed }
            notify(recipient: order.customerId, type: "handoff-reviewed", orderId: order.id, title: "Runner reviewed details", body: "Your runner reviewed the pickup details you submitted.")
        }

        if text(body["window_decision"], max: 20) == "accept" {
            guard isDriver, let ready = order.pendingReadyAt else {
                throw APIError(message: "There isn't a new pickup time waiting for you.", code: "bad_request")
            }
            order.pickupReadyAt = ready
            if let label = order.pendingWindowLabel { order.pickupWindowLabel = label }
            order.pendingReadyAt = nil
            order.pendingWindowLabel = nil
            order.detailsReviewedAt = nil
            order.detailsChangedAt = Self.stamp()
            notify(recipient: order.customerId, type: "window-accepted-\(Self.stamp())", orderId: order.id, title: "Pickup time agreed", body: "The runner agreed to the new pickup time. The delivery fee was not changed.", again: true)
        }

        if text(body["window_decision"], max: 20) == "decline" {
            guard isDriver, order.pendingReadyAt != nil else {
                throw APIError(message: "There isn't a new pickup time waiting for you.", code: "bad_request")
            }
            order.pendingReadyAt = nil
            order.pendingWindowLabel = nil
            notify(recipient: order.customerId, type: "window-declined-\(Self.stamp())", orderId: order.id, title: "Pickup time kept", body: "The runner kept the earlier pickup time.", again: true)
        }

        if text(body["place_decision"], max: 20) == "accept" {
            guard isDriver, order.placeChangePending == true else {
                throw APIError(message: "There isn't a branch change waiting for you.", code: "bad_request")
            }
            order.placeChangePending = false
            order.detailsReviewedAt = nil
            order.detailsChangedAt = Self.stamp()
            notify(recipient: order.customerId, type: "place-accepted-\(Self.stamp())", orderId: order.id, title: "Branch change noted", body: "The runner kept the accepted delivery fee. Review the pickup details again before collection.", again: true)
        }

        if isDriver, body["purchase_actual_cents"] != nil {
            guard order.isRunnerPurchase else {
                throw APIError(message: "The customer pays the store. Add pickup confirmation instead of a merchandise charge.", code: "bad_request")
            }
            guard order.status == .accepted, order.personalItem != true else {
                throw APIError(message: "Accept the request before recording a purchase.", code: "bad_request")
            }
            guard order.purchaseState != "placed" else {
                throw APIError(message: "The purchase is already recorded.", code: "bad_request")
            }
            let actual = Int(Self.number(body["purchase_actual_cents"]) ?? -1)
            guard actual >= 0 else { throw APIError(message: "Enter the actual merchandise total.", code: "bad_request") }
            let approved = order.merchandiseCents ?? 0
            order.restaurantOrderNumber = text(body["purchase_reference"], max: 60)
            if actual > approved {
                order.revisionMerchandiseCents = actual
                order.purchaseState = "revision"
                notify(recipient: order.customerId, type: "counteroffer", orderId: order.id, title: "Merchandise total changed", body: "The store total is higher than the screenshot. Approve it before the runner continues.")
            } else {
                order.actualMerchandiseCents = actual
                order.purchaseState = "placed"
                order.status = .restaurantConfirmed
                order.restaurantOrderConfirmedAt = Self.stamp()
                if actual < approved {
                    postLedger(orderId: order.id, kind: "merchandise-refund", cents: approved - actual, key: "merchandise-refund:\(order.id)")
                }
                notify(recipient: order.customerId, type: "purchase", orderId: order.id, title: "Purchase placed", body: "The runner recorded a simulated store purchase. This is not a receipt from the merchant.")
            }
        }

        if text(body["revision_decision"], max: 20) == "accept" {
            guard isCustomer, order.purchaseState == "revision", let actual = order.revisionMerchandiseCents else {
                throw APIError(message: "There isn't a new merchandise total waiting for you.", code: "bad_request")
            }
            let extra = actual - (order.merchandiseCents ?? 0)
            if extra > 0 {
                postLedger(orderId: order.id, kind: "merchandise-authorize", cents: extra, key: "merchandise-authorize-revision:\(order.id)")
                postLedger(orderId: order.id, kind: "merchandise-capture", cents: extra, key: "merchandise-capture-revision:\(order.id)")
            }
            order.merchandiseCents = actual
            order.actualMerchandiseCents = actual
            order.revisionMerchandiseCents = nil
            order.purchaseState = "placed"
            order.status = .restaurantConfirmed
            order.restaurantOrderConfirmedAt = Self.stamp()
            notify(recipient: order.driverId, type: "counteroffer", orderId: order.id, title: "New merchandise total approved", body: "The customer approved the higher store total.")
        }

        if text(body["revision_decision"], max: 20) == "decline" {
            guard isCustomer, order.purchaseState == "revision" else {
                throw APIError(message: "There isn't a new merchandise total waiting for you.", code: "bad_request")
            }
            order.purchaseState = nil
            order.revisionMerchandiseCents = nil
            notify(recipient: order.driverId, type: "counteroffer", orderId: order.id, title: "New merchandise total declined", body: "Keep the approved total, or cancel before buying.")
        }

        if let status = text(body["status"], max: 40), status != order.status.rawValue {
            guard let next = OrderStatus(rawValue: status) else {
                throw APIError(message: "That status isn't recognized.", code: "bad_request")
            }
            let stamp = Self.stamp()
            switch (order.status, next, isDriver, isCustomer) {
            case (.requested, .accepted, true, _):
                if let expiry = order.quoteExpiresAt, let when = Self.parse(expiry), when < DemoClock.now {
                    order.quoteState = "expired"
                    postLedger(orderId: order.id, kind: "release", cents: order.quoteCents ?? 0, key: "release:\(order.id)")
                    db.orders[index] = order
                    try save()
                    throw APIError(message: "This quote expired. Ask for a new one.", code: "bad_request")
                }
                guard order.quoteState == "quoted", order.deliveryFee != nil else {
                    throw APIError(message: "This request needs a reviewed price before it can be accepted.", code: "bad_request")
                }
                try enforceLimits(order)
                let load = db.orders.filter { $0.tripId == order.tripId && $0.id != order.id && Self.active.contains($0.status) }.count
                let cap = db.trips.first { $0.id == order.tripId }?.maxOrders ?? 0
                guard load < cap else { throw APIError(message: "This trip is already at its order limit.", code: "bad_request") }
                order.status = next
                order.acceptedAt = stamp
                if let cents = order.quoteCents {
                    postLedger(orderId: order.id, kind: "delivery-capture", cents: cents, key: "delivery-capture:\(order.id)")
                }
                if order.isRunnerPurchase, let goods = order.merchandiseCents, goods > 0 {
                    postLedger(orderId: order.id, kind: "merchandise-capture", cents: goods, key: "merchandise-capture:\(order.id)")
                }
                if order.usesCustomerHandoff && order.handoffSubmittedAt != nil {
                    order.status = .restaurantConfirmed
                    order.restaurantOrderConfirmedAt = stamp
                    notify(recipient: order.customerId, type: "accept", orderId: order.id, title: "Request accepted", body: "Your runner accepted. The confirmation you already added is saved. A runner was not guaranteed until now.")
                    notify(recipient: order.driverId, type: "handoff", orderId: order.id, title: "Review pickup details", body: "The customer submitted pickup confirmation.")
                } else if order.orderingModel == "customer_paid" {
                    notify(recipient: order.customerId, type: "accept", orderId: order.id, title: "Ready to place your order", body: "Order directly from the store, then add your pickup confirmation here.")
                } else if order.orderingModel == "personal" {
                    notify(recipient: order.customerId, type: "accept", orderId: order.id, title: "Request accepted", body: "Confirm the item and contact will be ready during the agreed window.")
                } else {
                    notify(recipient: order.customerId, type: "accept", orderId: order.id, title: "Request accepted", body: "Your runner accepted the pickup.")
                }
            case (.requested, .declined, true, _):
                guard let reason = text(body["decline_reason"], max: 160) else {
                    throw APIError(message: "Add a short reason for declining.", code: "bad_request")
                }
                order.status = next
                order.declinedAt = stamp
                order.declineReason = reason
                releaseBoth(order)
                notify(recipient: order.customerId, type: "decline", orderId: order.id, title: "Request declined", body: reason)
            case (.accepted, .restaurantConfirmed, true, _):
                if order.merchandiseCents != nil && order.purchaseState != "placed" {
                    throw APIError(message: "Record the store purchase before pickup. Accepting the request does not place the order.", code: "bad_request")
                }
                if order.pickupReadyAt == nil { order.pickupReadyAt = stamp }
                order.status = next
                order.restaurantOrderConfirmedAt = stamp
                if order.personalItem == true { order.purchaseState = "arranged" }
            case (.restaurantConfirmed, .pickedUp, true, _):
                if order.isRunnerPurchase && order.purchaseState != "placed" {
                    throw APIError(message: "Record the store purchase before marking it picked up.", code: "bad_request")
                }
                if order.usesCustomerHandoff {
                    guard order.handoffComplete, !order.detailsNeedReview else {
                        throw APIError(message: "Review the pickup details before collecting.", code: "bad_request")
                    }
                    guard order.pendingReadyAt == nil, order.placeChangePending != true else {
                        throw APIError(message: "Agree on the changed time or branch before pickup.", code: "bad_request")
                    }
                    guard flag(body["collection_confirmed"]) == true else {
                        throw APIError(message: "Confirm the reference and the described items match what you are collecting.", code: "bad_request")
                    }
                }
                order.status = next
                order.pickedUpAt = stamp
            case (.pickedUp, .onTheWay, true, _):
                order.status = next
                order.onTheWayAt = stamp
            case (.onTheWay, .arriving, true, _):
                order.status = next
                order.confirmationPin = Self.pin()
                order.pinAttempts = 0
                notify(recipient: order.customerId, type: "arrival", orderId: order.id, title: "Runner is arriving", body: "The confirmation code is on your order.")
            case (.arriving, .delivered, true, _):
                let entered = text(body["pin"], max: 8)
                guard entered == order.confirmationPin else {
                    order.pinAttempts = (order.pinAttempts ?? 0) + 1
                    db.orders[index] = order
                    try save()
                    if (order.pinAttempts ?? 0) >= 5 {
                        throw APIError(message: "Too many incorrect codes. Ask the customer to open the order again.", code: "bad_request")
                    }
                    throw APIError(message: "That code doesn't match.", code: "bad_request")
                }
                order.status = next
                order.deliveredAt = stamp
                order.confirmationPin = nil
                if let cents = order.runnerShareCents {
                    postLedger(orderId: order.id, kind: "earning", cents: cents, key: "earning:\(order.id)")
                }
                let delivery = order.quoteCents ?? 0
                let share = order.runnerShareCents ?? 0
                if delivery > share {
                    postLedger(orderId: order.id, kind: "platform-share", cents: delivery - share, key: "platform-share:\(order.id)")
                }
                if order.isRunnerPurchase, let goods = order.actualMerchandiseCents ?? order.merchandiseCents, goods > 0 {
                    postLedger(orderId: order.id, kind: "merchandise-reimburse", cents: goods, key: "merchandise-reimburse:\(order.id)")
                }
                notify(recipient: order.customerId, type: "delivery", orderId: order.id, title: "Delivered", body: "The pickup was marked delivered.")
            case (.requested, .cancelled, _, true), (.accepted, .cancelled, _, true), (.accepted, .cancelled, true, _):
                guard order.purchaseState != "placed" else {
                    throw APIError(message: "The purchase is already recorded. Open support. Home Run can't promise a merchant refund.", code: "bad_request")
                }
                let effect = DemoRules.cancellationEffect(status: order.status)
                order.status = next
                order.cancelledAt = stamp
                order.cancelledBy = user.id
                if effect == "release" {
                    releaseBoth(order)
                } else if effect == "refund" {
                    refundUnpurchased(order)
                }
                let other = user.id == order.customerId ? order.driverId : order.customerId
                notify(recipient: other, type: "cancellation", orderId: order.id, title: "Pickup cancelled", body: order.personalItem == true ? "The personal-item pickup was cancelled." : "The simulated merchandise and delivery amounts were updated.")
            case (.restaurantConfirmed, .cancelled, _, true), (.restaurantConfirmed, .cancelled, true, _):
                if order.isRunnerPurchase {
                    throw APIError(message: "The purchase is already recorded. Open support. Home Run can't promise a merchant refund.", code: "bad_request")
                }
                order.status = next
                order.cancelledAt = stamp
                order.cancelledBy = user.id
                refundUnpurchased(order)
                let other = user.id == order.customerId ? order.driverId : order.customerId
                let note = order.orderingModel == "personal"
                    ? "The personal-item pickup was cancelled before collection. The simulated delivery fee was refunded."
                    : "The simulated delivery fee was refunded. Money paid to the store is not refunded by Home Run."
                notify(recipient: other, type: "cancellation", orderId: order.id, title: "Pickup cancelled", body: note)
            case (.pickedUp, .cancelled, _, _), (.onTheWay, .cancelled, _, _), (.arriving, .cancelled, _, _):
                throw APIError(message: "After collection, open support. Home Run can't cancel this automatically.", code: "bad_request")
            default:
                throw APIError(message: "Invalid status change from \(order.status.rawValue) to \(status) for this account.", code: "forbidden")
            }
        }

        order.updatedAt = Self.stamp()
        db.orders[index] = order
        try save()
        return presented(order, viewer: user)
    }

    private func presented(_ trip: Trip) -> Trip {
        var copy = trip
        copy.stops = (trip.stops ?? []).sorted { $0.stopOrder < $1.stopOrder }
        copy.driver = db.users.first { $0.id == trip.driverId }.map(profile)
        copy.activeOrders = db.orders.filter { $0.tripId == trip.id && Self.active.contains($0.status) }.count
        return copy
    }

    private func presented(_ order: Order) -> Order {
        presented(order, viewer: nil)
    }

    private func presented(_ order: Order, viewer: StoredUser?) -> Order {
        var copy = order
        if let trip = db.trips.first(where: { $0.id == order.tripId }) { copy.trip = presented(trip) }
        copy.driver = db.users.first { $0.id == order.driverId }.map(profile)
        copy.customer = db.users.first { $0.id == order.customerId }.map(profile)
        if viewer?.id == order.driverId { copy.confirmationPin = nil }
        return copy
    }

    private func profile(_ user: StoredUser) -> Profile {
        Profile(id: user.id, displayName: user.displayName, avatarUrl: user.avatarUrl, paymentHandle: user.paymentHandle, createdAt: user.createdAt, intent: user.intent, notify: user.notify)
    }

    private func togglePlace(user: StoredUser, body: [String: Any]) throws -> SavedPlaceList {
        let placeId = try required(body["place_id"], max: 200, message: "Choose a place.")
        var rows = db.savedPlaces ?? []
        if let index = rows.firstIndex(where: { $0.userId == user.id && $0.placeId == placeId }) {
            rows.remove(at: index)
        } else {
            rows.append(SavedPlace(
                id: UUID().uuidString,
                userId: user.id,
                placeId: placeId,
                name: try required(body["name"], max: 120, message: "Choose a place."),
                address: text(body["address"], max: 200) ?? "",
                lat: try coordinate(body["lat"], "Place location is missing."),
                lng: try coordinate(body["lng"], "Place location is missing."),
                city: text(body["city"], max: 80) ?? "",
                photoName: text(body["photo_name"], max: 240),
                photoCredit: text(body["photo_credit"], max: 120),
                contentSource: text(body["content_source"], max: 20),
                createdAt: Self.stamp()
            ))
        }
        db.savedPlaces = rows
        try save()
        return SavedPlaceList(places: rows.filter { $0.userId == user.id })
    }

    private func deleteDemoAccount(user: StoredUser) throws {
        guard user.id.hasPrefix("demo-") else {
            throw APIError(message: "This demo action only removes a fictional demo profile.", code: "forbidden")
        }
        let open = db.orders.contains { order in
            (order.customerId == user.id || order.driverId == user.id) && !order.status.isTerminal && order.status != .declined
        }
        guard !open else {
            throw APIError(message: "Finish or cancel active pickups before removing this demo profile.", code: "bad_request")
        }
        guard let index = db.users.firstIndex(where: { $0.id == user.id }) else { return }
        db.users[index].displayName = "Removed demo"
        db.users[index].paymentHandle = nil
        try save()
    }

    private func storeHandoff(_ order: inout Order, body: [String: Any], trip: Trip?, creating: Bool) throws {
        if let details = text(body["request_text"], max: 800) {
            order.itemSummary = details
        }
        guard !(order.itemSummary ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError(message: "Add pickup details.", code: "bad_request")
        }
        if order.orderingModel == "personal" {
            guard flag(body["ready_confirmed"]) == true else {
                throw APIError(message: "Confirm the item and contact will be ready during the window.", code: "bad_request")
            }
            if let contact = text(body["contact_label"], max: 80) { order.contactLabel = contact }
            if let access = text(body["access_instructions"], max: 500) { order.accessInstructions = access }
            guard order.contactLabel != nil else {
                throw APIError(message: "Add who will meet the runner.", code: "bad_request")
            }
        } else {
            guard let name = text(body["pickup_name"], max: 80) else {
                throw APIError(message: "Add the name on the order.", code: "bad_request")
            }
            let missing = flag(body["reference_missing"]) == true
            let number = text(body["restaurant_order_number"], max: 60)
            guard missing || number != nil else {
                throw APIError(message: "Add the order number, or say the merchant did not provide one.", code: "bad_request")
            }
            order.pickupName = name
            order.referenceMissing = missing
            order.restaurantOrderNumber = missing ? nil : number
            order.pickupCode = text(body["pickup_code"], max: 40)
        }
        let window = text(body["pickup_window"], max: 120)
        let ready = text(body["pickup_ready_at"], max: 40)
        guard window != nil || ready != nil || order.pickupWindowLabel != nil || order.pickupReadyAt != nil else {
            throw APIError(message: "Add the pickup time.", code: "bad_request")
        }
        if let ready {
            guard let when = Self.parse(ready) else {
                throw APIError(message: "That pickup time could not be read.", code: "bad_request")
            }
            if let departure = trip.flatMap({ Self.parse($0.departureAt) }), when > departure {
                throw APIError(message: "That pickup time is after this trip leaves.", code: "bad_request")
            }
            if !creating, order.status != .requested, let existing = order.pickupReadyAt, let old = Self.parse(existing), abs(old.timeIntervalSince(when)) > 15 * 60 {
                order.pendingReadyAt = ready
                order.pendingWindowLabel = window ?? order.pickupWindowLabel
                notify(recipient: order.driverId, type: "window-\(Self.stamp())", orderId: order.id, title: "Pickup time changed", body: "Agree to the new pickup time before collecting. The delivery fee stays the same until you do.", again: true)
            } else {
                order.pickupReadyAt = ready
            }
        }
        if let window, order.pendingReadyAt == nil { order.pickupWindowLabel = window }
        if let instructions = text(body["pickup_instructions"], max: 500) { order.pickupInstructions = instructions }
        if let access = text(body["access_instructions"], max: 500) { order.accessInstructions = access }
        if let branch = text(body["branch_note"], max: 160), !creating, order.status != .requested {
            order.pendingRestaurantName = branch
            order.placeChangePending = true
            notify(recipient: order.driverId, type: "branch-\(Self.stamp())", orderId: order.id, title: "Branch change requested", body: "The customer asked for a different branch. The accepted delivery fee stays until you agree.", again: true)
        }
        if flag(body["remove_screenshot"]) == true {
            order.screenshotName = nil
        } else if let encoded = text(body["screenshot_base64"], max: 12_000_000) {
            order.screenshotName = try storeScreenshot(encoded, orderId: order.id)
        }
        let reviewed = order.detailsReviewedAt != nil && order.pendingReadyAt == nil
        order.handoffSubmittedAt = Self.stamp()
        if !creating, order.status == .accepted || order.status == .restaurantConfirmed {
            if order.pendingReadyAt == nil {
                order.status = .restaurantConfirmed
                order.restaurantOrderConfirmedAt = order.restaurantOrderConfirmedAt ?? Self.stamp()
            }
            if reviewed {
                order.detailsReviewedAt = nil
                order.detailsChangedAt = Self.stamp()
                notify(recipient: order.driverId, type: "handoff-changed-\(Self.stamp())", orderId: order.id, title: "Pickup details changed", body: "Review the updated confirmation before collecting.", again: true)
            } else if order.pendingReadyAt == nil {
                notify(recipient: order.driverId, type: "handoff", orderId: order.id, title: "Review pickup details", body: "The customer submitted pickup confirmation.")
            }
        }
    }

    private func remindMissingHandoff(for user: StoredUser) -> Bool {
        let before = db.notices?.count ?? 0
        for order in db.orders where order.customerId == user.id && order.usesCustomerHandoff && order.status == .accepted && !order.handoffComplete {
            guard let trip = db.trips.first(where: { $0.id == order.tripId }), let departure = Self.parse(trip.departureAt) else { continue }
            guard departure.timeIntervalSince(DemoClock.now) < 3 * 3600 else { continue }
            notify(recipient: user.id, type: "handoff-reminder", orderId: order.id, title: "Pickup details still needed", body: "Add the confirmation before this trip leaves, or cancel the delivery. This order is not ready for pickup.")
        }
        return (db.notices?.count ?? 0) != before
    }

    private func releaseBoth(_ order: Order) {
        postLedger(orderId: order.id, kind: "delivery-release", cents: order.quoteCents ?? 0, key: "delivery-release:\(order.id)")
        if let goods = order.merchandiseCents, goods > 0 {
            postLedger(orderId: order.id, kind: "merchandise-release", cents: goods, key: "merchandise-release:\(order.id)")
        }
    }

    private func refundUnpurchased(_ order: Order) {
        postLedger(orderId: order.id, kind: "delivery-refund", cents: order.quoteCents ?? 0, key: "delivery-refund:\(order.id)")
        if let goods = order.merchandiseCents, goods > 0 {
            postLedger(orderId: order.id, kind: "merchandise-refund", cents: goods, key: "merchandise-refund:\(order.id)")
        }
    }

    private func storeScreenshot(_ encoded: String, orderId: String) throws -> String {
        guard let data = Data(base64Encoded: encoded), !data.isEmpty else {
            throw APIError(message: "That screenshot could not be read.", code: "bad_request")
        }
        let jpeg = try normalizeJPEG(data)
        let name = "\(orderId).jpg"
        let folder = try attachmentsFolder()
        try jpeg.write(to: folder.appendingPathComponent(name), options: .atomic)
        return name
    }

    private func normalizeJPEG(_ data: Data) throws -> Data {
        guard data.count <= 8_000_000 else {
            throw APIError(message: "Use a screenshot under 8 MB.", code: "bad_request")
        }
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw APIError(message: "Use a photo of the basket or item list.", code: "bad_request")
        }
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let rendered = UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.72) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard rendered.count <= 1_500_000 else {
            throw APIError(message: "That screenshot is still too large after resizing.", code: "bad_request")
        }
        return rendered
    }

    private func attachmentsFolder() throws -> URL {
        let folder = storageURL.deletingLastPathComponent().appendingPathComponent("attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func attachment(for user: StoredUser, orderId: String) throws -> AttachmentPayload {
        guard let order = db.orders.first(where: { $0.id == orderId && ($0.customerId == user.id || $0.driverId == user.id || user.id == "demo-taylor") }) else {
            throw APIError(message: "That screenshot isn't available.", code: "not_found")
        }
        guard let name = order.screenshotName else { return AttachmentPayload(jpegBase64: nil) }
        let url = storageURL.deletingLastPathComponent().appendingPathComponent("attachments").appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return AttachmentPayload(jpegBase64: nil) }
        return AttachmentPayload(jpegBase64: data.base64EncodedString())
    }

    private func draftURL(userId: String) -> URL {
        storageURL.deletingLastPathComponent().appendingPathComponent("draft-\(userId).json")
    }

    private func loadDraft(userId: String) -> ComposerDraft {
        let empty = ComposerDraft(tripId: "", placeId: "", requestText: "", merchandise: "", substitution: "ask", instructions: "", personal: false, bulky: false, hasScreenshot: false)
        guard let data = try? Data(contentsOf: draftURL(userId: userId)), var draft = try? JSONDecoder().decode(ComposerDraft.self, from: data) else {
            return empty
        }
        let imageURL = storageURL.deletingLastPathComponent().appendingPathComponent("attachments/draft-\(userId).jpg")
        if let bytes = try? Data(contentsOf: imageURL), !bytes.isEmpty {
            draft.hasScreenshot = true
            draft.screenshotBase64 = bytes.base64EncodedString()
        }
        return draft
    }

    private func saveDraft(user: StoredUser, body: [String: Any]) throws {
        var draft = ComposerDraft(
            tripId: text(body["trip_id"], max: 80) ?? "",
            placeId: text(body["place_id"], max: 200) ?? "",
            requestText: text(body["request_text"], max: 500) ?? "",
            merchandise: text(body["merchandise"], max: 20) ?? "",
            substitution: text(body["substitution"], max: 20) ?? "ask",
            instructions: text(body["instructions"], max: 500) ?? "",
            personal: flag(body["personal"]) == true,
            bulky: flag(body["bulky"]) == true,
            hasScreenshot: false
        )
        let imageURL = storageURL.deletingLastPathComponent().appendingPathComponent("attachments/draft-\(user.id).jpg")
        if flag(body["remove_screenshot"]) == true {
            try? FileManager.default.removeItem(at: imageURL)
        } else if let encoded = text(body["screenshot_base64"], max: 12_000_000) {
            draft.hasScreenshot = true
            _ = try storeScreenshot(encoded, orderId: "draft-\(user.id)")
        } else if FileManager.default.fileExists(atPath: imageURL.path) {
            draft.hasScreenshot = true
        }
        let data = try JSONEncoder().encode(draft)
        try data.write(to: draftURL(userId: user.id), options: .atomic)
    }

    private func removeDraft(userId: String) {
        try? FileManager.default.removeItem(at: draftURL(userId: userId))
        try? FileManager.default.removeItem(at: storageURL.deletingLastPathComponent().appendingPathComponent("attachments/draft-\(userId).jpg"))
    }

    private func postLedger(orderId: String, kind: String, cents: Int, key: String) {
        var entries = db.ledger ?? []
        guard !entries.contains(where: { $0.operationKey == key }) else { return }
        entries.append(LedgerEntry(id: UUID().uuidString, operationKey: key, orderId: orderId, kind: kind, cents: cents, createdAt: Self.stamp()))
        db.ledger = entries
    }

    private func notify(recipient: String, type: String, orderId: String?, title: String, body: String, again: Bool = false) {
        if db.users.first(where: { $0.id == recipient })?.notify == false { return }
        let key = again ? "\(type)|\(recipient)|\(orderId ?? title)|\(Self.stamp())" : "\(type)|\(recipient)|\(orderId ?? title)"
        var notices = db.notices ?? []
        guard !notices.contains(where: { $0.dedupeKey == key }) else { return }
        notices.append(AppNotice(id: UUID().uuidString, recipientId: recipient, type: type, orderId: orderId, tripId: nil, title: title, body: body, createdAt: Self.stamp(), readAt: nil, dedupeKey: key))
        db.notices = notices
    }

    private func enforceLimits(_ order: Order) throws {
        guard let trip = db.trips.first(where: { $0.id == order.tripId }) else { return }
        if let pounds = order.weightPounds, let itemCap = trip.maxItemPounds, pounds > itemCap {
            throw APIError(message: "That weight is over this trip's item limit.", code: "bad_request")
        }
        if let pounds = order.weightPounds, let totalCap = trip.maxTotalPounds {
            let reserved = db.orders.filter { $0.tripId == trip.id && $0.id != order.id && Self.active.contains($0.status) }.compactMap(\.weightPounds).reduce(0, +)
            if reserved + pounds > totalCap {
                throw APIError(message: "That weight is over this trip's total limit.", code: "bad_request")
            }
        }
    }

    private func markNotices(user: StoredUser, body: [String: Any]) throws {
        var notices = db.notices ?? []
        let all = (body["all"] as? Bool) ?? (body["all"] as? NSNumber)?.boolValue ?? false
        let stamp = Self.stamp()
        if all {
            for index in notices.indices where notices[index].recipientId == user.id && notices[index].readAt == nil {
                notices[index].readAt = stamp
            }
        } else if let id = text(body["id"], max: 80), let index = notices.firstIndex(where: { $0.id == id && $0.recipientId == user.id }) {
            notices[index].readAt = stamp
        }
        db.notices = notices
        try save()
    }

    private func saveRequest(user: StoredUser, body: [String: Any]) throws -> SavedRequest {
        let city = try required(body["city"], max: 80, message: "Choose a pickup city.")
        let request = SavedRequest(id: UUID().uuidString, customerId: user.id, city: city, placeName: text(body["place_name"], max: 120), maxFeeCents: body["max_fee_cents"] == nil ? nil : Int(Self.number(body["max_fee_cents"]) ?? 0), status: "open", matchedTripId: nil, createdAt: Self.stamp())
        var rows = db.savedRequests ?? []
        rows.append(request)
        db.savedRequests = rows
        try save()
        return request
    }

    private func updateSavedRequest(user: StoredUser, body: [String: Any]) throws -> SavedRequest {
        guard let id = text(body["id"], max: 80), let index = (db.savedRequests ?? []).firstIndex(where: { $0.id == id && $0.customerId == user.id }) else {
            throw APIError(message: "That saved request isn't available.", code: "not_found")
        }
        let status = text(body["status"], max: 20) ?? "open"
        guard ["open", "paused", "deleted"].contains(status) else {
            throw APIError(message: "That saved-request update isn't allowed.", code: "bad_request")
        }
        db.savedRequests?[index].status = status
        if status == "open" { db.savedRequests?[index].matchedTripId = nil }
        let saved = db.savedRequests![index]
        try save()
        return saved
    }

    private func matchSavedRequests(to trip: Trip) {
        guard trip.status == "scheduled" else { return }
        var rows = db.savedRequests ?? []
        for index in rows.indices where rows[index].status == "open" && rows[index].city == trip.originCity && rows[index].matchedTripId == nil {
            rows[index].status = "matched"
            rows[index].matchedTripId = trip.id
            notify(recipient: rows[index].customerId, type: "saved-match", orderId: nil, title: "A trip matches your request", body: "\(trip.originCity) → College Station is posted. This is not a booking.")
            if var notices = db.notices, let noteIndex = notices.indices.last {
                notices[noteIndex].tripId = trip.id
                db.notices = notices
            }
            db.savedRequests = rows
            return
        }
    }

    private func supportCases(for user: StoredUser) -> [SupportCase] {
        let rows = db.supportCases ?? []
        if user.id == "demo-taylor" { return rows }
        return rows.filter { $0.actorId == user.id }
    }

    private func openCase(user: StoredUser, body: [String: Any]) throws -> SupportCase {
        let category = try required(body["category"], max: 40, message: "Choose what happened.")
        let details = try required(body["details"], max: 500, message: "Describe what happened.")
        let item = SupportCase(id: UUID().uuidString, actorId: user.id, orderId: text(body["order_id"], max: 80), category: category, details: details, status: "open", resolution: nil, createdAt: Self.stamp())
        var rows = db.supportCases ?? []
        rows.append(item)
        db.supportCases = rows
        try save()
        return item
    }

    private func updateCase(user: StoredUser, body: [String: Any]) throws -> SupportCase {
        guard user.id == "demo-taylor" else { throw APIError(message: "Support tools stay in the demo support account.", code: "forbidden") }
        guard let id = text(body["id"], max: 80), let index = (db.supportCases ?? []).firstIndex(where: { $0.id == id }) else {
            throw APIError(message: "Case not found.", code: "not_found")
        }
        let status = text(body["status"], max: 20) ?? "open"
        guard ["open", "in_review", "resolved", "closed"].contains(status) else {
            throw APIError(message: "That case update isn't allowed.", code: "bad_request")
        }
        db.supportCases?[index].status = status
        db.supportCases?[index].resolution = text(body["resolution"], max: 500)
        try save()
        return db.supportCases![index]
    }

    private func supportRefund(user: StoredUser, orderId: String) throws {
        guard user.id == "demo-taylor" else { throw APIError(message: "Only the demo support account can refund a delivered order.", code: "forbidden") }
        guard let index = db.orders.firstIndex(where: { $0.id == orderId }), db.orders[index].status == .delivered else {
            throw APIError(message: "A delivered order is required.", code: "bad_request")
        }
        let captured = db.orders[index].quoteCents ?? 0
        let refunded = (db.ledger ?? []).filter { $0.orderId == orderId && $0.kind == "refund" }.reduce(0) { $0 + $1.cents }
        guard DemoRules.refundAllowed(captured: captured, alreadyRefunded: refunded, amount: captured) else {
            throw APIError(message: "That refund is larger than the captured fee.", code: "bad_request")
        }
        postLedger(orderId: orderId, kind: "refund", cents: captured, key: "support-refund:\(orderId)")
        postLedger(orderId: orderId, kind: "earning-reversal", cents: db.orders[index].runnerShareCents ?? 0, key: "support-reversal:\(orderId)")
        notify(recipient: db.orders[index].customerId, type: "refund", orderId: orderId, title: "Simulated refund", body: "Support refunded the delivery fee. The delivery record stays delivered.")
        try save()
    }

    private func ledger(for user: StoredUser, orderId: String?) -> [LedgerEntry] {
        let mine = Set(db.orders.filter { $0.customerId == user.id || $0.driverId == user.id || user.id == "demo-taylor" }.map(\.id))
        return (db.ledger ?? []).filter { mine.contains($0.orderId) && (orderId == nil || $0.orderId == orderId) }
    }

    private func resetDemo(user: StoredUser) throws {
        guard user.id.hasPrefix("demo-") else {
            throw APIError(message: "Reset only replaces fictional demo records.", code: "forbidden")
        }
        db.orders.removeAll { $0.customerId.hasPrefix("demo-") || $0.driverId.hasPrefix("demo-") }
        db.trips.removeAll { $0.driverId.hasPrefix("demo-") }
        let remaining = Set(db.orders.map(\.id))
        db.messages = (db.messages ?? []).filter { remaining.contains($0.orderId) }
        db.ledger = (db.ledger ?? []).filter { remaining.contains($0.orderId) }
        db.notices = (db.notices ?? []).filter { !$0.recipientId.hasPrefix("demo-") }
        db.savedRequests = (db.savedRequests ?? []).filter { !$0.customerId.hasPrefix("demo-") }
        db.savedPlaces = (db.savedPlaces ?? []).filter { !$0.userId.hasPrefix("demo-") }
        db.supportCases = (db.supportCases ?? []).filter { !$0.actorId.hasPrefix("demo-") }
        try save()
        seedDemoIfNeeded()
        _ = seedHistoryIfNeeded()
    }

    @discardableResult
    private func seedHistoryIfNeeded() -> Bool {
        var changed = false
        if !db.trips.contains(where: { $0.id == "demo-trip-jordan-done" }) {
            let past = DemoClock.now.addingTimeInterval(-2 * 86_400)
            let houston = Places.city(named: "Houston")!
            db.trips.append(Trip(
                id: "demo-trip-jordan-done", driverId: "demo-jordan", originCity: "Houston", originLat: houston.lat, originLng: houston.lng,
                destinationCity: Places.destination.name, destinationLat: Places.destination.lat, destinationLng: Places.destination.lng,
                departureAt: Self.plain.string(from: past), maxOrders: 4, notes: "Completed demo history.", status: "completed",
                createdAt: Self.stamp(), driver: nil, stops: nil, activeOrders: nil
            ))
            var delivered = Self.historyOrder(id: "demo-order-delivered", trip: "demo-trip-jordan-done", status: .delivered, fee: 8, share: 640)
            delivered.orderingModel = "runner_purchase"
            delivered.merchandiseCents = 2_400
            delivered.actualMerchandiseCents = 2_400
            delivered.purchaseState = "placed"
            delivered.substitution = "ask"
            delivered.itemSummary = "Rice bowl. Sample basket — not a real order."
            delivered.screenshotName = "demo-order-delivered.jpg"
            db.orders.append(delivered)
            if let folder = try? attachmentsFolder(), let jpeg = try? sampleBasketJPEG() {
                try? jpeg.write(to: folder.appendingPathComponent("demo-order-delivered.jpg"), options: .atomic)
            }
            var entries = db.ledger ?? []
            entries.append(contentsOf: [
                LedgerEntry(id: "demo-ledger-auth", operationKey: "authorize:demo-order-delivered", orderId: "demo-order-delivered", kind: "authorize", cents: 800, createdAt: Self.stamp()),
                LedgerEntry(id: "demo-ledger-capture", operationKey: "capture:demo-order-delivered", orderId: "demo-order-delivered", kind: "capture", cents: 800, createdAt: Self.stamp()),
                LedgerEntry(id: "demo-ledger-earn", operationKey: "earning:demo-order-delivered", orderId: "demo-order-delivered", kind: "earning", cents: 640, createdAt: Self.stamp()),
                LedgerEntry(id: "demo-ledger-goods", operationKey: "merchandise-reimburse:demo-order-delivered", orderId: "demo-order-delivered", kind: "merchandise-reimburse", cents: 2_400, createdAt: Self.stamp()),
                LedgerEntry(id: "demo-ledger-platform", operationKey: "platform-share:demo-order-delivered", orderId: "demo-order-delivered", kind: "platform-share", cents: 160, createdAt: Self.stamp()),
            ])
            db.ledger = entries
            var messages = db.messages ?? []
            messages.append(OrderMessage(id: "demo-message-1", orderId: "demo-order-delivered", senderId: "demo-maya", body: "Sample basket for the rice bowl. This is not a real customer screenshot.", createdAt: Self.stamp()))
            messages.append(OrderMessage(id: "demo-message-2", orderId: "demo-order-delivered", senderId: "demo-jordan", body: "Got it. I’ll message when I leave the stop.", createdAt: Self.stamp()))
            db.messages = messages
            changed = true
        }
        if !db.trips.contains(where: { $0.id == "demo-trip-jordan-cancelled" }) {
            let past = DemoClock.now.addingTimeInterval(-3 * 86_400)
            let houston = Places.city(named: "Houston")!
            db.trips.append(Trip(
                id: "demo-trip-jordan-cancelled", driverId: "demo-jordan", originCity: "Houston", originLat: houston.lat, originLng: houston.lng,
                destinationCity: Places.destination.name, destinationLat: Places.destination.lat, destinationLng: Places.destination.lng,
                departureAt: Self.plain.string(from: past), maxOrders: 4, notes: "Cancelled before pickup.", status: "cancelled",
                createdAt: Self.stamp(), driver: nil, stops: nil, activeOrders: nil
            ))
            var cancelled = Self.historyOrder(id: "demo-order-cancelled", trip: "demo-trip-jordan-cancelled", status: .cancelled, fee: 8, share: 640)
            cancelled.cancelledBy = "demo-jordan"
            cancelled.cancelledAt = Self.stamp()
            db.orders.append(cancelled)
            var entries = db.ledger ?? []
            entries.append(LedgerEntry(id: "demo-ledger-release", operationKey: "release:demo-order-cancelled", orderId: "demo-order-cancelled", kind: "release", cents: 800, createdAt: Self.stamp()))
            db.ledger = entries
            changed = true
        }
        return changed
    }

    private func prepareScenario(user: StoredUser, number: Int) throws -> ScenarioPrep {
        guard (1...10).contains(number) else {
            throw APIError(message: "Choose a scenario from 1 to 10.", code: "bad_request")
        }
        try resetDemo(user: user)
        let fixture: String
        let samples: Bool
        let city: String
        let clearTerms: Bool
        let title: String
        let instructions: String
        switch number {
        case 1:
            fixture = "standard"; samples = false; city = "Houston"; clearTerms = false
            title = "From Houston, with dinner"
            pointBayou("demo-trip-jordan")
            instructions = "Stay as Anish Koduri. Discover is Houston. Choose Bayou Bowl Kitchen, Restaurant or store, and Campus Library Plaza. In Pickup details, describe the bags. Wait for Jordan to accept before ordering. The labeled route is within 1 mile and 5 minutes, so the delivery fee is $8. Submit. Profile → Demo people → Jordan Ellis and accept. Switch back to Anish. Order and pay the store yourself, then add the name, reference, and pickup time. Jordan taps Review pickup details, then Details received, confirms the bags match, and continues through the code. Earnings shows $6.40. Nothing is charged."
        case 2:
            fixture = "detour"; samples = false; city = "Dallas"; clearTerms = false
            title = "Worth the detour"
            instructions = "Stay as Anish Koduri. The pickup city is Dallas and Avery Patel's trip is open. Choose a Dallas place and describe the order in Pickup details. The labeled fixture is 6 extra miles and 12 extra minutes: delivery fee $15.50, runner earning $12.40. That earning is only the delivery fee. Submit, switch to Avery, accept, then as Anish add the store confirmation. Avery reviews it and completes the delivery with the code."
        case 3:
            fixture = "standard"; samples = false; city = "Austin"; clearTerms = false
            title = "A little heavier"
            instructions = "Stay as Anish Koduri. Austin uses Sam Rivera's trip. For a restaurant order, turn on About 35 lb. The delivery fee becomes $15 and the runner earning is $12. Or choose Home or personal item and leave the weight blank: the price stays in review rather than $0. Sam can counteroffer $18 on the delivery fee. Approve it as Anish. The simulated earning becomes $14.40. A heavier offer still cannot pass Sam's limits."
        case 4:
            fixture = "standard"; samples = false; city = "Houston"; clearTerms = false
            title = "One stop, two orders"
            pointBayou("demo-trip-jordan")
            if let index = db.trips.firstIndex(where: { $0.id == "demo-trip-jordan" }) { db.trips[index].maxOrders = 4 }
            instructions = "Anish Koduri requests Bayou Bowl Kitchen and describes the bags. Profile → Demo people → Alex Morgan and request the same place and meetup. The orders stay separate, each with its own confirmation and code. The $2 shared-stop discount is defined and off. Jordan accepts both. Each customer then pays the store and adds pickup confirmation."
        case 5:
            fixture = ""; samples = false; city = "San Antonio"; clearTerms = false
            title = "Catch the next trip"
            instructions = "Stay as Anish Koduri. San Antonio has no published trip. Profile → Saved requests, save one for San Antonio, then Demo controls → Publish a matching trip. One notice appears. Nothing is booked or charged. Open the trip from the notice."
        case 6:
            fixture = "standard"; samples = false; city = "Houston"; clearTerms = false
            title = "Plans change"
            stageOrder(id: "demo-order-plans", tripId: "demo-trip-jordan", customerId: "demo-maya", placeId: "sample:bayou-bowl", name: "Bayou Bowl Kitchen", lat: 29.743, lng: -95.369, status: .accepted)
            instructions = "Profile → Demo people → Jordan Ellis. My trips → the Houston trip → Cancel trip. The order is accepted and the customer has not added store confirmation, so the simulated delivery fee is refunded. Money paid to a store is not refunded by Home Run. Both people get a notice. The pickup is not reassigned."
        case 7:
            fixture = "standard"; samples = false; city = "Houston"; clearTerms = false
            title = "The last spot"
            if let index = db.trips.firstIndex(where: { $0.id == "demo-trip-jordan" }) { db.trips[index].maxOrders = 1 }
            stageOrder(id: "demo-order-race-maya", tripId: "demo-trip-jordan", customerId: "demo-maya", placeId: "sample:bayou-bowl", name: "Bayou Bowl Kitchen", lat: 29.743, lng: -95.369, status: .requested)
            stageOrder(id: "demo-order-race-alex", tripId: "demo-trip-jordan", customerId: "demo-alex", placeId: "sample:bayou-coffee", name: "Bayou Coffee Counter", lat: 29.752, lng: -95.358, status: .requested)
            instructions = "Profile → Demo people → Jordan Ellis. Requests lists Anish Koduri and Alex Morgan, each with pickup details. Accept one. Accepting the other fails because the only spot is taken, and that delivery fee is not captured."
        case 8:
            fixture = ""; samples = false; city = "Houston"; clearTerms = false
            title = "Make it right"
            instructions = "Anish Koduri → Orders → the delivered Bayou Bowl history. That older record is marked runner purchase and keeps its separate merchandise reimbursement. Get help and submit a case. Profile → Demo people → Taylor Brooks. Support → In review, then Resolve. Resolve does not refund. Simulate full refund returns the delivery fee only, and the order stays delivered. New requests do not create a merchandise charge."
        case 9:
            fixture = ""; samples = false; city = "Houston"; clearTerms = true
            title = "Welcome, Aggie"
            instructions = "The demo terms are unchecked again. Version demo-1. Open the terms, leave the toggle off, and see Continue stay disabled. Accept, then use Bring food and Order food. Force quit and reopen: the same demo person returns. Sign out to read Forgot password: no email is sent."
        case 10:
            fixture = "review"; samples = true; city = "Houston"; clearTerms = false
            title = "Offline, still presentable"
            instructions = "Discover uses the labeled sample catalog even if a Places key is set. A request stays in price review instead of inventing a delivery fee. Nothing is captured while the quote needs review. Use Reset demo records to restore the baseline trips. Account 1 is left alone."
        default:
            throw APIError(message: "Choose a scenario from 1 to 10.", code: "bad_request")
        }
        DemoRouteFixture.set(fixture)
        DemoRouteFixture.setSamples(samples)
        if clearTerms {
            for id in ["demo-maya", "demo-jordan", "demo-avery", "demo-sam", "demo-alex", "demo-taylor"] {
                UserDefaults.standard.removeObject(forKey: "homerun.terms.\(id)")
            }
        }
        try save()
        return ScenarioPrep(scenario: number, title: title, instructions: instructions, city: city, fixture: fixture, forceSamples: samples, clearTerms: clearTerms)
    }

    private func pointBayou(_ tripId: String) {
        guard let index = db.trips.firstIndex(where: { $0.id == tripId }) else { return }
        db.trips[index].stops = [TripStop(id: "\(tripId)-bayou", tripId: tripId, placeId: "sample:bayou-bowl", restaurantName: "Bayou Bowl Kitchen", address: "Sample address, Houston, TX", lat: 29.743, lng: -95.369, stopOrder: 0, kind: "pickup", available: true, arrivesAt: "Before departure")]
    }

    private func stageOrder(id: String, tripId: String, customerId: String, placeId: String, name: String, lat: Double, lng: Double, status: OrderStatus) {
        guard let trip = db.trips.first(where: { $0.id == tripId }) else { return }
        guard !db.orders.contains(where: { $0.id == id }) else { return }
        let stamp = Self.stamp()
        let order = Order(
            id: id, tripId: tripId, customerId: customerId, driverId: trip.driverId,
            restaurantPlaceId: placeId, restaurantName: name, restaurantAddress: "Sample address",
            restaurantLat: lat, restaurantLng: lng, restaurantWebsite: nil, placeSource: "sample",
            destinationType: "campus", destinationLabel: "Campus Library Plaza — demo location",
            destinationLat: 30.618, destinationLng: -96.338, detourMinutes: 0, deliveryFee: 8, estimateSource: "fixture",
            estimatedArrivalAt: nil, customerNote: nil, itemSummary: "1× Rice bowl", quoteCents: 800, runnerShareCents: 640,
            quoteState: "quoted", confirmationPin: nil, pinAttempts: 0, pickupName: "HR-SCENARIO", restaurantOrderNumber: nil,
            pickupReadyAt: nil, pickupInstructions: nil, status: status, cancelledBy: nil,
            acceptedAt: status == .accepted ? stamp : nil, restaurantOrderConfirmedAt: nil, pickedUpAt: nil, onTheWayAt: nil,
            deliveredAt: nil, declinedAt: nil, cancelledAt: nil, createdAt: stamp, updatedAt: stamp,
            trip: nil, driver: nil, customer: nil
        )
        var stored = order
        stored.orderingModel = "customer_paid"
        stored.itemSummary = "Two takeout bags: one rice bowl and one sandwich. Keep the drink upright."
        stored.merchandiseCents = nil
        stored.pickupName = nil
        db.orders.append(stored)
        postLedger(orderId: id, kind: "delivery-authorize", cents: 800, key: "delivery-authorize:\(id)")
        if status == .accepted {
            postLedger(orderId: id, kind: "delivery-capture", cents: 800, key: "delivery-capture:\(id)")
        }
    }

    private func sampleBasketJPEG() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360))
        let jpeg = renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            let copy = "Sample basket\nNot a real customer order\nRice bowl    $24.00" as NSString
            copy.draw(in: CGRect(x: 28, y: 36, width: 580, height: 280), withAttributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: UIColor(red: 0.31, green: 0.08, blue: 0.13, alpha: 1),
            ])
        }
        return jpeg
    }

    private func publishMatchingTrip(city: String) throws {
        guard let origin = Places.city(named: city) else {
            throw APIError(message: "That city isn't in the demo list.", code: "bad_request")
        }
        let identifier = "demo-trip-match-\(origin.name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        guard !db.trips.contains(where: { $0.id == identifier }) else { return }
        guard !db.trips.contains(where: { $0.originCity == origin.name && $0.status == "scheduled" && (Self.parse($0.departureAt) ?? .distantPast) >= DemoClock.now }) else {
            return
        }
        let when = DemoClock.now.addingTimeInterval(26 * 3_600)
        let trip = Trip(
            id: identifier,
            driverId: "demo-jordan",
            originCity: origin.name,
            originLat: origin.lat,
            originLng: origin.lng,
            destinationCity: Places.destination.name,
            destinationLat: Places.destination.lat,
            destinationLng: Places.destination.lng,
            departureAt: Self.plain.string(from: when),
            maxOrders: 2,
            notes: "Published from demo controls. Not a booking.",
            status: "scheduled",
            maxItemPounds: 50,
            maxTotalPounds: 50,
            maxDetourMinutes: 30,
            maxDetourMiles: 15,
            createdAt: Self.stamp(),
            driver: nil,
            stops: nil,
            activeOrders: 0
        )
        db.trips.append(trip)
        matchSavedRequests(to: trip)
        try save()
    }

    private func simulatePayout(user: StoredUser) throws {
        let earned = (db.ledger ?? []).filter { entry in
            entry.kind == "earning" && db.orders.contains { $0.id == entry.orderId && $0.driverId == user.id }
        }
        for entry in earned where !(db.ledger ?? []).contains(where: { $0.operationKey == "payout:\(entry.orderId)" }) {
            postLedger(orderId: entry.orderId, kind: "payout", cents: entry.cents, key: "payout:\(entry.orderId)")
        }
        try save()
    }

    private struct Priced {
        var fee: Double?
        var total: Int?
        var share: Int?
        var state: String
    }

    private func orderLines(_ value: Any?) -> [OrderLine] {
        let rows = (value as? [[String: Any]] ?? []).prefix(12)
        return rows.compactMap { row in
            guard let name = text(row["name"], max: 80), !name.isEmpty else { return nil }
            let quantity = min(12, max(1, Int(Self.number(row["quantity"]) ?? 1)))
            let weight = Self.number(row["weight_pounds"])
            let confirmed = (row["weight_confirmed"] as? Bool) ?? (row["weight_confirmed"] as? NSNumber)?.boolValue ?? (weight != nil)
            return OrderLine(
                id: text(row["id"], max: 80) ?? UUID().uuidString,
                name: name,
                quantity: quantity,
                weightPounds: weight,
                weightConfirmed: confirmed && (weight ?? 0) > 0,
                bulky: (row["bulky"] as? Bool) ?? (row["bulky"] as? NSNumber)?.boolValue ?? false,
                fragile: (row["fragile"] as? Bool) ?? (row["fragile"] as? NSNumber)?.boolValue ?? false,
                note: text(row["note"], max: 160)
            )
        }
    }

    private static func price(_ body: [String: Any]) -> Priced {
        let source = (body["estimate_source"] as? String) ?? ""
        guard DemoRouteFixture.isPricedRoad(source) else {
            return Priced(fee: nil, total: nil, share: nil, state: "review")
        }
        let confirmed = (body["weight_confirmed"] as? Bool) ?? (body["weight_confirmed"] as? NSNumber)?.boolValue ?? false
        let bulky = (body["bulky"] as? Bool) ?? (body["bulky"] as? NSNumber)?.boolValue ?? false
        switch PricingPolicy.evaluate(.init(
            extraMeters: number(body["extra_meters"]) ?? 0,
            extraSeconds: number(body["extra_seconds"]) ?? 0,
            weightPounds: number(body["weight_pounds"]),
            weightConfirmed: confirmed,
            bulky: bulky,
            agreedWaitingMinutes: Int(number(body["waiting_minutes"]) ?? 0)
        )) {
        case .quoted(let quote):
            return Priced(fee: quote.dollars, total: quote.totalCents, share: quote.runnerShareCents, state: "quoted")
        case .manualReview:
            return Priced(fee: nil, total: nil, share: nil, state: "review")
        }
    }

    private static func historyOrder(id: String, trip: String, status: OrderStatus, fee: Double, share: Int) -> Order {
        let stamp = stamp()
        let houston = Places.city(named: "Houston")!
        return Order(
            id: id, tripId: trip, customerId: "demo-maya", driverId: "demo-jordan",
            restaurantPlaceId: "sample:history", restaurantName: "Bayou Bowl Kitchen", restaurantAddress: "Sample address, Houston, TX",
            restaurantLat: houston.lat, restaurantLng: houston.lng, restaurantWebsite: nil, placeSource: "sample",
            destinationType: "campus", destinationLabel: "Campus Library Plaza — demo location",
            destinationLat: 30.618, destinationLng: -96.338, detourMinutes: 4, deliveryFee: fee, estimateSource: "sample",
            estimatedArrivalAt: nil, customerNote: nil, itemSummary: "Rice bowl · 1 · 2 lb", quoteCents: Int(fee * 100), runnerShareCents: share,
            quoteState: "quoted", confirmationPin: nil, pinAttempts: 0, pickupName: "HR-DEMO-104", restaurantOrderNumber: nil,
            pickupReadyAt: stamp, pickupInstructions: nil, status: status, cancelledBy: nil, acceptedAt: stamp,
            restaurantOrderConfirmedAt: stamp, pickedUpAt: status == .delivered ? stamp : nil, onTheWayAt: status == .delivered ? stamp : nil,
            deliveredAt: status == .delivered ? stamp : nil, declinedAt: nil, cancelledAt: nil, createdAt: stamp, updatedAt: stamp,
            trip: nil, driver: nil, customer: nil
        )
    }

    private static func pin() -> String { String(format: "%04d", Int.random(in: 0...9999)) }

    private func messages(for orderId: String, user: StoredUser) -> [OrderMessage] {
        guard let order = db.orders.first(where: { $0.id == orderId }), order.customerId == user.id || order.driverId == user.id else { return [] }
        var rows = db.messages ?? []
        var changed = false
        for index in rows.indices where rows[index].orderId == orderId && rows[index].senderId != user.id && !(rows[index].seenBy ?? []).contains(user.id) {
            var seen = rows[index].seenBy ?? []
            seen.append(user.id)
            rows[index].seenBy = seen
            changed = true
        }
        if changed {
            db.messages = rows
            try? save()
        }
        return rows.filter { $0.orderId == orderId }.sorted { $0.createdAt < $1.createdAt }
    }

    private func inboxCount(for user: StoredUser) -> InboxCount {
        let notices = (db.notices ?? []).filter { $0.recipientId == user.id && $0.readAt == nil }.count
        let messages = (db.messages ?? []).filter { message in
            guard message.senderId != user.id else { return false }
            guard let order = db.orders.first(where: { $0.id == message.orderId }) else { return false }
            guard order.customerId == user.id || order.driverId == user.id else { return false }
            return !(message.seenBy ?? []).contains(user.id)
        }.count
        return InboxCount(notices: notices, messages: messages)
    }

    private func postMessage(user: StoredUser, body: [String: Any]) throws -> MessageList {
        guard let orderId = text(body["order_id"], max: 80),
              let order = db.orders.first(where: { $0.id == orderId }),
              order.customerId == user.id || order.driverId == user.id else {
            throw APIError(message: "That conversation isn't available.", code: "forbidden")
        }
        guard let text = text(body["body"], max: 500) else {
            throw APIError(message: "Write a message first.", code: "bad_request")
        }
        var messages = db.messages ?? []
        messages.append(OrderMessage(id: UUID().uuidString, orderId: orderId, senderId: user.id, body: text, createdAt: Self.stamp()))
        db.messages = messages
        try save()
        return MessageList(messages: self.messages(for: orderId, user: user))
    }

    private func demoActors() -> [DemoActor] {
        [
            DemoActor(id: "demo-maya", name: "Anish Koduri", detail: "Customer · College Station"),
            DemoActor(id: "demo-jordan", name: "Jordan Ellis", detail: "Runner · Houston"),
            DemoActor(id: "demo-avery", name: "Avery Patel", detail: "Runner · Dallas"),
            DemoActor(id: "demo-sam", name: "Sam Rivera", detail: "Runner · Austin"),
            DemoActor(id: "demo-alex", name: "Alex Morgan", detail: "Customer"),
            DemoActor(id: "demo-taylor", name: "Taylor Brooks", detail: "Demo support only"),
            DemoActor(id: "1", name: "Account 1", detail: "Existing local sign-in"),
        ]
    }

    private func switchDemo(_ id: String) throws -> AuthPayload {
        guard demoActors().contains(where: { $0.id == id }),
              let user = db.users.first(where: { $0.id == id || (id == "1" && $0.email == "1") }) else {
            throw APIError(message: "That demo person isn't available.", code: "not_found")
        }
        return try issue(user)
    }

    private func seedDemoIfNeeded() {
        if !db.users.contains(where: { $0.id == "demo-jordan" }) {
            func person(_ id: String, _ name: String, _ email: String, _ intent: AccountUse) -> StoredUser {
                StoredUser(id: id, email: email, passwordHash: Self.hash("demo", salt: id), passwordSalt: id, displayName: name, avatarUrl: nil, paymentHandle: nil, createdAt: Self.stamp(), intent: intent.rawValue)
            }
            db.users.append(contentsOf: [
                person("demo-maya", "Anish Koduri", "maya@demo.local", .order),
                person("demo-jordan", "Jordan Ellis", "jordan@demo.local", .deliver),
                person("demo-avery", "Avery Patel", "avery@demo.local", .deliver),
                person("demo-sam", "Sam Rivera", "sam@demo.local", .both),
                person("demo-alex", "Alex Morgan", "alex@demo.local", .order),
            ])
        }
        guard !db.trips.contains(where: { $0.id == "demo-trip-jordan" }) else { return }
        func trip(_ id: String, _ driver: String, _ city: String, _ days: Int, _ hour: Int, _ slots: Int, _ stop: String, _ lat: Double, _ lng: Double, _ status: String) -> Trip {
            let when = DemoClock.chicago(days, hour: hour, minute: 0)
            return Trip(
                id: id, driverId: driver, originCity: city, originLat: lat, originLng: lng,
                destinationCity: Places.destination.name, destinationLat: Places.destination.lat, destinationLng: Places.destination.lng,
                departureAt: Self.plain.string(from: when), maxOrders: slots, notes: "Demo trip. Sample stop, not a live partnership.",
                status: status, createdAt: Self.stamp(), driver: nil,
                stops: [TripStop(id: id + "-stop", tripId: id, placeId: "sample:\(id)", restaurantName: stop, address: "Sample address, \(city), TX", lat: lat, lng: lng, stopOrder: 0)],
                activeOrders: nil
            )
        }
        let houston = Places.city(named: "Houston")!
        let dallas = Places.city(named: "Dallas")!
        let austin = Places.city(named: "Austin")!
        db.trips.append(contentsOf: [
            trip("demo-trip-jordan", "demo-jordan", "Houston", 1, 16, 4, "Bayou Bowl Kitchen", houston.lat, houston.lng, "scheduled"),
            trip("demo-trip-avery", "demo-avery", "Dallas", 1, 13, 3, "North Loop Pantry", dallas.lat, dallas.lng, "scheduled"),
            trip("demo-trip-sam", "demo-sam", "Austin", 2, 15, 2, "Cedar Trail Market", austin.lat, austin.lng, "scheduled"),
            trip("demo-trip-jordan-later", "demo-jordan", "Houston", 4, 16, 4, "Bayou Market", houston.lat, houston.lng, "scheduled"),
            trip("demo-trip-jordan-draft", "demo-jordan", "Houston", 3, 18, 4, "Bayou Coffee Counter", houston.lat, houston.lng, "draft"),
        ])
        try? save()
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try Self.snake.encode(value)
    }

    private static func object(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        let value = try JSONSerialization.jsonObject(with: data)
        return value as? [String: Any] ?? [:]
    }

    private static func load(from url: URL) -> Database {
        let empty = Database(users: [], sessions: [], trips: [], orders: [], messages: [], ledger: [], notices: [], savedRequests: [], supportCases: [], savedPlaces: [])
        guard FileManager.default.fileExists(atPath: url.path) else { return empty }
        guard let data = try? Data(contentsOf: url) else { return empty }
        do {
            return try JSONDecoder().decode(Database.self, from: data)
        } catch {
            let backup = url.deletingLastPathComponent().appendingPathComponent("store.unreadable.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return empty
        }
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
        let directory = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.fileEncoder.encode(snapshot).write(to: storageURL, options: .atomic)
        db = snapshot
        for index in db.trips.indices {
            db.trips[index].stops = snapshot.trips[index].stops
        }
    }

    private static var defaultStorageURL: URL {
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
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        return nil
    }

    private func flag(_ value: Any?) -> Bool? {
        if value is NSNull { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
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
