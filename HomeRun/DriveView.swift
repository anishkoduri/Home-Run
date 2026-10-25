import SwiftUI

struct DriveView: View {
    @Environment(AppModel.self) private var model
    @Binding var section: Section
    @State private var trips: [Trip] = []
    @State private var orders: [Order] = []
    @State private var error: String?
    @State private var busy = false
    @State private var tripPendingCancel: Trip?

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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bring food").font(Theme.text(.subheadline, weight: .bold)).foregroundStyle(.white.opacity(0.72))
                        Text(section.rawValue).font(Theme.display(.title)).foregroundStyle(Theme.cream)
                    }
                    Spacer(minLength: 8)
                    NavigationLink("Post") { PostTripView() }
                        .font(Theme.text(.headline, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                if let error { ErrorBanner(message: error).padding(.horizontal, 20) }
                List {
                    switch section {
                    case .requests:
                        let incoming = orders.filter { $0.status == .requested }
                        if incoming.isEmpty { roadEmpty("No new requests.") }
                        ForEach(incoming) { order in requestRow(order) }
                    case .deliveries:
                        let active = orders.filter { $0.status.isActiveDelivery }
                        if active.isEmpty { roadEmpty("No active deliveries.") }
                        ForEach(active) { order in deliveryRow(order) }
                    case .trips:
                        if trips.isEmpty { roadEmpty("No trips yet.") }
                        ForEach(trips) { trip in tripRow(trip) }
                    case .earnings:
                        let delivered = orders.filter { $0.status == .delivered }
                        let pending = orders.filter { $0.status.isActiveDelivery }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.roadMuted)
                            Text(Fees.money(pending.reduce(0) { $0 + ($1.deliveryFee ?? 0) })).font(Theme.display(.title2)).foregroundStyle(Theme.cream)
                            Text("Delivered").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.roadMuted)
                            Text(Fees.money(delivered.reduce(0) { $0 + ($1.deliveryFee ?? 0) })).font(Theme.display(.title2)).foregroundStyle(Theme.cream)
                            Text("Customers pay you directly. Home Run doesn't process payments.")
                                .font(Theme.text(.caption)).foregroundStyle(Theme.roadMuted)
                        }
                        .padding(16)
                        .sketchPanel(fill: Theme.roadSurface, ink: Theme.cream.opacity(0.35))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowSeparator(.hidden)
            }
            .homeRunPage(road: true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Theme.road, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: String.self) { OrderDetailView(id: $0) }
            .refreshable { await load() }
            .task { await watch { await load() } }
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
                .foregroundStyle(Theme.gold)
            HStack {
                NavigationLink("Details", value: order.id)
                Button("Decline") { Task { await set(order, .declined) } }.foregroundStyle(Theme.bad)
                Button("Accept") { Task { await set(order, .accepted) } }.fontWeight(.bold).disabled(busy)
            }
        }
        .padding(12)
        .sketchPanel(fill: Theme.roadSurface, ink: Theme.cream.opacity(0.35))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func deliveryRow(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink(value: order.id) {
                VStack(alignment: .leading) {
                    Text(order.restaurantName).fontWeight(.bold).foregroundStyle(Theme.cream)
                    Text("\(order.customer?.displayName ?? "") · \(order.destinationLabel)")
                        .font(Theme.text(.caption)).foregroundStyle(Theme.roadMuted)
                    if let name = order.pickupName {
                        Text("Pickup: \(name)\(order.restaurantOrderNumber.map { " · #\($0)" } ?? "")")
                            .font(Theme.text(.caption))
                    } else {
                        Text("Waiting for the customer's restaurant order.").font(Theme.text(.caption)).foregroundStyle(Theme.coral)
                    }
                }
            }
            if let next = order.status.driverNext {
                Button(next.1) { Task { await set(order, next.0) } }.fontWeight(.bold).disabled(busy)
            }
        }
        .padding(12)
        .sketchPanel(fill: Theme.roadSurface, ink: Theme.cream.opacity(0.35))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func tripRow(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CityRoute(origin: trip.originCity, destination: trip.destinationCity, tint: .white)
            Text("\(Format.relative(trip.departureAt)) · \(trip.activeOrders ?? 0) of \(trip.maxOrders) spots")
                .font(Theme.text(.caption)).foregroundStyle(Theme.roadMuted)
            Text(trip.status.capitalized).font(Theme.text(.caption))
            if trip.status == "scheduled" {
                Button("Cancel trip") { tripPendingCancel = trip }.foregroundStyle(Theme.bad)
            }
        }
        .padding(12)
        .sketchPanel(fill: Theme.roadSurface, ink: Theme.cream.opacity(0.35))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func roadEmpty(_ title: String) -> some View {
        HStack(spacing: 12) {
            GroceryBagSketch(ink: Theme.cream.opacity(0.9))
            Text(title).foregroundStyle(Theme.roadMuted)
        }
        .listRowBackground(Color.clear)
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
