import SwiftUI

struct OrdersView: View {
    @Environment(AppModel.self) private var model
    @State private var orders: [Order] = []
    @State private var past = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Orders", detail: past ? "Finished deliveries." : "Deliveries still in progress.")
                ChoiceBar(options: [false, true], label: { $0 ? "Past" : "Active" }, selection: $past)
                    .padding(.horizontal, 20)
                if let error { ErrorBanner(message: error).padding(.horizontal, 20) }
                if shown.isEmpty {
                    EmptyState(
                        title: past ? "No past orders." : "No active orders.",
                        message: past ? "Finished orders show up here." : "Request a pickup from Home."
                    )
                    .padding(.horizontal, 20)
                    Spacer(minLength: 0)
                } else {
                List(shown) { order in
                    NavigationLink(value: order.id) {
                        HStack(spacing: 12) {
                            PlacePlate(name: order.restaurantName)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.restaurantName).font(Theme.text(.headline, weight: .semibold))
                                if let trip = order.trip {
                                    Text("\(trip.originCity) → \(order.destinationLabel)")
                                        .font(Theme.text(.subheadline))
                                        .foregroundStyle(Theme.muted)
                                }
                                if let summary = order.itemSummary {
                                    Text(summary)
                                        .font(Theme.text(.subheadline))
                                        .foregroundStyle(Theme.muted)
                                }
                                Text("\(Format.shortId(order.id)) · \(Fees.money(order.deliveryFee))")
                                    .font(Theme.text(.subheadline, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                StatusPill(status: order.status)
                            }
                        }
                        .padding(12)
                        .sketchPanel()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .scrollContentBackground(.hidden)
                .listRowSeparator(.hidden)
                }
            }
            .homeRunPage(road: false)
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Theme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
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
