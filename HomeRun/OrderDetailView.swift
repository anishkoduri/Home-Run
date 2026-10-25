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
        .background(Theme.cream)
        .navigationTitle(order?.restaurantName ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .task { await watch { await load() } }
    }

    @ViewBuilder
    private func content(_ order: Order) -> some View {
        let role = order.driverId == model.user?.id ? "driver" : "customer"
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    Text(role == "driver" ? "Delivery for \(order.customer?.displayName ?? "customer")" : "Order \(Format.shortId(order.id))")
                        .font(.caption).foregroundStyle(Theme.muted)
                    Text(order.restaurantName).font(.title2.weight(.bold)).foregroundStyle(Theme.maroon)
                    Text("\(order.trip?.originCity ?? "") → \(order.destinationLabel)").foregroundStyle(Theme.muted)
                }
                Spacer()
                StatusPill(status: order.status)
            }
            if let error { ErrorBanner(message: error) }
            actions(order, role: role)
            timeline(order)
            facts(order, role: role)
            if let trip = order.trip {
                RouteMap(path: routePath ?? [
                    [trip.originLat, trip.originLng],
                    [order.restaurantLat, order.restaurantLng],
                    [order.destinationLat, order.destinationLng],
                    [trip.destinationLat, trip.destinationLng],
                ])
                Text(routePath == nil
                     ? "Straight line between the posted stops. A road route was not available, and this is not live tracking."
                     : "Road route from the routing service. This map is not live tracking.")
                    .font(.caption)
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
                TextField("Name on the order", text: $pickupName).textFieldStyle(.roundedBorder)
                TextField("Order number (optional)", text: $orderNumber).textFieldStyle(.roundedBorder)
                DatePicker("Ready", selection: $ready)
                TextField("Pickup instructions", text: $instructions, axis: .vertical).textFieldStyle(.roundedBorder)
                PrimaryButton(title: order.status == .restaurantConfirmed ? "Save pickup details" : "Confirm restaurant order", busy: busy) {
                    Task { await confirm(order) }
                }
            } else if order.status == .delivered {
                Text("Delivered. Pay the driver \(Fees.money(order.deliveryFee)) outside Home Run.")
            } else if order.status == .requested && role == "customer" {
                Text("Waiting for the driver. Don't order from the restaurant yet.")
            } else {
                Text(order.status.label)
            }
            if (role == "customer" && order.status.customerCanCancel) || (role == "driver" && order.status.driverCanCancel) {
                Button("Cancel delivery") { confirmCancel = true }
                    .foregroundStyle(Theme.bad)
                    .padding(.top, 6)
            }
        }
        .confirmationDialog("Cancel this delivery?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel delivery", role: .destructive) { Task { await setStatus(order, .cancelled) } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text(role == "customer" && order.status == .requested ? "The driver has not accepted yet." : "This stops the delivery.")
        }
    }

    private func timeline(_ order: Order) -> some View {
        let steps: [(String, String?)] = [
            ("Requested", order.createdAt),
            ("Driver accepted", order.acceptedAt),
            ("Restaurant order confirmed", order.restaurantOrderConfirmedAt),
            ("Picked up", order.pickedUpAt),
            ("On the way", order.onTheWayAt),
            ("Delivered", order.deliveredAt),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("Progress").font(.title3.weight(.bold))
            ForEach(steps, id: \.0) { step in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: step.1 == nil ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(step.1 == nil ? Theme.muted : Theme.good)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.0)
                        Text(step.1.map(Format.dayTime) ?? "Not yet").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Hairline()
        }
    }

    private func facts(_ order: Order, role: String) -> some View {
        Card {
            Text("Restaurant").font(.headline)
            Text(order.restaurantAddress ?? "")
            if let website = restaurantURL(order.restaurantWebsite) {
                Link("Restaurant website", destination: website).fontWeight(.bold)
            }
            Text("Handoff").font(.headline).padding(.top, 6)
            Text(order.destinationLabel)
            if let arrival = order.estimatedArrivalAt {
                Text("Estimated around \(Format.time(arrival))").font(.caption).foregroundStyle(Theme.muted)
            }
            Text("Fee").font(.headline).padding(.top, 6)
            Text(Fees.money(order.deliveryFee)).font(.title3.weight(.bold)).foregroundStyle(Theme.maroon)
            Text(Fees.formula).font(.caption).foregroundStyle(Theme.muted)
            if role == "customer", let handle = order.driver?.paymentHandle {
                Text("Send to \(handle)").font(.caption)
            }
            Text("Home Run doesn't process or verify payments.").font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private func load() async {
        do {
            let envelope: OrderEnvelope = try await model.client().store("orders", query: ["id": id])
            order = envelope.order
            if envelope.order == nil { error = "Order not found." }
            else if routePath == nil, let order = envelope.order { await loadRoute(order) }
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
        } catch {
            routePath = nil
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
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map of the delivery route")
    }
}
