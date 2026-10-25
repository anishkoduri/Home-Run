import MapKit
import SwiftUI

struct OrderDetailView: View {
    @Environment(AppModel.self) private var model
    var id: String
    @State private var order: Order?
    @State private var error: String?
    @State private var busy = false
    @State private var pickupName = ""
    @State private var orderNumber = ""
    @State private var ready = Date().addingTimeInterval(3600)
    @State private var instructions = ""
    @State private var ordered = false
    @State private var confirmCancel = false
    @State private var routePath: [[Double]]?
    @State private var routeSource: String?
    @State private var pinEntry = ""
    @State private var messageText = ""
    @State private var messages: [OrderMessage] = []
    @State private var helpOpen = false
    @State private var helpDetails = ""
    @State private var receipt: [LedgerEntry] = []
    @State private var showReceipt = false

    var body: some View {
        ScrollView {
            if let order {
                content(order)
            } else if let error {
                ErrorBanner(message: error).padding(20)
            } else {
                ProgressView("Loading order…").padding(40)
            }
        }
        .homeRunPage(road: false)
        .background(Theme.cream.ignoresSafeArea())
        .toolbarBackground(Theme.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .navigationTitle(order?.restaurantName ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .task { await watch { await load() } }
        .sheet(isPresented: $showReceipt) {
            NavigationStack {
                List(receipt) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.kind.capitalized).font(Theme.text(.body, weight: .semibold))
                        Text(Fees.money(Double(entry.cents) / 100)).font(Theme.text(.caption))
                    }
                }
                .navigationTitle("Simulated receipt")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showReceipt = false } } }
            }
        }
    }

    @ViewBuilder
    private func content(_ order: Order) -> some View {
        let role = order.driverId == model.user?.id ? "driver" : "customer"
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text(role == "driver" ? "Delivery for \(order.customer?.displayName ?? "customer")" : "Order \(Format.shortId(order.id))")
                        .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                    Text(order.restaurantName).font(Theme.brand(.title2)).foregroundStyle(Theme.maroon)
                    Text("\(order.trip?.originCity ?? "") → \(order.destinationLabel)").foregroundStyle(Theme.muted)
                }
                Spacer()
                StatusPill(status: order.status)
            }
            if let error { ErrorBanner(message: error) }
            actions(order, role: role)
            timeline(order)
            facts(order, role: role)
            conversation
            if let trip = order.trip {
                RouteMap(path: routePath ?? [
                    [trip.originLat, trip.originLng],
                    [order.restaurantLat, order.restaurantLng],
                    [order.destinationLat, order.destinationLng],
                    [trip.destinationLat, trip.destinationLng],
                ])
                Text(routeCaption)
                    .font(Theme.text(.caption))
                    .foregroundStyle(Theme.muted)
                    .font(Theme.text(.caption))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(20)
        .onAppear {
            pickupName = order.pickupName ?? model.profile?.displayName ?? ""
            orderNumber = order.restaurantOrderNumber ?? ""
            instructions = order.pickupInstructions ?? ""
            if let readyAt = order.pickupReadyAt, let date = Format.parse(readyAt) { ready = date }
            ordered = order.status == .restaurantConfirmed
        }
    }

    @ViewBuilder
    private func actions(_ order: Order, role: String) -> some View {
        Card {
            if role == "driver" && order.status == .requested {
                Text("\(Format.firstName(order.customer?.displayName)) wants \(order.restaurantName).")
                Text("About \(Format.minutes(order.detourMinutes)) extra for \(Fees.money(order.deliveryFee)).")
                    .foregroundStyle(Theme.muted)
                PrimaryButton(title: "Accept request", busy: busy) { Task { await setStatus(order, .accepted) } }
                Button("Decline") { Task { await setStatus(order, .declined) } }.foregroundStyle(Theme.bad)
            } else if role == "driver", let next = order.status.driverNext {
                Text(next.1)
                PrimaryButton(title: next.1, busy: busy) { Task { await setStatus(order, next.0) } }
            } else if role == "customer" && (order.status == .accepted || order.status == .restaurantConfirmed) {
                Text(order.status == .accepted ? "Place and pay for the restaurant order, then add pickup details." : "Update pickup details.")
                    .foregroundStyle(Theme.muted)
                Toggle("I placed and paid for my order", isOn: $ordered)
                TextField("Name on the order", text: $pickupName)
                    .padding(12)
                    .frame(minHeight: 44)
                    .sketchPanel()
                TextField("Order number (optional)", text: $orderNumber)
                    .padding(12)
                    .frame(minHeight: 44)
                    .sketchPanel()
                DatePicker("Ready", selection: $ready)
                TextField("Pickup instructions", text: $instructions, axis: .vertical)
                    .padding(12)
                    .frame(minHeight: 44)
                    .sketchPanel()
                PrimaryButton(title: order.status == .restaurantConfirmed ? "Save pickup details" : "Confirm restaurant order", busy: busy) {
                    Task { await confirm(order) }
                }
            } else if role == "driver", order.status == .arriving {
                Text("Ask the customer for the confirmation code. It is not shown here.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                TextField("Confirmation code", text: $pinEntry)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .sketchPanel()
                    .accessibilityIdentifier("delivery-pin")
                PrimaryButton(title: "Complete delivery", busy: busy) { Task { await complete(order) } }
            } else if role == "customer", order.status == .arriving, let pin = order.confirmationPin {
                Text("Confirmation code")
                    .font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                Text(pin).font(Theme.price(.title)).foregroundStyle(Theme.maroon)
                    .accessibilityIdentifier("customer-pin")
                Text("Read this to the runner. It works once.")
                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            } else if order.status == .delivered {
                Text("Delivered. The delivery fee stayed a simulation.")
            } else if order.status == .requested && role == "customer" {
                Text("Waiting for the driver. Don't order from the restaurant yet.")
            } else {
                Text(order.status.label)
            }
            if order.quoteState == "customer_approval", role == "customer", let cents = order.counterCents {
                Text("The runner offered \(Fees.money(Double(cents) / 100)).")
                    .font(Theme.text(.body, weight: .semibold))
                if let reason = order.counterReason { Text(reason).font(Theme.text(.caption)).foregroundStyle(Theme.muted) }
                Button("Approve price") { Task { await decide("accept") } }.fontWeight(.bold)
                Button("Keep earlier terms") { Task { await decide("decline") } }
            }
            if (role == "customer" && order.status.customerCanCancel) || (role == "driver" && order.status.driverCanCancel) {
                Button("Cancel delivery") { confirmCancel = true }
                    .foregroundStyle(Theme.bad)
                    .padding(.top, 6)
            }
            if role == "customer", order.status == .pickedUp || order.status == .onTheWay || order.status == .arriving || order.status == .delivered {
                Button("Get help") { helpOpen = true }
                    .font(Theme.text(.body, weight: .semibold))
            }
        }
        .confirmationDialog("Cancel this delivery?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel delivery", role: .destructive) { Task { await setStatus(order, .cancelled) } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text(cancelCopy(order, role: role))
        }
        .sheet(isPresented: $helpOpen) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tell support what happened. This stays in the demo.").font(Theme.section())
                    TextField("What happened", text: $helpDetails, axis: .vertical).padding(12).sketchPanel()
                    PrimaryButton(title: "Open a case") { Task { await openHelp(order) } }
                    Spacer()
                }
                .padding(20)
                .homeRunPage(road: false)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { helpOpen = false } } }
            }
            .presentationDetents([.medium])
        }
    }

    private func cancelCopy(_ order: Order, role: String) -> String {
        switch order.status {
        case .requested: return "The simulated authorization is released. Nothing was captured."
        case .accepted, .restaurantConfirmed: return "The full simulated delivery fee is refunded. There is no penalty."
        case .pickedUp, .onTheWay, .arriving: return "After pickup, cancellation goes through support."
        default: return "This stops the delivery."
        }
    }

    private func decide(_ decision: String) async {
        guard let order else { return }
        do {
            let _: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: CounterDecision(counterDecision: decision))
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func openHelp(_ order: Order) async {
        let details = helpDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !details.isEmpty else { return }
        do {
            let _: SupportCase = try await model.client().store("support", method: "POST", body: SupportDraft(orderId: order.id, category: "delivery", details: details))
            helpOpen = false
        } catch { self.error = error.localizedDescription }
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Messages").font(Theme.section())
            if messages.isEmpty {
                Text("No messages yet.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
            ForEach(messages) { message in
                Text(message.body)
                    .font(Theme.text(.subheadline))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: message.senderId == model.user?.id ? .trailing : .leading)
            }
            TextField("Message", text: $messageText)
                .padding(12)
                .sketchPanel()
            Button("Send") { Task { await sendMessage() } }
                .font(Theme.text(.body, weight: .semibold))
        }
        .padding(16)
        .sketchPanel()
    }

    private func timeline(_ order: Order) -> some View {
        let steps: [(String, String?)] = [
            ("Requested", order.createdAt),
            ("Driver accepted", order.acceptedAt),
            ("Restaurant order confirmed", order.restaurantOrderConfirmedAt),
            ("Picked up", order.pickedUpAt),
            ("On the way", order.onTheWayAt),
            ("Arriving", order.status == .arriving || order.status == .delivered ? (order.deliveredAt ?? order.onTheWayAt) : nil),
            ("Delivered", order.deliveredAt),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("Progress").font(Theme.section())
            ForEach(steps, id: \.0) { step in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: step.1 == nil ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(step.1 == nil ? Theme.muted : Theme.good)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.0)
                        Text(step.1.map(Format.dayTime) ?? "Not yet").font(Theme.text(.subheadline)).foregroundStyle(Theme.muted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .sketchPanel()
    }

    private func facts(_ order: Order, role: String) -> some View {
        Card {
            Text("Restaurant").font(Theme.text(.headline, weight: .semibold))
            Text(order.restaurantAddress ?? "")
            if let website = restaurantURL(order.restaurantWebsite) {
                Link("Restaurant website", destination: website).fontWeight(.bold)
            }
            Text("Handoff").font(Theme.text(.headline, weight: .semibold)).padding(.top, 6)
            Text(order.destinationLabel)
            if let directions = URL(string: "https://maps.apple.com/?daddr=\(order.destinationLat),\(order.destinationLng)") {
                Link("Meetup directions", destination: directions).fontWeight(.bold)
            }
            if let arrival = order.estimatedArrivalAt {
                Text("Estimated around \(Format.time(arrival))").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
            Text("Fee").font(Theme.text(.headline, weight: .semibold)).padding(.top, 6)
            Text(order.quoteState == "expired" ? "Quote expired. Submit a new request." : (order.quoteState == "review" || order.deliveryFee == nil ? "Price needs review" : Fees.money(order.deliveryFee))).font(Theme.price()).foregroundStyle(Theme.maroon)
            if let lines = order.lines, !lines.isEmpty {
                ForEach(lines) { line in
                    Text("\(line.quantity)× \(line.name)\(line.weightPounds.map { " · \(Int($0)) lb" } ?? "")")
                        .font(Theme.text(.subheadline))
                }
            } else if let summary = order.itemSummary { Text(summary) }
            Text("Demo fee. No real charge.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            if role == "driver", let share = order.runnerShareCents {
                Text("Your simulated share \(Fees.money(Double(share) / 100))").font(Theme.text(.caption))
            }
            if role == "customer", let handle = order.driver?.paymentHandle {
                Text("Send to \(handle)").font(Theme.text(.caption))
            }
            if order.status == .delivered, role == "customer" {
                Button("Order again") {
                    model.stageRepeat(order.lines ?? [])
                }
                .font(Theme.text(.body, weight: .semibold))
            }
            Text("Home Run doesn't process or verify payments.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            Button("View receipt") { Task { await loadReceipt(order) } }
                .font(Theme.text(.body, weight: .semibold))
        }
    }

    private func loadReceipt(_ order: Order) async {
        let list: LedgerList = (try? await model.client().store("ledger", query: ["order": order.id])) ?? LedgerList(entries: [])
        receipt = list.entries
        showReceipt = true
    }

    private func load() async {
        do {
            let envelope: OrderEnvelope = try await model.client().store("orders", query: ["id": id])
            order = envelope.order
            if envelope.order == nil { error = "Order not found." }
            else if routePath == nil, let order = envelope.order {
                await loadRoute(order)
                await loadMessages()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadRoute(_ order: Order) async {
        guard let trip = order.trip else { return }
        do {
            let result = try await Routing.estimate(
                client: try model.client(),
                origin: LatLng(lat: trip.originLat, lng: trip.originLng),
                destination: LatLng(lat: trip.destinationLat, lng: trip.destinationLng),
                stops: (trip.stops ?? []).map { LatLng(lat: $0.lat, lng: $0.lng) },
                restaurant: LatLng(lat: order.restaurantLat, lng: order.restaurantLng),
                dropoff: LatLng(lat: order.destinationLat, lng: order.destinationLng)
            )
            routePath = result.0.withPath
            routeSource = result.0.source
        } catch {
            routePath = nil
            routeSource = nil
        }
    }

    private func loadMessages() async {
        guard let list: MessageList = try? await model.client().store("messages", query: ["order": id]) else { return }
        messages = list.messages
    }

    private func sendMessage() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let list: MessageList = try await model.client().store("messages", method: "POST", query: [:], body: MessageDraft(orderId: id, body: text))
            messages = list.messages
            messageText = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func complete(_ order: Order) async {
        busy = true
        defer { busy = false }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: DeliveryPatch(status: OrderStatus.delivered.rawValue, pin: pinEntry))
            self.order = updated
            pinEntry = ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func setStatus(_ order: Order, _ status: OrderStatus) async {
        busy = true
        defer { busy = false }
        do {
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: StatusPatch(status: status.rawValue))
            Haptics.success()
            self.order = updated
            error = nil
            await model.refreshBadges()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func confirm(_ order: Order) async {
        if !ordered { error = "Place your order with the restaurant first, then check the box."; return }
        if pickupName.trimmingCharacters(in: .whitespaces).isEmpty { error = "Add the name the order is under."; return }
        busy = true
        defer { busy = false }
        do {
            let patch = PickupPatch(
                pickupName: pickupName.trimmingCharacters(in: .whitespaces),
                restaurantOrderNumber: orderNumber.trimmingCharacters(in: .whitespaces).isEmpty ? nil : orderNumber,
                pickupReadyAt: ISO8601DateFormatter().string(from: ready),
                pickupInstructions: instructions.trimmingCharacters(in: .whitespaces).isEmpty ? nil : instructions,
                status: order.status == .restaurantConfirmed ? nil : OrderStatus.restaurantConfirmed.rawValue
            )
            let updated: Order = try await model.client().store("orders", method: "PATCH", query: ["id": order.id], body: patch)
            Haptics.success()
            self.order = updated
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RouteMap: View {
    var path: [[Double]]
    var body: some View {
        Group {
            if GoogleMapsStartup.isReady {
                GoogleRouteMap(path: path)
            } else {
                appleMap
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map of the delivery route")
    }

    private var appleMap: some View {
        Map {
            let coordinates = path.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count == 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
            }
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates).stroke(Theme.maroon, lineWidth: 4)
            }
            ForEach(Array(coordinates.enumerated()), id: \.offset) { item in
                Marker("", coordinate: item.element)
            }
        }
    }
}

private extension OrderDetailView {
    var routeCaption: String {
        guard routePath != nil else {
            return "Straight line between the posted stops. A driving route wasn't available, and this is not live tracking."
        }
        if GoogleMapsStartup.isReady {
            if routeSource == "google" {
                return "Driving route. Google Maps provides this map. This is not live tracking."
            }
            return "Google Maps provides this map. The road measurement is a separate estimate, and this is not live tracking."
        }
        return "Driving route. Apple Maps provides this map. This is not live tracking."
    }
}
