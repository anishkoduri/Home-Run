import SwiftUI

struct OrdersView: View {
    @Environment(AppModel.self) private var model
    @State private var orders: [Order] = []
    @State private var past = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Orders", selection: $past) {
                    Text("Active").tag(false)
                    Text("Past").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                if let error { ErrorBanner(message: error).padding(.horizontal, 20) }
                List(shown) { order in
                    NavigationLink(value: order.id) {
                        HStack(spacing: 12) {
                            PlacePlate(name: order.restaurantName)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.restaurantName).font(.headline)
                                if let trip = order.trip {
                                    Text("\(trip.originCity) → \(order.destinationLabel)")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.muted)
                                }
                                Text("\(Format.shortId(order.id)) · \(Fees.money(order.deliveryFee))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                StatusPill(status: order.status)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .background(Theme.cream)
            .navigationTitle("Orders")
            .navigationDestination(for: String.self) { OrderDetailView(id: $0) }
            .refreshable { await load() }
            .task { await watch { await load() } }
        }
    }

    private var shown: [Order] { orders.filter { past ? $0.status.isTerminal : !$0.status.isTerminal } }

    private func load() async {
        do {
            orders = try await model.client().store("orders", query: ["role": "customer"])
            error = nil
            await model.refreshBadges()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
