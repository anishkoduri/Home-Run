import SwiftUI

enum DemoTerms {
    static func accepted(by userId: String?) -> Bool {
        guard let userId else { return false }
        return UserDefaults.standard.string(forKey: "homerun.terms.\(userId)") == DemoRules.termsVersion
    }

    static func accept(userId: String) {
        UserDefaults.standard.set(DemoRules.termsVersion, forKey: "homerun.terms.\(userId)")
    }

    static func clearDemoAcceptance() {
        for id in ["demo-maya", "demo-jordan", "demo-avery", "demo-sam", "demo-alex", "demo-taylor"] {
            UserDefaults.standard.removeObject(forKey: "homerun.terms.\(id)")
        }
    }
}

struct TermsGate: View {
    var userId: String
    var onAccept: () -> Void
    @State private var checked = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Home Run").font(Theme.brand(.title))
                    Text("By Aggies, for Aggies.").font(Theme.text(.subheadline, weight: .semibold)).foregroundStyle(Theme.maroon)
                        .accessibilityIdentifier("slogan")
                    Text("Demo • sample data • no real charges").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    Text(LegalCopy.terms).font(Theme.text(.footnote))
                    Text(LegalCopy.privacy).font(Theme.text(.footnote)).foregroundStyle(Theme.muted)
                    Toggle("I agree to the demo terms", isOn: $checked)
                        .font(Theme.text(.body))
                    PrimaryButton(title: "Continue", busy: false) { DemoTerms.accept(userId: userId); onAccept() }
                        .disabled(!checked)
                        .opacity(checked ? 1 : 0.45)
                }
                .padding(20)
            }
            .homeRunPage(road: false)
            .navigationTitle("Terms")
        }
    }
}

struct InboxView: View {
    @Environment(AppModel.self) private var model
    @State private var notices: [AppNotice] = []
    @State private var error: String?

    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(Theme.bad) }
            if notices.isEmpty { Text("No notifications.").foregroundStyle(Theme.muted) }
            ForEach(notices) { notice in
                VStack(alignment: .leading, spacing: 4) {
                    Text(notice.title).font(Theme.text(.body, weight: .semibold))
                    Text(notice.body).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    if notice.readAt == nil { Text("Unread").font(Theme.text(.caption)).foregroundStyle(Theme.maroon) }
                    if let orderId = notice.orderId {
                        NavigationLink("Open order") { OrderDetailView(id: orderId) }
                    } else if let tripId = notice.tripId {
                        Text("Trip \(tripId)").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { Task { await mark(notice) } }
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            Button("Mark all read") { Task { await markAll() } }
        }
        .task { await load() }
    }

    private func load() async {
        do {
            let list: NoticeList = try await model.client().store("notices")
            notices = list.notices
        } catch { self.error = error.localizedDescription }
    }

    private func mark(_ notice: AppNotice) async {
        let _: OkayBody = (try? await model.client().store("notices", method: "PATCH", body: NoticeRead(id: notice.id, all: nil))) ?? OkayBody(ok: false)
        await load()
    }

    private func markAll() async {
        let _: OkayBody = (try? await model.client().store("notices", method: "PATCH", body: NoticeRead(id: nil, all: true))) ?? OkayBody(ok: false)
        await load()
    }
}

struct SavedRequestsView: View {
    @Environment(AppModel.self) private var model
    @State private var rows: [SavedRequest] = []
    @State private var city: String
    @State private var place = ""
    @State private var error: String?

    init(city: String = "San Antonio") {
        _city = State(initialValue: city)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saving a request does not book a trip or charge a fee.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                TextField("Pickup city", text: $city).padding(12).sketchPanel()
                TextField("Place, optional", text: $place).padding(12).sketchPanel()
                if let error { ErrorBanner(message: error) }
                PrimaryButton(title: "Save request") { Task { await save() } }
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row.city).font(Theme.text(.body, weight: .semibold))
                        if let place = row.placeName, !place.isEmpty { Text(place).font(Theme.text(.caption)) }
                        Text(savedCopy(row.status))
                            .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        HStack {
                            if row.status == "paused" {
                                Button("Resume") { Task { await set(row, "open") } }
                            } else if row.status == "open" {
                                Button("Pause") { Task { await set(row, "paused") } }
                            }
                            Button("Delete") { Task { await set(row, "deleted") } }
                                .foregroundStyle(Theme.bad)
                        }
                        .font(Theme.text(.caption, weight: .semibold))
                    }
                    .padding(12)
                    .ticketPanel()
                }
            }
            .padding(20)
        }
        .navigationTitle("Saved requests")
        .homeRunPage(road: false)
        .task { await load() }
    }

    private func load() async {
        let list: SavedRequestList = (try? await model.client().store("saved-requests")) ?? SavedRequestList(requests: [])
        rows = list.requests
    }

    private func save() async {
        do {
            let _: SavedRequest = try await model.client().store("saved-requests", method: "POST", body: SavedRequestDraft(city: city, placeName: place.isEmpty ? nil : place))
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func set(_ row: SavedRequest, _ status: String) async {
        struct Patch: Encodable { var id: String; var status: String }
        do {
            let _: SavedRequest = try await model.client().store("saved-requests", method: "PATCH", body: Patch(id: row.id, status: status))
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func savedCopy(_ status: String) -> String {
        switch status {
        case "matched": return "A matching trip was posted. This is not a booking."
        case "paused": return "Paused. A new trip will not notify you until you resume."
        default: return "Waiting for a trip."
        }
    }
}

struct SavedPlacesView: View {
    @Environment(AppModel.self) private var model
    @State private var places: [SavedPlace] = []

    var body: some View {
        List {
            if places.isEmpty { Text("Saved places show up here.").foregroundStyle(Theme.muted) }
            ForEach(places) { place in
                VStack(alignment: .leading) {
                    Text(place.name).font(Theme.text(.body, weight: .semibold))
                    Text(place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    Button("Remove") { Task { await remove(place) } }
                        .font(Theme.text(.caption, weight: .semibold))
                        .foregroundStyle(Theme.bad)
                }
            }
        }
        .navigationTitle("Saved places")
        .task { await load() }
    }

    private func load() async {
        let list: SavedPlaceList = (try? await model.client().store("saved-places")) ?? SavedPlaceList(places: [])
        places = list.places
    }

    private func remove(_ place: SavedPlace) async {
        struct Body: Encodable { var placeId: String; var name: String; var lat: Double; var lng: Double }
        let _: SavedPlaceList? = try? await model.client().store("saved-places", method: "POST", body: Body(placeId: place.placeId, name: place.name, lat: place.lat, lng: place.lng))
        await load()
    }
}

struct SupportDeskView: View {
    @Environment(AppModel.self) private var model
    @State private var cases: [SupportCase] = []
    @State private var error: String?

    var body: some View {
        List {
            if let error { Text(error) }
            ForEach(cases) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.category).font(Theme.text(.body, weight: .semibold))
                    Text(item.details).font(Theme.text(.caption))
                    Text(item.status.replacingOccurrences(of: "_", with: " ")).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    if model.user?.id == "demo-taylor" {
                        Button("Mark in review") { Task { await update(item, "in_review") } }
                        Button("Resolve") { Task { await update(item, "resolved") } }
                        if let orderId = item.orderId {
                            Button("Simulate full refund") { Task { await refund(orderId) } }
                        }
                    }
                }
            }
        }
        .navigationTitle("Support")
        .task { await load() }
    }

    private func load() async {
        let list: SupportList = (try? await model.client().store("support")) ?? SupportList(cases: [])
        cases = list.cases
    }

    private func update(_ item: SupportCase, _ status: String) async {
        struct Patch: Encodable { var id: String; var status: String; var resolution: String }
        do {
            let _: SupportCase = try await model.client().store("support", method: "PATCH", body: Patch(id: item.id, status: status, resolution: "Demo resolution. No real refund unless you use the refund action."))
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func refund(_ orderId: String) async {
        struct Body: Encodable { var orderId: String }
        do {
            let _: OkayBody = try await model.client().store("support-refund", method: "POST", body: Body(orderId: orderId))
            await load()
        } catch { self.error = error.localizedDescription }
    }
}

struct FAQView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(LegalCopy.faq).font(Theme.text(.body))
            }
            .padding(20)
        }
        .navigationTitle("FAQ")
        .homeRunPage(road: false)
    }
}

struct DemoControlView: View {
    @Environment(AppModel.self) private var model
    @State private var city = "San Antonio"
    @State private var confirmReset = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("These controls change the demo clock and fictional records. They do not touch a non-demo account.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                Button("Advance 5 minutes") { DemoClock.advance(by: 5 * 60); message = "Clock moved 5 minutes." }
                Button("Advance 15 minutes") { DemoClock.advance(by: 15 * 60); message = "Clock moved 15 minutes." }
                Button("Advance 1 day") { DemoClock.advance(by: 86_400); message = "Clock moved 1 day." }
                TextField("City to publish", text: $city).padding(12).sketchPanel()
                Button("Publish a matching trip") { Task { await publish() } }
                Text("Presenter scenarios").font(Theme.section())
                Text("Each one resets fictional demo records, then leaves the shared orders and trips ready to use on the normal screens. Account 1 is left alone.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                ForEach(1...10, id: \.self) { number in
                    Button(scenarioName(number)) { Task { await prepare(number) } }
                        .accessibilityIdentifier("scenario-\(number)")
                }
                Button("Reset demo records") { confirmReset = true }.foregroundStyle(Theme.bad)
                if let message { Text(message).font(Theme.text(.caption)) }
            }
            .font(Theme.text(.body, weight: .semibold))
            .padding(20)
        }
        .navigationTitle("Demo controls")
        .homeRunPage(road: false)
        .confirmationDialog("Replace fictional demo trips and orders?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset demo records", role: .destructive) { Task { await reset() } }
            Button("Keep them", role: .cancel) {}
        } message: {
            Text("Demo trips, orders, notices, and balances are replaced with the baseline. Account 1 is left alone.")
        }
    }

    private func publish() async {
        struct Body: Encodable { var city: String }
        do {
            let _: OkayBody = try await model.client().store("demo-publish", method: "POST", body: Body(city: city))
            message = "If that city had no open trip, one was posted. A saved request gets a single notice and is not booked."
        } catch { message = error.localizedDescription }
    }

    private func scenarioName(_ number: Int) -> String {
        switch number {
        case 1: return "1 · Houston dinner"
        case 2: return "2 · Worth the detour"
        case 3: return "3 · A little heavier"
        case 4: return "4 · One stop, two orders"
        case 5: return "5 · Catch the next trip"
        case 6: return "6 · Plans change"
        case 7: return "7 · The last spot"
        case 8: return "8 · Make it right"
        case 9: return "9 · Welcome, Aggie"
        default: return "10 · Offline, still presentable"
        }
    }

    private func prepare(_ number: Int) async {
        struct Body: Encodable { var scenario: Int }
        do {
            let prep: ScenarioPrep = try await model.client().store("demo-scenario", method: "POST", body: Body(scenario: number))
            DemoRouteFixture.set(prep.fixture)
            DemoRouteFixture.setSamples(prep.forceSamples)
            if prep.clearTerms { DemoTerms.clearDemoAcceptance() }
            model.confirmPickupCity(prep.city)
            message = "\(prep.title). \(prep.instructions)"
        } catch {
            message = error.localizedDescription
        }
    }

    private func reset() async {
        do {
            let _: OkayBody = try await model.client().store("demo-reset", method: "POST")
            message = "Demo records are back to the baseline."
        } catch { message = error.localizedDescription }
    }
}

enum LegalCopy {
    static let terms = """
    Demo terms, version demo-1. This copy is a draft for the class demonstration and needs legal review before any real service.

    Home Run is a student demo. It is not an official Texas A&M University service. The app coordinates a pickup between two people who already know the trip. It does not sell food, hold a card, or move money.

    A quoted delivery fee is a simulation. Nothing is charged. Accepting a request, cancelling, or receiving a refund only updates the on-device demo ledger. A runner's share is a simulated balance, not a bank transfer.

    Availability and earnings are never guaranteed. A trip can fill up, a quote can expire, and a runner can decline.
    """

    static let privacy = """
    Demo privacy note. Records stay in a file on this phone. The demo does not send email, SMS, or push notifications. Place search uses Google only when a key is configured on the device; otherwise the catalog is labeled sample data. This note does not describe a production privacy policy.
    """

    static let faq = """
    Who pays the restaurant? You do, outside Home Run, after a runner accepts.

    What does the delivery fee mean? It is a simulated quote. The runner's share in the demo is 80 percent of that quote.

    Can I cancel? Before acceptance, the simulated authorization is released. After acceptance and before pickup, the full simulated fee is refunded. After pickup, open a support case.

    Does a saved request book anything? No. It only notifies you if a matching trip is posted.
    """
}

private struct OkayBody: Decodable { var ok: Bool }
