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
    @State private var showCities = false

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
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Theme.maroon, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: String.self) { OrderDetailView(id: $0) }
            .refreshable { await load() }
            .task { await watch { await load() } }
            .onAppear {
                if model.pickupCityConfirmed { city = model.pickupCity }
                else { showCities = true }
            }
            .sheet(isPresented: $showCities) {
                PickupCitySheet { name in
                    city = name
                    model.confirmPickupCity(name)
                }
            }
            .sensoryFeedback(.selection, trigger: expandedTripID)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text("Home Run")
                    .font(Theme.brand(.largeTitle))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                NavigationLink {
                    InboxView()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                        if model.noticeBadge > 0 {
                            Text("\(model.noticeBadge)")
                                .font(Theme.text(.caption2, weight: .bold))
                                .foregroundStyle(Theme.maroon)
                                .padding(4)
                                .background(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .accessibilityLabel(model.noticeBadge > 0 ? "Notifications, \(model.noticeBadge) unread" : "Notifications")
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: typeSize.isAccessibilitySize ? 64 : 78, height: typeSize.isAccessibilitySize ? 64 : 78)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.maroon)

            VStack(alignment: .leading, spacing: 10) {
                Text("Food runs to College Station.")
                    .font(Theme.text(.subheadline))
                    .foregroundStyle(.white.opacity(0.9))
                photoBand
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Theme.maroon.overlay(PaperFiber(tone: .white))
            }
        }
        .background(Theme.maroon.ignoresSafeArea(edges: .top))
    }

    private var photoBand: some View {
        Group {
            if UIImage(named: "FoodPlate") != nil {
                Image("FoodPlate")
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.maroonDark
                    GroceryBagSketch()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: typeSize.isAccessibilitySize ? 72 : 88)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.7), lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var pickupTitle: some View {
        Text("Find a pickup")
            .font(Theme.section(.title3))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private var pickupBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            pickupTitle
            PickupCityButton(city: city) { showCities = true }
            Text("Delivering to College Station.")
                .font(Theme.text(.caption))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                TextField("Restaurant or store", text: $query, prompt: Text("Restaurant or store").foregroundStyle(Theme.muted))
                    .focused($searchFocused)
                    .font(Theme.text(.body))
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .frame(minHeight: 48)
                NavigationLink {
                    DiscoverView(initialCity: city, initialQuery: query, embedded: true)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(Theme.text(.body, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Theme.maroon)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Find a pickup")
                .accessibilityHint("Opens restaurant search for \(city)")
            }
        }
        .padding(16)
        .background(Theme.surface)
        .sketchPanel()
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var activeOrders: some View {
        let active = orders.filter { !$0.status.isTerminal }.prefix(3)
        if !active.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("In motion")
                    .font(Theme.section())
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 8)
                ForEach(active) { order in
                    NavigationLink(value: order.id) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.restaurantName)
                                    .font(Theme.text(.headline, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                Text(order.trip.map { "\($0.originCity) → \(order.destinationLabel)" } ?? order.destinationLabel)
                                    .font(Theme.text(.subheadline))
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
            Text("Trips to College Station")
                .font(Theme.section())
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
        HStack(alignment: .center, spacing: 12) {
            GroceryBagSketch()
            VStack(alignment: .leading, spacing: 2) {
            Text("No trips yet.")
                .font(Theme.section(.headline))
                .foregroundStyle(Theme.ink)
            Text("Driving back? Post a trip.")
                .font(Theme.text(.subheadline))
                .foregroundStyle(Theme.muted)
            if model.profile?.use != .order {
                Button("Bring food") { model.side = .driving }
                    .font(Theme.text(.body, weight: .semibold))
                    .frame(minHeight: 44)
            }
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
    @Environment(AppModel.self) private var model
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
                        .font(Theme.text(.subheadline))
                        .foregroundStyle(Theme.muted)
                    HStack {
                        Text(spots)
                            .font(Theme.text(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(Theme.text(.caption, weight: .bold))
                            .foregroundStyle(Theme.muted)
                            .accessibilityHidden(true)
                    }
                    if trip.driverId == model.user?.id {
                        Text("Your trip.")
                            .font(Theme.text(.caption, weight: .bold))
                            .foregroundStyle(Theme.maroon)
                    }
                    if let name = Format.personalName(trip.driver?.displayName) {
                        Text(name)
                            .font(Theme.text(.subheadline))
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
        }
        .padding(.horizontal, 16)
        .ticketPanel(open: expanded)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.14), value: expanded)
    }

    private var spots: String {
        let taken = trip.activeOrders ?? 0
        let open = max(0, trip.maxOrders - taken)
        if open == 0 { return "No spots left · \(taken) of \(trip.maxOrders)" }
        return "\(open) of \(trip.maxOrders) spots open"
    }
}

private struct TripRouteDetail: View {
    @Environment(AppModel.self) private var model
    var trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RouteSketch(origin: trip.originCity, destination: trip.destinationCity)
            if let stops = trip.stops, !stops.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stops they already planned")
                        .font(Theme.text(.subheadline, weight: .bold))
                    ForEach(stops, id: \.stopOrder) { stop in
                        Text(stop.restaurantName)
                            .font(Theme.text(.subheadline))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            if let notes = trip.notes, !notes.isEmpty {
                Text(notes)
                    .font(Theme.text(.subheadline))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink {
                DiscoverView(initialCity: trip.originCity, initialQuery: "", focusTripID: trip.id, embedded: true)
            } label: {
                Text(trip.driverId == model.user?.id ? "Your trip" : "Find a pickup on this trip")
                    .font(Theme.text(.headline, weight: .semibold))
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
