import SwiftUI

struct DriveView: View {
    @Environment(AppModel.self) private var model
    @State private var section = Section.requests
    @State private var trips: [Trip] = []
    @State private var orders: [Order] = []
    @State private var error: String?
    @State private var busy = false

    enum Section: String, CaseIterable, Identifiable {
        case requests = "Requests"
        case deliveries = "Deliveries"
        case trips = "My trips"
        case earnings = "Earnings"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                if let error { ErrorBanner(message: error).padding(.horizontal, 20) }
                List {
                    switch section {
                    case .requests:
                        let incoming = orders.filter { $0.status == .requested }
                        if incoming.isEmpty { Text("No new requests.").foregroundStyle(Theme.muted) }
                        ForEach(incoming) { order in requestRow(order) }
                    case .deliveries:
                        let active = orders.filter { $0.status.isActiveDelivery }
                        if active.isEmpty { Text("No active deliveries.").foregroundStyle(Theme.muted) }
                        ForEach(active) { order in deliveryRow(order) }
                    case .trips:
                        if trips.isEmpty { Text("No trips yet.").foregroundStyle(Theme.muted) }
                        ForEach(trips) { trip in tripRow(trip) }
                    case .earnings:
                        let delivered = orders.filter { $0.status == .delivered }
                        let pending = orders.filter { $0.status.isActiveDelivery }
                        Text("Active \(Fees.money(pending.reduce(0) { $0 + ($1.deliveryFee ?? 0) }))")
                        Text("Delivered \(Fees.money(delivered.reduce(0) { $0 + ($1.deliveryFee ?? 0) }))")
                        Text("Customers pay you directly. Home Run doesn't process payments.")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(Theme.cream)
            .navigationTitle("Bring Food")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Post") { PostTripView() }
                }
            }
            .navigationDestination(for: String.self) { OrderDetailView(id: $0) }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func requestRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(order.customer?.displayName ?? "Customer").fontWeight(.bold)
            Text(order.restaurantName)
            Text("\(Format.minutes(order.detourMinutes)) · \(Fees.money(order.deliveryFee))")
                .foregroundStyle(Theme.maroon)
            HStack {
                NavigationLink("Details", value: order.id)
                Button("Decline") { Task { await set(order, .declined) } }.foregroundStyle(Theme.bad)
                Button("Accept") { Task { await set(order, .accepted) } }.fontWeight(.bold).disabled(busy)
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func deliveryRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink(value: order.id) {
                VStack(alignment: .leading) {
                    Text(order.restaurantName).fontWeight(.bold).foregroundStyle(Theme.ink)
                    Text("\(order.customer?.displayName ?? "") · \(order.destinationLabel)")
                        .font(.caption).foregroundStyle(Theme.muted)
                    if let name = order.pickupName {
                        Text("Pickup: \(name)\(order.restaurantOrderNumber.map { " · #\($0)" } ?? "")")
                            .font(.caption)
                    } else {
                        Text("Waiting for the customer's restaurant order.").font(.caption).foregroundStyle(Theme.coral)
                    }
                }
            }
            if let next = order.status.driverNext {
                Button(next.1) { Task { await set(order, next.0) } }.fontWeight(.bold).disabled(busy)
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func tripRow(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(trip.originCity) → \(trip.destinationCity)").font(.headline)
            Text("\(Format.relative(trip.departureAt)) · \(trip.activeOrders ?? 0) of \(trip.maxOrders) spots")
                .font(.caption).foregroundStyle(Theme.muted)
            Text(trip.status.capitalized).font(.caption)
            if trip.status == "scheduled" {
                Button("Cancel trip") { Task { await cancel(trip) } }.foregroundStyle(Theme.bad)
            }
        }
        .listRowBackground(Theme.surface)
    }

    private func load() async {
        do {
            let client = try model.client()
            trips = try await client.store("trips", query: ["mine": "1"])
            orders = try await client.store("orders", query: ["role": "driver"])
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
