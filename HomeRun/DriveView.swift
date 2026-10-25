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
    @State private var available: [Order] = []
    @State private var sort = "latest"
    @State private var areaFilter = ""
    @State private var editingTrip: Trip?
    @State private var parkedEdit: Trip?
    @State private var path = NavigationPath()
    @State private var leavePrompt = false

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
        NavigationStack(path: $path) {
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
                        availableFeed
                    case .deliveries:
                        let waiting = orders.filter { $0.status == .requested }
                        let active = orders.filter { $0.status.isActiveDelivery }
                        if waiting.isEmpty && active.isEmpty {
                            EmptyState(title: "No deliveries right now", message: "Accepted requests, and requests already assigned to you, show up here.")
                        }
                        ForEach(waiting) { order in requestRow(order) }
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
                            Text("Delivered earning").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                            Text(Fees.money(delivered.reduce(0) { $0 + share($1) })).font(Theme.price(.title2)).foregroundStyle(Theme.maroon)
                            Text("Earlier merchandise reimbursement").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                            Text(Fees.money(Double(reimbursedInPeriod) / 100)).font(Theme.price(.title3)).foregroundStyle(Theme.ink)
                            Text("Simulated paid").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                            Text(Fees.money(Double(paidInPeriod) / 100)).font(Theme.price(.title3)).foregroundStyle(Theme.ink)
                            ForEach(ledger.filter { $0.kind == "earning" && inPeriod($0.createdAt) }) { entry in
                                NavigationLink(value: entry.orderId) {
                                    Text("Delivery earning \(Fees.money(Double(entry.cents) / 100))")
                                        .font(Theme.text(.caption))
                                }
                            }
                            ForEach(ledger.filter { $0.kind == "merchandise-reimburse" && inPeriod($0.createdAt) }) { entry in
                                NavigationLink(value: entry.orderId) {
                                    Text("Reimbursement \(Fees.money(Double(entry.cents) / 100))")
                                        .font(Theme.text(.caption))
                                }
                            }
                            Text("No real money moves.")
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
            .navigationDestination(for: String.self) { OrderDetailView(id: $0, forRunner: true) }
            .refreshable { await load() }
            .sheet(item: $declining) { order in
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why are you declining?").font(Theme.section())
                        EntryField("Short reason", text: $declineReason).padding(12).sketchPanel()
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
                        EntryField("Dollars", text: $counterDollars, keyboard: .decimalPad).padding(12).sketchPanel()
                        EntryField("Reason", text: $counterReason).padding(12).sketchPanel()
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
            .onChange(of: model.driveRootTick) { _, _ in
                if editingTrip != nil || declining != nil || countering != nil {
                    leavePrompt = true
                } else {
                    path = NavigationPath()
                }
            }
            .confirmationDialog("Leave this form?", isPresented: $leavePrompt, titleVisibility: .visible) {
                Button("Keep draft") {
                    parkedEdit = editingTrip ?? parkedEdit
                    editingTrip = nil
                    declining = nil
                    countering = nil
                    path = NavigationPath()
                }
                Button("Discard", role: .destructive) {
                    parkedEdit = nil
                    editingTrip = nil
                    declining = nil
                    countering = nil
                    declineReason = ""
                    counterReason = ""
                    path = NavigationPath()
                }
                Button("Stay", role: .cancel) {}
            } message: {
                Text("This trip edit is only on this phone until you save it.")
            }
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
            Text(requestMoney(order))
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
                    Text(purchaseCaption(order))
                        .font(Theme.text(.caption))
                        .foregroundStyle(order.purchaseState == "placed" ? Theme.muted : Theme.coral)
                }
            }
            if order.usesCustomerHandoff, order.detailsNeedReview {
                NavigationLink("Review pickup details", value: order.id).fontWeight(.bold)
            } else if let next = order.driverAction, next.0 == .pickedUp, order.usesCustomerHandoff {
                NavigationLink("Open collection checklist", value: order.id).fontWeight(.bold)
            } else if order.status == .arriving {
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
            Text("\(Format.relative(trip.departureAt)) · \(TripCopy.pickupLimit(trip))")
                .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            Text(trip.status.replacingOccurrences(of: "_", with: " ").capitalized).font(Theme.text(.caption))
            if trip.status == "draft" || trip.status == "scheduled" || trip.status == "requests_closed" {
                Button(trip.templateId == nil ? "Edit trip" : "Edit this date") {
                    editingTrip = parkedEdit?.id == trip.id ? parkedEdit : trip
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

    private var reimbursedInPeriod: Int {
        ledger.filter { $0.kind == "merchandise-reimburse" && inPeriod($0.createdAt) }.reduce(0) { $0 + $1.cents }
    }

    private func requestMoney(_ order: Order) -> String {
        let delivery = Fees.money(order.deliveryFee)
        if order.isRunnerPurchase, let goods = order.merchandiseCents {
            return "\(Format.minutes(order.detourMinutes)) · Earlier merchandise \(Fees.money(Double(goods) / 100)) · Delivery \(delivery)"
        }
        return "\(Format.minutes(order.detourMinutes)) · Delivery \(delivery)"
    }

    private func purchaseCaption(_ order: Order) -> String {
        if order.isPersonalPickup { return order.handoffComplete ? "Pickup arranged" : "Home pickup. Details still needed." }
        if order.isRunnerPurchase { return order.purchaseState == "placed" ? "Earlier purchase recorded" : "Earlier runner-purchase record" }
        if order.detailsNeedReview { return "Customer submitted confirmation" }
        if order.handoffComplete { return "Runner reviewed details" }
        if order.status == .accepted { return "Awaiting pickup details" }
        return "Awaiting runner"
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

    private func areaChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.text(.caption, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Theme.maroon : Theme.surface)
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var rankedAvailable: [Order] {
        switch sort {
        case "closest":
            return RequestRanking.closest(available, origin: model.runnerOrigin)
        case "recommended":
            return RequestRanking.recommended(available, origin: model.runnerOrigin, area: model.runnerArea, now: DemoClock.now)
        default:
            return RequestRanking.latest(available)
        }
    }

    private var availableFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available requests").font(Theme.section())
            Picker("Sort", selection: $sort) {
                Text("Latest").tag("latest")
                Text("Closest").tag("closest")
                Text("Recommended").tag("recommended")
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("request-sort")
            if model.runnerOrigin == nil {
                Text("Choose a starting area to sort by distance. This does not use a pretend GPS point.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            } else if model.runnerAreaSource == "manual" {
                Text("Manual area: \(model.runnerArea). Distances are approximate geographic distance, not a driving route.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            } else {
                Text("Device location. Closest uses approximate geographic distance unless a road route is calculated when you claim.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    areaChip("All", selected: areaFilter.isEmpty) {
                        areaFilter = ""
                        Task { await load() }
                    }
                    .accessibilityIdentifier("area-All")
                    ForEach(["Houston", "Dallas", "Austin"], id: \.self) { name in
                        areaChip(name, selected: areaFilter == name) {
                            areaFilter = name
                            model.setManualArea(name)
                            Task { await load() }
                        }
                        .accessibilityIdentifier("area-\(name)")
                    }
                }
            }
            Button("Use current location") {
                RunnerLocator.shared.onFix = { location in
                    model.setDeviceArea(lat: location.coordinate.latitude, lng: location.coordinate.longitude, label: "Current location")
                }
                RunnerLocator.shared.request()
            }
                .font(Theme.text(.caption, weight: .semibold))
            if rankedAvailable.isEmpty {
                EmptyState(title: "No open requests", message: "Posted pickups that still need a runner show up here. You don't need a trip to look.")
            }
            ForEach(rankedAvailable) { order in
                let preview = RequestRanking.payoutPreview(order, origin: model.runnerOrigin)
                HStack(alignment: .center, spacing: 12) {
                    NavigationLink(value: order.id) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.personalItem == true ? "Personal item" : order.restaurantName)
                                .font(Theme.text(.headline, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text("\(order.pickupCity ?? "Pickup") → \(order.destinationLabel)")
                                .font(Theme.text(.caption))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                            Text(order.itemSummary ?? "")
                                .font(Theme.text(.caption))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("available-request")
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(Fees.money(Double(preview.shareCents) / 100))
                            .font(Theme.price(.headline))
                            .foregroundStyle(Theme.maroon)
                        Text("Est.")
                            .font(Theme.text(.caption2, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        if order.customerId == model.user?.id {
                            Text("You posted this.")
                                .font(Theme.text(.caption2))
                                .foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Button("Claim") { Task { await claim(order) } }
                                .font(Theme.text(.caption, weight: .bold))
                                .accessibilityIdentifier("claim-\(order.id)")
                        }
                    }
                }
                .padding(.vertical, 10)
                Divider()
            }
        }
    }

    private func claim(_ order: Order) async {
        let preview = RequestRanking.payoutPreview(order, origin: model.runnerOrigin)
        let trip = trips.first { $0.status == "scheduled" && $0.destinationCity == Places.destination.name }
        let meters = preview.meters
        let incremental = model.runnerOrigin != nil
        struct Body: Encodable {
            var offer: String
            var extraMeters: Double
            var extraSeconds: Double
            var distanceKind: String
            var incremental: Bool
            var tripId: String?
        }
        do {
            let _: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: Body(offer: "submit", extraMeters: meters, extraSeconds: preview.seconds, distanceKind: "geographic", incremental: incremental, tripId: trip?.id))
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
            let city = Places.city(named: areaFilter)?.name ?? ""
            let open: [Order] = try await client.store("orders", query: city.isEmpty ? ["role": "available"] : ["role": "available", "city": city])
            let mine: [Order] = try await client.store("orders")
            let posted = mine.filter { order in
                order.status == .requested && order.driverId.isEmpty && RequestRanking.matchesPickupCity(order, filter: areaFilter)
            }
            var seen = Set(open.map(\.id))
            available = (open + posted.filter { seen.insert($0.id).inserted })
                .filter { RequestRanking.matchesPickupCity($0, filter: areaFilter) }
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
