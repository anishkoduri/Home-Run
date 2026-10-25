import SwiftUI

struct OrdersView: View {
    @Environment(AppModel.self) private var model
    @State private var orders: [Order] = []
    @State private var favorites: [SavedPlace] = []
    @State private var lane = Lane.active
    @State private var error: String?

    enum Lane: String, CaseIterable, Identifiable {
        case active = "Active"
        case past = "Past"
        case faves = "My Faves"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Orders")
                ChoiceBar(options: Lane.allCases, label: { $0.rawValue }, selection: $lane)
                    .padding(.horizontal, 20)
                if let error { ErrorBanner(message: error).padding(.horizontal, 20) }
                if lane == .faves {
                    favoritesList
                } else if shown.isEmpty {
                    EmptyState(title: emptyTitle, message: emptyMessage)
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
                                Text(order.progressTitle)
                                    .font(Theme.text(.caption, weight: .semibold))
                                    .foregroundStyle(Theme.maroon)
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .navigationDestination(for: String.self) { OrderDetailView(id: $0) }
            .navigationDestination(for: SavedPlace.self) { FavoritePlaceView(place: $0) }
            .refreshable { await load() }
            .task { await watch { await load() } }
        }
    }

    private var shown: [Order] {
        orders.filter { lane == .past ? $0.status.isTerminal : !$0.status.isTerminal }
    }

    private var emptyTitle: String { lane == .past ? "No past orders." : "No active orders." }
    private var emptyMessage: String { lane == .past ? "Finished orders show up here." : "Request a pickup from Home." }

    @ViewBuilder
    private var favoritesList: some View {
        if favorites.isEmpty {
            EmptyState(title: "No saved places.", message: "Bookmark a restaurant or store and it shows up here.")
                .padding(.horizontal, 20)
            Spacer(minLength: 0)
        } else {
            List(favorites) { place in
                NavigationLink(value: place) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name.isEmpty ? "Place unavailable" : place.name)
                            .font(Theme.text(.headline, weight: .semibold))
                        Text(place.address.isEmpty ? place.city : place.address)
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(12)
                    .sketchPanel()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func load() async {
        do {
            orders = try await model.client().store("orders", query: ["role": "customer"])
            let list: SavedPlaceList = try await model.client().store("saved-places")
            favorites = list.places
            error = nil
            await model.refreshBadges()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct FavoritePlaceView: View {
    @Environment(AppModel.self) private var model
    var place: SavedPlace

    private var missing: Bool { place.placeId.isEmpty || place.name.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if missing {
                EmptyState(title: "This place isn't available", message: "The saved record has no place to open. Search again from Discover.")
            } else {
                Text(place.name).font(Theme.section(.title2))
                Text(place.address).font(Theme.text(.body)).foregroundStyle(Theme.muted)
                Text(place.city).font(Theme.text(.subheadline, weight: .semibold))
                Button("Request a pickup") {
                    model.stagedFavorite = place
                    model.requestedCustomerTab = "discover"
                }
                .font(Theme.text(.headline, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.maroon))
            }
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .homeRunPage(road: false)
        .navigationTitle(missing ? "Saved place" : place.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
