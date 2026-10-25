import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var city = Places.origins[0].name
    @State private var query = ""
    @State private var trips: [Trip] = []
    @State private var orders: [Order] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(Format.greeting()), \(Format.firstName(model.profile?.displayName))")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.coral)
                    Text("What should someone bring back?")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.maroon)
                    Text("Find a student already driving to College Station and add your restaurant pickup to their trip.")
                        .foregroundStyle(Theme.muted)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Restaurant city").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                        Picker("City", selection: $city) {
                            ForEach(Places.origins) { Text($0.name).tag($0.name) }
                        }
                        .pickerStyle(.menu)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        TextField("e.g. Whataburger", text: $query)
                            .padding(12)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        NavigationLink {
                            DiscoverView(initialCity: city, initialQuery: query)
                        } label: {
                            Text("Find drivers")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(Theme.maroon)
                                .background(Theme.gold)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                        }
                    }
                    .padding(16)
                    .background(Theme.maroon)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if let error { ErrorBanner(message: error) }

                    let active = orders.filter { !$0.status.isTerminal }.prefix(3)
                    if !active.isEmpty {
                        Text("Your active orders").font(.title3.weight(.bold))
                        ForEach(active) { order in
                            NavigationLink(value: order.id) {
                                Card {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(order.restaurantName).fontWeight(.bold).foregroundStyle(Theme.ink)
                                            Text(Format.relative(order.trip?.departureAt ?? order.createdAt))
                                                .font(.caption).foregroundStyle(Theme.muted)
                                        }
                                        Spacer()
                                        StatusPill(status: order.status)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Upcoming trips").font(.title3.weight(.bold))
                    if trips.isEmpty {
                        Text("When students post drives to College Station, they'll show up here.")
                            .foregroundStyle(Theme.muted)
                    } else {
                        ForEach(trips) { trip in TripSummary(trip: trip) }
                    }
                }
                .padding(20)
            }
            .background(Theme.cream)
            .navigationTitle("Howdy Haul")
            .navigationDestination(for: String.self) { OrderDetailView(id: $0) }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            let client = try model.client()
            trips = try await client.store("trips", query: ["limit": "6"])
            orders = try await client.store("orders", query: ["role": "customer"])
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct TripSummary: View {
    var trip: Trip
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(trip.originCity) → \(trip.destinationCity)").font(.headline).foregroundStyle(Theme.maroon)
                Text(Format.relative(trip.departureAt)).font(.subheadline).foregroundStyle(Theme.muted)
                Text("\(trip.activeOrders ?? 0) of \(trip.maxOrders) spots taken")
                    .font(.caption).foregroundStyle(Theme.muted)
                if let name = trip.driver?.displayName {
                    Text(name).font(.caption.weight(.semibold))
                }
            }
        }
    }
}
