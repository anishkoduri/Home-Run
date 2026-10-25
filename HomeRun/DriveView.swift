import SwiftUI

struct DriveView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var section: Section
    @State private var trips: [Trip] = []
    @State private var orders: [Order] = []
    @State private var error: String?
    @State private var busy = false
    @State private var tripPendingCancel: Trip?
    @State private var declining: Order?
    @State private var declineReason = ""
    @State private var countering: Order?
    @State private var counterDollars = "18"
    @State private var counterReason = ""
    @State private var paidCents = 0
    @State private var ledger: [LedgerEntry] = []
    @State private var earningPeriod = "all"
    @State private var latestFirst = true
    @State private var editingTrip: Trip?

    enum Section: String, CaseIterable, Identifiable {
        case requests = "Requests"
        case deliveries = "Deliveries"
        case trips = "My trips"
        case earnings = "Earnings"
        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .requests: return "bell.fill"
            case .deliveries: return "shippingbox.fill"
            case .trips: return "map.fill"
            case .earnings: return "dollarsign.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(section.rawValue).font(Theme.brand(.title)).foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        NavigationLink {
                            InboxView()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .frame(width: 44, height: 44)
                                if model.noticeBadge > 0 {
                                    Text("\(model.noticeBadge)")
                                        .font(Theme.text(.caption2, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Theme.maroon)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .accessibilityLabel(model.noticeBadge > 0 ? "Notifications, \(model.noticeBadge) unread" : "Notifications")
                        NavigationLink("Post a trip") { PostTripView() }
                            .font(Theme.text(.subheadline, weight: .semibold))
                            .frame(minHeight: 44)
                    }
                    if let error { ErrorBanner(message: error) }
                    switch section {
                    case .requests:
                        let incoming = orders.filter { $0.status == .requested }
                        Text(latestFirst ? "Latest" : "Soonest departure").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                        Button(latestFirst ? "Sort by departure" : "Sort latest") { latestFirst.toggle() }
                            .font(Theme.text(.caption, weight: .semibold))
                        if incoming.isEmpty {
                            EmptyState(title: "You're all caught up", message: "New requests show up here.")
                        }
                        ForEach(sortedRequests(incoming)) { order in requestRow(order) }
                    case .deliveries:
                        let active = orders.filter { $0.status.isActiveDelivery }
                        if active.isEmpty {
                            EmptyState(title: "No deliveries right now", message: "Accepted requests move here.")
                        }
                        ForEach(active) { order in deliveryRow(order) }
                    case .trips:
                        if trips.isEmpty {
                            EmptyState(title: "No trips yet", message: "Post a trip when you're driving back.")
                        }
                        ForEach(trips) { trip in tripRow(trip) }
                    case .earnings:
                        let delivered = orders.filter { $0.status == .delivered && inPeriod($0.deliveredAt) }
                        let pending = orders.filter { $0.status.isActiveDelivery }
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Period", selection: $earningPeriod) {
                                Text("This week").tag("week")
                                Text("All").tag("all")
                            }
                            .pickerStyle(.segmented)
                            Text("Still out").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                            Text(Fees.money(pending.reduce(0) { $0 + ($1.deliveryFee ?? 0) })).font(Theme.price(.title2)).foregroundStyle(Theme.maroon)
                            Text("Delivered").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                            Text(Fees.money(delivered.reduce(0) { $0 + share($1) })).font(Theme.price(.title2)).foregroundStyle(Theme.maroon)
                            Text("Simulated paid").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                            Text(Fees.money(Double(paidInPeriod) / 100)).font(Theme.price(.title3)).foregroundStyle(Theme.ink)
                            ForEach(ledger.filter { $0.kind == "earning" && inPeriod($0.createdAt) }) { entry in
                                NavigationLink(value: entry.orderId) {
                                    Text("Earning \(Fees.money(Double(entry.cents) / 100))")
                                        .font(Theme.text(.caption))
                                }
                            }
                            Text("Demo balance — no real money.")
                                .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                            Button("Simulate payout") { Task { await payout() } }
                                .font(Theme.text(.caption, weight: .semibold))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sketchPanel()
                    }
                }
                .padding(20)
                .animation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.12), value: section)
            }
            .homeRunPage(road: false)
            .background(Theme.cream.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Theme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationDestination(for: String.self) { OrderDetailView(id: $0) }
            .refreshable { await load() }
            .sheet(item: $declining) { order in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why are you declining?").font(Theme.section())
                        TextField("Short reason", text: $declineReason).padding(12).sketchPanel()
                        PrimaryButton(title: "Decline request") { Task { await decline(order) } }
                        Spacer()
                    }
                    .padding(20)
                    .homeRunPage(road: false)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { declining = nil } } }
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $countering) { order in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Offer a delivery fee from $1 to $250.").font(Theme.section())
                        TextField("Dollars", text: $counterDollars).keyboardType(.decimalPad).padding(12).sketchPanel()
                        TextField("Reason", text: $counterReason).padding(12).sketchPanel()
                        PrimaryButton(title: "Send offer") { Task { await counter(order) } }
                        Spacer()
                    }
                    .padding(20)
                    .homeRunPage(road: false)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { countering = nil } } }
                }
                .presentationDetents([.medium])
            }
            .task { await watch { await load() } }
            .sheet(item: $editingTrip) { trip in
                TripEditor(trip: trip) {
                    editingTrip = nil
                    Task { await load() }
                }
            }
            .confirmationDialog(
                "Cancel this trip?",
                isPresented: Binding(
                    get: { tripPendingCancel != nil },
                    set: { if !$0 { tripPendingCancel = nil } }
                ),
                titleVisibility: .visible,
                presenting: tripPendingCancel
            ) { trip in
                Button("Cancel trip", role: .destructive) { Task { await cancel(trip) } }
                Button("Keep trip", role: .cancel) {}
            } message: { trip in
                Text("\(trip.originCity) → \(trip.destinationCity) will stop accepting requests.")
            }
        }
    }

    private func requestRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(order.customer?.displayName ?? "Customer").fontWeight(.bold)
            Text(order.restaurantName)
            Text("\(Format.minutes(order.detourMinutes)) · \(Fees.money(order.deliveryFee))")
                .font(Theme.price(.subheadline))
                .foregroundStyle(Theme.maroon)
            HStack {
                NavigationLink("Details", value: order.id)
                Button("Decline") { declining = order; declineReason = "" }.foregroundStyle(Theme.bad)
                Button("Counter") { countering = order }.fontWeight(.semibold)
                Button("Accept") { Task { await set(order, .accepted) } }.fontWeight(.bold).disabled(busy)
            }
        }
        .padding(12)
        .sketchPanel()
    }

    private func deliveryRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink(value: order.id) {
                VStack(alignment: .leading) {
                    Text(order.restaurantName).fontWeight(.bold).foregroundStyle(Theme.ink)
                    Text("\(order.customer?.displayName ?? "") · \(order.destinationLabel)")
                        .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    if let name = order.pickupName {
                        Text("Pickup: \(name)\(order.restaurantOrderNumber.map { " · #\($0)" } ?? "")")
                            .font(Theme.text(.caption))
                    } else {
                        Text("Waiting for the customer's restaurant order.").font(Theme.text(.caption)).foregroundStyle(Theme.coral)
                    }
                }
            }
            if order.status == .arriving {
                Text("Open the delivery and enter the customer's code.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            } else if let next = order.status.driverNext {
                Button(next.1) { Task { await set(order, next.0) } }.fontWeight(.bold).disabled(busy)
            }
            Button("Report a delay") { Task { await delay(order) } }
                .font(Theme.text(.caption, weight: .semibold))
            Button("Problem with delivery") { Task { await reportProblem(order) } }
                .font(Theme.text(.caption, weight: .semibold))
        }
        .padding(12)
        .sketchPanel()
    }

    private func tripRow(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CityRoute(origin: trip.originCity, destination: trip.destinationCity)
            Text("\(Format.relative(trip.departureAt)) · \(trip.activeOrders ?? 0) of \(trip.maxOrders) spots")
                .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            Text(trip.status.replacingOccurrences(of: "_", with: " ").capitalized).font(Theme.text(.caption))
            if trip.status == "draft" || trip.status == "scheduled" || trip.status == "requests_closed" {
                Button(trip.templateId == nil ? "Edit trip" : "Edit this date") {
                    editingTrip = trip
                }
                .font(Theme.text(.caption, weight: .semibold))
            }
            if trip.status == "draft" {
                Button("Publish trip") { Task { await setTrip(trip, "scheduled") } }
                    .font(Theme.text(.caption, weight: .semibold))
                if trip.templateId != nil {
                    Button("Skip this date") { Task { await setTrip(trip, "cancelled") } }
                        .font(Theme.text(.caption, weight: .semibold))
                }
            }
            if trip.status == "scheduled" {
                Button("Close requests") { Task { await setTrip(trip, "requests_closed") } }
                    .font(Theme.text(.caption, weight: .semibold))
                Button("Start trip") { Task { await setTrip(trip, "in_progress") } }
                    .font(Theme.text(.caption, weight: .semibold))
                Button("Cancel trip") { tripPendingCancel = trip }.foregroundStyle(Theme.bad)
                Button("Repeat weekly") { Task { await repeatWeekly(trip) } }
                    .font(Theme.text(.caption, weight: .semibold))
                Button("Every other week") { Task { await repeatCadence(trip, "biweekly") } }
                    .font(Theme.text(.caption, weight: .semibold))
                Text(recurrencePreview(trip))
                    .font(Theme.text(.caption))
                    .foregroundStyle(Theme.muted)
            }
            if trip.status == "requests_closed" {
                Button("Reopen requests") { Task { await setTrip(trip, "scheduled") } }
                    .font(Theme.text(.caption, weight: .semibold))
                Button("Start trip") { Task { await setTrip(trip, "in_progress") } }
                    .font(Theme.text(.caption, weight: .semibold))
            }
            if trip.status == "in_progress" {
                Button("Complete trip") { Task { await setTrip(trip, "completed") } }
                    .font(Theme.text(.caption, weight: .semibold))
            }
        }
        .padding(12)
        .ticketPanel()
    }

    private func sortedRequests(_ orders: [Order]) -> [Order] {
        if latestFirst { return orders.sorted { $0.createdAt > $1.createdAt } }
        return orders.sorted { ($0.trip?.departureAt ?? $0.createdAt) < ($1.trip?.departureAt ?? $1.createdAt) }
    }

    private func setTrip(_ trip: Trip, _ status: String) async {
        do {
            let _: OkayBody = try await model.client().store("trips", method: "PATCH", query: ["id": trip.id], body: TripStatusPatch(status: status))
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var paidInPeriod: Int {
        ledger.filter { $0.kind == "payout" && inPeriod($0.createdAt) }.reduce(0) { $0 + $1.cents }
    }

    private func inPeriod(_ iso: String?) -> Bool {
        guard earningPeriod == "week" else { return true }
        guard let iso, let date = Format.parse(iso) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .current
        return calendar.isDate(date, equalTo: DemoClock.now, toGranularity: .weekOfYear)
    }

    private func recurrencePreview(_ trip: Trip) -> String {
        guard let start = Format.parse(trip.departureAt) else { return "Dates appear after the departure is set." }
        let weekly = stride(from: 7, through: 28, by: 7).map { Format.dayTime(Self.iso(start.addingTimeInterval(Double($0) * 86_400))) }
        return "Next 28 days, weekly: \(weekly.joined(separator: ", ")). Every other week uses the first and third."
    }

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func share(_ order: Order) -> Double {
        if let cents = order.runnerShareCents { return Double(cents) / 100 }
        return (order.deliveryFee ?? 0) * 0.8
    }

    private func reportProblem(_ order: Order) async {
        do {
            let _: SupportCase = try await model.client().store("support", method: "POST", body: SupportDraft(orderId: order.id, category: "delivery", details: "The runner reported a problem with this delivery."))
            error = "A support case is open. The delivery code is still required."
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delay(_ order: Order) async {
        struct Body: Encodable { var delayMinutes: Int; var delayReason: String }
        do {
            let _: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: Body(delayMinutes: 10, delayReason: "Traffic added about 10 minutes."))
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func repeatWeekly(_ trip: Trip) async {
        await repeatCadence(trip, "weekly")
    }

    private func repeatCadence(_ trip: Trip, _ cadence: String) async {
        do {
            let _: OkayBody = try await model.client().store("recurrence", method: "POST", body: RepeatTrip(tripId: trip.id, cadence: cadence))
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func payout() async {
        do {
            let _: OkayBody = try await model.client().store("payout", method: "POST")
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func decline(_ order: Order) async {
        let reason = declineReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { error = "Add a short reason."; return }
        do {
            let _: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: DeclinePatch(status: OrderStatus.declined.rawValue, declineReason: reason))
            declining = nil
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func counter(_ order: Order) async {
        let dollars = Double(counterDollars) ?? 0
        let cents = Int((dollars * 100).rounded())
        let reason = counterReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard DemoRules.counterofferAllowed(cents), !reason.isEmpty else {
            error = "Offer $1 to $250 and a reason."
            return
        }
        do {
            let _: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: CounterPatch(counterCents: cents, counterReason: reason))
            countering = nil
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func load() async {
        do {
            let client = try model.client()
            trips = try await client.store("trips", query: ["mine": "1"])
            orders = try await client.store("orders", query: ["role": "driver"])
            let ledger: LedgerList = (try? await client.store("ledger")) ?? LedgerList(entries: [])
            self.ledger = ledger.entries
            paidCents = ledger.entries.filter { $0.kind == "payout" }.reduce(0) { $0 + $1.cents }
            error = nil
            await model.refreshBadges()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func set(_ order: Order, _ status: OrderStatus) async {
        busy = true
        defer { busy = false }
        do {
            let _: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: StatusPatch(status: status.rawValue))
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func cancel(_ trip: Trip) async {
        do {
            let _: OkayBody = try await model.client().store("trips", method: "PATCH", query: ["id": trip.id], body: TripStatusPatch(status: "cancelled"))
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct OkayBody: Decodable { var ok: Bool }
