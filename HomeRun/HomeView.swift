import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var searchFocused: Bool
    @State private var city = Places.origins[0].name
    @State private var query = ""
    @State private var trips: [Trip] = []
    @State private var orders: [Order] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var expandedTripID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    pickupBar
                    VStack(alignment: .leading, spacing: 28) {
                        if let error { ErrorBanner(message: error) }
                        activeOrders
                        upcoming
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.cream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.maroon, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: String.self) { OrderDetailView(id: $0) }
            .refreshable { await load() }
            .task { await watch { await load() } }
            .sensoryFeedback(.selection, trigger: expandedTripID)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("Home Run")
                    .font(Theme.display(.headline))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Image("BrandMark")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
            }
            if typeSize.isAccessibilitySize {
                headline
            } else {
                HStack(alignment: .center, spacing: 12) {
                    headline
                    FoodPlate()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Theme.maroon
                .overlay(PaperFiber())
                .ignoresSafeArea(edges: .top)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bring something home.")
                .font(Theme.display(.title2))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Food runs to College Station.")
                .font(Theme.text(.subheadline))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var pickupTitle: some View {
        Text("Find a pickup")
            .font(Theme.display(.headline))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private var cityMenu: some View {
        Menu {
            ForEach(Places.origins) { origin in
                Button(origin.name) { city = origin.name }
            }
        } label: {
            Text(city)
                .font(Theme.text(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.maroon)
                .lineLimit(1)
        }
        .accessibilityLabel("Restaurant city, \(city)")
    }

    private var pickupBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    pickupTitle
                    Spacer(minLength: 12)
                    cityMenu
                }
                VStack(alignment: .leading, spacing: 4) {
                    pickupTitle
                    cityMenu
                }
            }
            HStack(spacing: 8) {
                TextField("Restaurant or store", text: $query, prompt: Text("Restaurant or store").foregroundStyle(Theme.muted))
                    .focused($searchFocused)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .frame(minHeight: 44)
                NavigationLink {
                    DiscoverView(initialCity: city, initialQuery: query, embedded: true)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.maroon)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Find a pickup")
                .accessibilityHint("Opens restaurant search for \(city)")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .overlay(alignment: .bottom) { Hairline() }
    }

    @ViewBuilder
    private var activeOrders: some View {
        let active = orders.filter { !$0.status.isTerminal }.prefix(3)
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("In motion")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 8)
                ForEach(active) { order in
                    NavigationLink(value: order.id) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.restaurantName)
                                    .font(.headline)
                                    .foregroundStyle(Theme.ink)
                                Text(order.trip.map { "\($0.originCity) → \(order.destinationLabel)" } ?? order.destinationLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 8)
                            StatusPill(status: order.status)
                        }
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this order")
                    Hairline()
                }
            }
        }
    }

    @ViewBuilder
    private var upcoming: some View {
        VStack(alignment: .leading, spacing: 14) {
            StitchMark(tint: Theme.maroon.opacity(0.4))
            Text("Heading to College Station")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            if !loaded && error == nil {
                ProgressView("Loading trips")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if trips.isEmpty {
                emptyTrips
            } else {
                ForEach(trips) { trip in
                    TripLane(
                        trip: trip,
                        expanded: expandedTripID == trip.id,
                        reduceMotion: reduceMotion
                    ) {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.35)) {
                            expandedTripID = expandedTripID == trip.id ? nil : trip.id
                        }
                    }
                }
            }
        }
    }

    private var emptyTrips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No trips yet.")
                .font(Theme.display(.headline))
                .foregroundStyle(Theme.ink)
            Text("Driving back? Post your trip.")
                .font(Theme.text(.subheadline))
                .foregroundStyle(Theme.muted)
            if model.profile?.use != .order {
                Button("Bring food") { model.side = .driving }
                    .font(Theme.text(.body, weight: .semibold))
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func load() async {
        do {
            let client = try model.client()
            trips = try await client.store("trips", query: ["limit": "6"])
            orders = try await client.store("orders", query: ["role": "customer"])
            error = nil
            loaded = true
        } catch {
            self.error = error.localizedDescription
            loaded = true
        }
    }
}

private struct TripLane: View {
    var trip: Trip
    var expanded: Bool
    var reduceMotion: Bool
    var toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                VStack(alignment: .leading, spacing: 8) {
                    CityRoute(origin: trip.originCity, destination: trip.destinationCity)
                    Text(Format.relative(trip.departureAt))
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    HStack {
                        Text(spots)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                            .accessibilityHidden(true)
                    }
                    if let name = Format.personalName(trip.driver?.displayName) {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(trip.originCity) to \(trip.destinationCity), \(Format.relative(trip.departureAt)), \(spots)")
            .accessibilityHint(expanded ? "Hides the route" : "Shows the posted route")
            .accessibilityAddTraits(expanded ? .isSelected : [])

            if expanded {
                TripRouteDetail(trip: trip)
                    .padding(.bottom, 16)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
            Hairline()
        }
    }

    private var spots: String {
        let taken = trip.activeOrders ?? 0
        let open = max(0, trip.maxOrders - taken)
        if open == 0 { return "No spots left · \(taken) of \(trip.maxOrders)" }
        return "\(open) of \(trip.maxOrders) spots open"
    }
}

private struct TripRouteDetail: View {
    var trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RouteSketch(origin: trip.originCity, destination: trip.destinationCity)
            if let stops = trip.stops, !stops.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stops they already planned")
                        .font(.subheadline.weight(.bold))
                    ForEach(stops, id: \.stopOrder) { stop in
                        Text(stop.restaurantName)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink {
                DiscoverView(initialCity: trip.originCity, initialQuery: "", focusTripID: trip.id, embedded: true)
            } label: {
                Text("Find a pickup on this trip")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.maroon)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous))
            }
            .buttonStyle(PressStyle())
            .disabled((trip.activeOrders ?? 0) >= trip.maxOrders)
        }
    }
}
