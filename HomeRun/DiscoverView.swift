import SwiftUI

struct Handoff: Equatable {
    var type: String
    var label: String
    var lat: Double
    var lng: Double

    static var campusDefault: Handoff {
        let point = Places.meetups[0]
        return Handoff(type: "campus", label: point.label, lat: point.lat, lng: point.lng)
    }
}

struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    var initialCity: String = Places.origins[0].name
    var initialQuery: String = ""
    var focusTripID: String?
    var embedded = false

    @State private var city: String
    @State private var search: String
    @State private var places: [Place] = []
    @State private var source: String?
    @State private var restaurant: (place: Place, source: String)?
    @State private var handoffMode = "campus"
    @State private var addressQuery = ""
    @State private var addressResults: [Place] = []
    @State private var handoff = Handoff.campusDefault
    @State private var trips: [Trip] = []
    @State private var estimates: [String: DetourEstimate] = [:]
    @State private var searching = false
    @State private var error: String?
    @State private var request: RequestDraft?

    init(initialCity: String = Places.origins[0].name, initialQuery: String = "", focusTripID: String? = nil, embedded: Bool = false) {
        self.initialCity = initialCity
        self.initialQuery = initialQuery
        self.focusTripID = focusTripID
        self.embedded = embedded
        _city = State(initialValue: initialCity)
        _search = State(initialValue: initialQuery)
    }

    private var estimateKey: String {
        let place = restaurant?.place.placeId ?? ""
        let tripIDs = trips.map(\.id).joined(separator: ",")
        return "\(place)|\(handoff.type)|\(handoff.lat)|\(handoff.lng)|\(tripIDs)"
    }

    var body: some View {
        if embedded {
            browser
        } else {
            NavigationStack { browser }
        }
    }

    private var browser: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose a place, then a trip.")
                        .font(Theme.text(.subheadline))
                        .foregroundStyle(Theme.muted)
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(Places.origins) { origin in
                                Button(origin.name) { city = origin.name }
                            }
                        } label: {
                            Text(city)
                                .font(Theme.text(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.maroon)
                                .lineLimit(1)
                                .frame(minHeight: 44)
                        }
                        .accessibilityLabel("Restaurant city, \(city)")
                        TextField("Restaurant or store", text: $search, prompt: Text("Restaurant or store").foregroundStyle(Theme.muted))
                            .textFieldStyle(.plain)
                            .submitLabel(.search)
                            .frame(minHeight: 44)
                            .onSubmit { Task { await searchPlaces() } }
                        Button("Search") {
                            Task { await searchPlaces() }
                        }
                        .fontWeight(.bold)
                        .frame(minHeight: 44)
                        .disabled(searching)
                        .sensoryFeedback(.selection, trigger: searching) { _, started in started }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .background(Theme.surface)
                    .clipShape(InkCard())
                    .overlay(InkCard().stroke(Theme.ink.opacity(0.28), lineWidth: 1.3))
                    if let error { ErrorBanner(message: error) }
                    if searching { ProgressView("Searching \(city)…") }
                    if restaurant == nil {
                        if !searching && places.isEmpty && error == nil {
                            EmptyState(title: "Search \(city)", message: "Places come from Google, or OpenStreetMap if Google has no key.")
                        }
                        ForEach(places) { place in
                            Button {
                                Haptics.tap()
                                restaurant = (place, source ?? "osm")
                            } label: {
                                HStack(spacing: 12) {
                                    PlacePlate(name: place.name)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(place.name).font(Theme.text(.headline, weight: .semibold)).foregroundStyle(Theme.ink)
                                        Text(place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                        if let rating = place.rating {
                                            Text("\(rating, format: .number.precision(.fractionLength(1))) · \(place.ratingCount ?? 0) ratings")
                                                .font(Theme.text(.caption, weight: .semibold))
                                                .foregroundStyle(Theme.maroon)
                                        }
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.muted).accessibilityHidden(true)
                                }
                                .padding(12)
                                .sketchPanel()
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityLabel("\(place.name), \(place.address)")
                        }
                    } else if let restaurant {
                        Card {
                            HStack(spacing: 12) {
                                PlacePlate(name: restaurant.place.name)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(restaurant.place.name).font(Theme.text(.headline, weight: .semibold))
                                    Text(restaurant.place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                }
                            }
                            if let website = restaurantURL(restaurant.place.website) {
                                Link("Restaurant website", destination: website)
                                    .fontWeight(.bold)
                            }
                            Button("Change") { self.restaurant = nil }.fontWeight(.bold)
                        }
                        Text("Handoff").font(Theme.display(.title3))
                        Picker("Handoff", selection: $handoffMode) {
                            Text("Campus").tag("campus")
                            Text("Address").tag("address")
                        }
                        .pickerStyle(.segmented)
                        if handoffMode == "campus" {
                            ForEach(Places.meetups) { point in
                                Button {
                                    handoff = Handoff(type: "campus", label: point.label, lat: point.lat, lng: point.lng)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(point.label).fontWeight(.semibold)
                                            Text(point.detail).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                        }
                                        Spacer()
                                        if handoff.type == "campus" && handoff.label == point.label {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.maroon)
                                        }
                                    }
                                    .padding(12)
                                    .sketchPanel(ink: handoff.type == "campus" && handoff.label == point.label ? Theme.maroon : Theme.ink.opacity(0.28))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(point.label)
                            }
                        } else {
                            TextField("Street address in College Station", text: $addressQuery)
                                .padding(12)
                                .frame(minHeight: 44)
                                .sketchPanel()
                            Button("Find address") { Task { await searchAddress() } }
                                .fontWeight(.bold)
                            if handoff.type == "address" {
                                Text("Delivering to \(handoff.label)").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                            }
                            ForEach(addressResults) { place in
                                Button {
                                    let label = [place.name, place.address].filter { !$0.isEmpty }.joined(separator: ", ")
                                    handoff = Handoff(type: "address", label: String(label.prefix(160)), lat: place.lat, lng: place.lng)
                                    addressResults = []
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(place.name).fontWeight(.semibold)
                                        Text(place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Drivers").font(Theme.display(.title3))
                        Text("Fee: \(Fees.formula).").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        if ranked.isEmpty {
                            EmptyState(title: "No trips from \(city)", message: "No one has posted a drive from here yet.")
                        }
                        ForEach(ranked, id: \.trip.id) { row in
                            VStack(alignment: .leading, spacing: 8) {
                                if row.trip.id == focusTripID {
                                    Text("Trip you opened")
                                        .font(Theme.text(.caption, weight: .bold))
                                        .foregroundStyle(Theme.maroon)
                                }
                                TripSummary(trip: row.trip)
                                if row.own {
                                    Text("This is your trip.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                } else if let estimate = row.estimate {
                                    Text("\(Format.minutes(estimate.detourMinutes)) added · \(Fees.money(Fees.estimate(estimate.detourMinutes)))")
                                        .font(Theme.text(.subheadline, weight: .bold)).foregroundStyle(Theme.maroon)
                                    if estimate.detourMinutes > 45 {
                                        Text("Long detour. The driver may decline.").font(Theme.text(.caption)).foregroundStyle(Theme.coral)
                                    }
                                    if estimate.source == "straight_line" {
                                        Text("Approximate · routing unavailable").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                    }
                                    Button("Request delivery") {
                                        request = RequestDraft(trip: row.trip, estimate: estimate, place: restaurant.place, source: restaurant.source, handoff: handoff)
                                    }
                                    .font(Theme.text(.headline, weight: .semibold))
                                    .frame(minHeight: 44)
                                    .disabled((row.trip.activeOrders ?? 0) >= row.trip.maxOrders)
                                } else {
                                    ProgressView("Calculating route…")
                                }
                            }
                            .padding(12)
                            .sketchPanel()
                        }
                    }
                }
                .padding(20)
            }
            .homeRunPage(road: false)
            .navigationTitle("Discover")
            .toolbar(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .task {
                let typed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !typed.isEmpty { await searchPlaces() }
            }
            .task(id: city) { await loadTrips() }
            .task(id: estimateKey) { await estimateAll() }
            .sheet(item: $request) { draft in
                RequestSheet(draft: draft) { request = nil }
            }
    }

    private struct Ranked { var trip: Trip; var estimate: DetourEstimate?; var own: Bool }

    private var ranked: [Ranked] {
        trips.map { trip in
            Ranked(trip: trip, estimate: estimates[trip.id], own: trip.driverId == model.user?.id)
        }
        .sorted { lhs, rhs in
            if lhs.trip.id == focusTripID { return true }
            if rhs.trip.id == focusTripID { return false }
            if lhs.own != rhs.own { return !lhs.own }
            return (lhs.estimate?.detourMinutes ?? 999) < (rhs.estimate?.detourMinutes ?? 999)
        }
    }

    private func searchPlaces() async {
        searching = true
        defer { searching = false }
        do {
            let response: PlaceSearchResponse = try await model.client().geo("places", query: ["city": city, "q": search])
            places = response.places
            source = response.source
            error = places.isEmpty ? "No restaurants found for \(search)." : nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadTrips() async {
        do {
            trips = try await model.client().store("trips", query: ["city": city])
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func searchAddress() async {
        let query = addressQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 3 else {
            error = "Enter a street address in College Station or Bryan."
            return
        }
        do {
            let response: PlaceSearchResponse = try await model.client().geo("geocode", query: ["city": "College Station", "q": query])
            addressResults = response.places
            error = response.places.isEmpty ? "We couldn't find that address. Try adding the street number." : nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func estimateAll() async {
        guard let restaurant, !restaurant.place.placeId.isEmpty else { return }
        estimates = [:]
        let client: APIClient
        do { client = try model.client() } catch {
            self.error = error.localizedDescription
            return
        }
        let candidates = trips.filter { $0.driverId != model.user?.id }
        for trip in candidates.prefix(12) {
            if Task.isCancelled { return }
            do {
                let result = try await Routing.estimate(
                    client: client,
                    origin: LatLng(lat: trip.originLat, lng: trip.originLng),
                    destination: LatLng(lat: trip.destinationLat, lng: trip.destinationLng),
                    stops: (trip.stops ?? []).map { LatLng(lat: $0.lat, lng: $0.lng) },
                    restaurant: LatLng(lat: restaurant.place.lat, lng: restaurant.place.lng),
                    dropoff: LatLng(lat: handoff.lat, lng: handoff.lng)
                )
                if Task.isCancelled { return }
                estimates[trip.id] = result.0
            } catch let error as APIError where error.code == "unauthenticated" {
                self.error = error.message
                return
            } catch {
                self.error = error.localizedDescription
                return
            }
        }
    }
}

struct RequestDraft: Identifiable {
    var trip: Trip
    var estimate: DetourEstimate
    var place: Place
    var source: String
    var handoff: Handoff
    var id: String { trip.id }
}

struct RequestSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var draft: RequestDraft
    var onDone: () -> Void
    @State private var note = ""
    @State private var busy = false
    @State private var error: String?
    @State private var confirmed: Order?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let confirmed {
                        Text("Request stored")
                            .font(Theme.display(.title))
                            .foregroundStyle(Theme.maroon)
                        Text(confirmed.restaurantName).font(Theme.display(.title3))
                        StatusPill(status: confirmed.status)
                        Text("This is the status Home Run saved. The driver has not accepted it yet, and no payment was taken.")
                            .font(Theme.text(.subheadline))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        PrimaryButton(title: "Done") { onDone(); dismiss() }
                    } else {
                        Text("Ask \(Format.firstName(draft.trip.driver?.displayName)) to grab \(draft.place.name)")
                            .font(Theme.display(.title2)).foregroundStyle(Theme.maroon)
                        CityRoute(origin: draft.trip.originCity, destination: draft.trip.destinationCity)
                        Text("Leaves \(Format.relative(draft.trip.departureAt))").foregroundStyle(Theme.muted)
                        Text("Handoff at \(draft.handoff.label)").foregroundStyle(Theme.muted)
                        Text("Added drive \(Format.minutes(draft.estimate.detourMinutes))")
                        Text("Delivery fee \(Fees.money(Fees.estimate(draft.estimate.detourMinutes)))").font(Theme.display(.title3))
                        if let website = restaurantURL(draft.place.website) {
                            Link("Restaurant website", destination: website).fontWeight(.bold)
                        }
                        RouteMap(path: draft.estimate.withPath)
                        Text(draft.estimate.source == "straight_line" ? "Approximate path. Routing was unavailable." : "Road route from the routing service. Apple Maps provides this map.")
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                        TextField("Note for the driver", text: $note, axis: .vertical)
                            .lineLimit(3 ... 5)
                            .padding(12)
                            .sketchPanel()
                        Text("Don't order food yet. Wait for the driver to accept. Home Run doesn't process payments.")
                            .font(Theme.text(.footnote)).foregroundStyle(Theme.muted)
                        if let error { ErrorBanner(message: error) }
                        PrimaryButton(title: "Send request", busy: busy) { submit() }
                    }
                }
                .padding(20)
            }
            .homeRunPage(road: false)
            .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: confirmed?.id)
            .sensoryFeedback(.success, trigger: confirmed?.id) { old, new in
                old == nil && new != nil
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func submit() {
        guard !busy, confirmed == nil else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let fee = Fees.estimate(draft.estimate.detourMinutes)
                let arrival = (Format.parse(draft.trip.departureAt) ?? Date()).addingTimeInterval(draft.estimate.toDropoffMinutes * 60)
                let formatter = ISO8601DateFormatter()
                let body = NewOrderBody(
                    tripId: draft.trip.id,
                    restaurantPlaceId: draft.place.placeId,
                    restaurantName: String(draft.place.name.prefix(120)),
                    restaurantAddress: draft.place.address,
                    restaurantLat: draft.place.lat,
                    restaurantLng: draft.place.lng,
                    restaurantWebsite: draft.place.website,
                    placeSource: draft.source,
                    destinationType: draft.handoff.type,
                    destinationLabel: draft.handoff.label,
                    destinationLat: draft.handoff.lat,
                    destinationLng: draft.handoff.lng,
                    detourMinutes: draft.estimate.detourMinutes,
                    deliveryFee: fee,
                    estimateSource: draft.estimate.source,
                    estimatedArrivalAt: formatter.string(from: arrival),
                    customerNote: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
                )
                confirmed = try await model.client().store("orders", method: "POST", body: body)
                await model.refreshBadges()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

func restaurantURL(_ raw: String?) -> URL? {
    guard let raw, let url = URL(string: raw), url.scheme == "http" || url.scheme == "https" else { return nil }
    return url
}
