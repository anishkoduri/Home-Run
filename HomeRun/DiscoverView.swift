import PhotosUI
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
    @State private var dateFilter: String?
    @State private var estimates: [String: DetourEstimate] = [:]
    @State private var searching = false
    @State private var error: String?
    @State private var request: RequestDraft?
    @State private var gallery: Place?
    @State private var savedPlaceIds: Set<String> = []
    @State private var category = "all"
    @State private var draftCategory = "all"
    @State private var showFilters = false
    @State private var searchGeneration = 0
    @State private var personalBrowse: Bool
    @State private var promoted: Set<String> = []
    @State private var pendingFavorite: SavedPlace?

    init(initialCity: String = Places.origins[0].name, initialQuery: String = "", focusTripID: String? = nil, embedded: Bool = false, personalEntry: Bool = false) {
        self.initialCity = initialCity
        self.initialQuery = initialQuery
        self.focusTripID = focusTripID
        self.embedded = embedded
        _city = State(initialValue: initialCity)
        _search = State(initialValue: initialQuery)
        _personalBrowse = State(initialValue: personalEntry)
    }

    private var estimateKey: String {
        let place = personalBrowse ? "personal" : (restaurant?.place.placeId ?? "")
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
                    if !embedded {
                        PageHeader(title: "Discover", detail: "Find a place, then a trip.")
                            .padding(.horizontal, -20)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        PickupCityButton(city: model.pickupCityConfirmed ? city : "Choose pickup city") {
                            model.cityPickerOpen = true
                        }
                        Button(personalBrowse ? "Restaurant or store" : "Home or personal item") {
                            if !model.pickupCityConfirmed {
                                model.cityPickerOpen = true
                            } else {
                                personalBrowse.toggle()
                                if personalBrowse { restaurant = nil }
                            }
                        }
                        .font(Theme.text(.body, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("home-or-personal")
                        Text("Delivering to College Station.")
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                        ChoiceBar(
                            options: ["all", "food", "groceries", "stores"],
                            label: { option in
                                switch option {
                                case "food": return "Food"
                                case "groceries": return "Groceries"
                                case "stores": return "Stores"
                                default: return "All"
                                }
                            },
                            selection: $category
                        )
                        Button("Filters") {
                            draftCategory = category
                            showFilters = true
                        }
                        .font(Theme.text(.caption, weight: .semibold))
                        .accessibilityIdentifier("discover-filters")
                        HStack(spacing: 8) {
                            TextField("Restaurant or store", text: $search, prompt: Text("Restaurant or store").foregroundStyle(Theme.muted))
                                .textFieldStyle(.plain)
                                .submitLabel(.search)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("place-search")
                                .onSubmit { Task { await searchPlaces(immediate: true) } }
                            Button("Search") {
                                if !model.pickupCityConfirmed {
                                    model.cityPickerOpen = true
                                } else {
                                    Task { await searchPlaces(immediate: true) }
                                }
                            }
                            .font(Theme.text(.body, weight: .bold))
                            .frame(minWidth: 44, minHeight: 44)
                            .disabled(searching)
                            .accessibilityIdentifier("place-search-submit")
                        }
                    }
                    .padding(14)
                    .sketchPanel()
                    .onChange(of: search) { _, _ in
                        searchGeneration += 1
                        let token = searchGeneration
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            guard token == searchGeneration else { return }
                            await searchPlaces(immediate: false, token: token)
                        }
                    }
                    .onChange(of: category) { _, _ in
                        restaurant = nil
                        Task { await searchPlaces(immediate: true) }
                    }
                    if let error { ErrorBanner(message: error) }
                    if !promoted.isEmpty && search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !personalBrowse {
                        Text("Recommended is an editorial selection for this metro. It is not a popularity rank, a sponsored placement, or a Google rating.")
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                    }
                    if source == "sample" && error == nil {
                        Text("Sample places in \(city). Not live store listings.")
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                    }
                    if searching { ProgressView("Searching \(city)…") }
                    if personalBrowse {
                        personalTrips
                    } else if restaurant == nil {
                        if !searching && places.isEmpty && error == nil {
                            EmptyState(title: "No places in \(city)", message: "Try another name, or change the pickup city.")
                        }
                        ForEach(places) { place in
                            HStack(spacing: 12) {
                                Button { gallery = place } label: { PlacePhoto(place: place) }
                                    .accessibilityLabel("Photo of \(place.name)")
                                Button {
                                    Haptics.tap()
                                    restaurant = (place, source ?? place.contentSource ?? "sample")
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(place.name).font(Theme.text(.headline, weight: .semibold)).foregroundStyle(Theme.ink)
                                        Text(place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                        if let rating = place.rating {
                                            Text("\(rating, format: .number.precision(.fractionLength(1)))")
                                                .font(Theme.text(.caption, weight: .semibold))
                                                .foregroundStyle(Theme.maroon)
                                        }
                                        if promoted.contains(place.placeId) {
                                            Text("Recommended")
                                                .font(Theme.text(.caption2, weight: .bold))
                                                .foregroundStyle(Theme.maroon)
                                        }
                                        if place.outsideCity == true {
                                            Text("Outside \(city)")
                                                .font(Theme.text(.caption))
                                                .foregroundStyle(Theme.coral)
                                        }
                                        if let credit = place.photoCredit {
                                            Text("Photo: \(credit)")
                                                .font(Theme.text(.caption2))
                                                .foregroundStyle(Theme.muted)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                Button { Task { await toggleSaved(place) } } label: {
                                    Image(systemName: savedPlaceIds.contains(place.placeId) ? "bookmark.fill" : "bookmark")
                                        .foregroundStyle(Theme.maroon)
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel(savedPlaceIds.contains(place.placeId) ? "Remove saved place" : "Save place")
                            }
                            .padding(12)
                            .sketchPanel()
                            .accessibilityIdentifier("place-result-\(place.placeId)")
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
                        Text("Handoff").font(Theme.section())
                        ChoiceBar(options: ["campus", "address"], label: { $0 == "campus" ? "Campus" : "Address" }, selection: $handoffMode)
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
                        Text("Trips").font(Theme.section())
                        if !dayChoices.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    filterChip("Any day", selected: dateFilter == nil) { dateFilter = nil }
                                    ForEach(dayChoices, id: \.self) { day in
                                        filterChip(day, selected: dateFilter == day) { dateFilter = day }
                                    }
                                }
                            }
                        }
                        if dateFilter != nil && ranked.isEmpty {
                            Button("Clear date") { dateFilter = nil }
                                .font(Theme.text(.caption, weight: .semibold))
                        }
                        Text("Fee: \(Fees.formula).").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        if ranked.isEmpty {
                            EmptyState(title: "No trips from \(city)", message: "No one has posted a drive from here yet.")
                            NavigationLink("Save a request") { SavedRequestsView(city: city) }
                                .font(Theme.text(.body, weight: .semibold))
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
                            Text("Your trip.").font(Theme.text(.caption, weight: .bold)).foregroundStyle(Theme.maroon)
                            Text("You can inspect it here. Switch to another person to request a pickup.")
                                .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        } else if let estimate = row.estimate {
                                    Text("\(Format.minutes(estimate.detourMinutes)) added · \(previewFee(estimate))")
                                        .font(Theme.text(.subheadline, weight: .bold)).foregroundStyle(Theme.maroon)
                                    if estimate.detourMinutes > 45 {
                                        Text("Long detour. The driver may decline.").font(Theme.text(.caption)).foregroundStyle(Theme.coral)
                                    }
                                    if estimate.source == "straight_line" {
                                        Text("Approximate distance. A driving route wasn't available.").font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                    }
                                    Button("Restaurant or store") {
                                        request = RequestDraft(trip: row.trip, estimate: estimate, place: restaurant.place, source: restaurant.source, handoff: handoff, kind: "merchant")
                                    }
                                    .font(Theme.text(.headline, weight: .semibold))
                                    .frame(minHeight: 44)
                                    .disabled((row.trip.activeOrders ?? 0) >= row.trip.maxOrders)
                                    Button("Home or personal item") {
                                        request = RequestDraft(trip: row.trip, estimate: estimate, place: Self.sampleHouse(near: row.trip), source: "sample", handoff: handoff, kind: "personal")
                                    }
                                    .font(Theme.text(.headline, weight: .semibold))
                                    .frame(minHeight: 44)
                                    .disabled((row.trip.activeOrders ?? 0) >= row.trip.maxOrders)
                                } else {
                                    ProgressView("Calculating route…")
                                }
                            }
                            .padding(12)
                            .ticketPanel()
                        }
                    }
                }
                .padding(20)
            }
            .homeRunPage(road: false)
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(embedded ? .visible : .hidden, for: .navigationBar)
            .toolbarBackground(Theme.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .task {
                if let saved = model.stagedFavorite {
                    model.stagedFavorite = nil
                    personalBrowse = false
                    pendingFavorite = saved
                    if Places.city(named: saved.city) != nil {
                        city = Places.city(named: saved.city)?.name ?? saved.city
                        model.confirmPickupCity(city)
                    }
                } else if !embedded, model.pickupCityConfirmed {
                    city = model.pickupCity
                }
                await searchPlaces(immediate: true)
            }
            .task(id: city) {
                restaurant = nil
                await loadTrips()
                await searchPlaces(immediate: true)
                if let saved = pendingFavorite {
                    pendingFavorite = nil
                    guard !saved.placeId.isEmpty, !saved.name.isEmpty else { return }
                    restaurant = (Place(placeId: saved.placeId, name: saved.name, address: saved.address, lat: saved.lat, lng: saved.lng, contentSource: saved.contentSource), saved.contentSource ?? "saved")
                }
            }
            .refreshable {
                await loadTrips()
                await searchPlaces(immediate: true)
            }
            .onChange(of: model.pickupCity) { _, name in
                guard model.pickupCityConfirmed, !embedded else { return }
                city = name
                restaurant = nil
            }
            .task(id: estimateKey) { await estimateAll() }
            .sheet(item: $request) { draft in
                RequestSheet(draft: draft) { request = nil }
            }
            .sheet(item: $gallery) { place in
                PlaceGallery(place: place)
            }
            .sheet(isPresented: $showFilters) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category").font(Theme.section())
                        ChoiceBar(
                            options: ["all", "food", "groceries", "stores"],
                            label: { option in
                                switch option {
                                case "food": return "Food"
                                case "groceries": return "Groceries"
                                case "stores": return "Stores"
                                default: return "All"
                                }
                            },
                            selection: $draftCategory
                        )
                        Text("The pickup city stays \(city).")
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                        PrimaryButton(title: "Apply") {
                            category = draftCategory
                            showFilters = false
                        }
                        Button("Reset") { draftCategory = "all" }
                            .font(Theme.text(.body, weight: .semibold))
                        Button("Clear all") {
                            category = "all"
                            draftCategory = "all"
                            showFilters = false
                        }
                        .font(Theme.text(.body, weight: .semibold))
                        Spacer()
                    }
                    .padding(20)
                    .homeRunPage(road: false)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showFilters = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .task { await loadSavedPlaces() }
    }

    private struct Ranked { var trip: Trip; var estimate: DetourEstimate?; var own: Bool }

    private var dayChoices: [String] {
        Array(Set(trips.map { Format.chicagoDay($0.departureAt) })).sorted()
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.text(.caption, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Theme.maroon : Theme.surface)
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var ranked: [Ranked] {
        trips.filter { dateFilter == nil || Format.chicagoDay($0.departureAt) == dateFilter }.map { trip in
            Ranked(trip: trip, estimate: estimates[trip.id], own: trip.driverId == model.user?.id)
        }
        .sorted { lhs, rhs in
            if lhs.trip.id == focusTripID { return true }
            if rhs.trip.id == focusTripID { return false }
            if lhs.own != rhs.own { return !lhs.own }
            return (lhs.estimate?.detourMinutes ?? 999) < (rhs.estimate?.detourMinutes ?? 999)
        }
    }

    private func previewFee(_ estimate: DetourEstimate) -> String {
        guard DemoRouteFixture.isPricedRoad(estimate.source) else { return "Price needs review" }
        let meters = max(0, (estimate.withKm - estimate.baseKm) * 1000)
        let seconds = max(0, estimate.detourMinutes * 60)
        switch PricingPolicy.evaluate(.init(extraMeters: meters, extraSeconds: seconds, weightPounds: 1, weightConfirmed: true, bulky: false, agreedWaitingMinutes: 0)) {
        case .quoted(let quote): return "from \(Fees.money(quote.dollars))"
        case .manualReview: return "Price needs review"
        }
    }

    private func loadSavedPlaces() async {
        let list: SavedPlaceList = (try? await model.client().store("saved-places")) ?? SavedPlaceList(places: [])
        savedPlaceIds = Set(list.places.map(\.placeId))
    }

    private func toggleSaved(_ place: Place) async {
        struct Body: Encodable {
            var placeId: String
            var name: String
            var address: String
            var lat: Double
            var lng: Double
            var city: String
            var photoName: String?
            var photoCredit: String?
            var contentSource: String?
        }
        do {
            let list: SavedPlaceList = try await model.client().store("saved-places", method: "POST", body: Body(placeId: place.placeId, name: place.name, address: place.address, lat: place.lat, lng: place.lng, city: city, photoName: place.photoName, photoCredit: place.photoCredit, contentSource: place.contentSource))
            savedPlaceIds = Set(list.places.map(\.placeId))
        } catch {
            self.error = error.localizedDescription
        }
    }

    @ViewBuilder
    private var personalTrips: some View {
        Text("Home or personal item")
            .font(Theme.section())
        Text("No store purchase. Describe the item, where it is, and when someone can pick it up.")
            .font(Theme.text(.caption))
            .foregroundStyle(Theme.muted)
        if ranked.isEmpty {
            EmptyState(title: "No trips from \(city)", message: "No one has posted a drive from here yet.")
        }
        ForEach(ranked, id: \.trip.id) { row in
            VStack(alignment: .leading, spacing: 8) {
                TripSummary(trip: row.trip)
                if row.own {
                    Text("Your trip.").font(Theme.text(.caption, weight: .bold)).foregroundStyle(Theme.maroon)
                } else if let estimate = row.estimate {
                    Text("\(Format.minutes(estimate.detourMinutes)) added · \(previewFee(estimate))")
                        .font(Theme.text(.subheadline, weight: .bold)).foregroundStyle(Theme.maroon)
                    Button("Request a pickup") {
                        request = RequestDraft(trip: row.trip, estimate: estimate, place: Self.sampleHouse(near: row.trip), source: "sample", handoff: handoff, kind: "personal")
                    }
                    .font(Theme.text(.headline, weight: .semibold))
                    .frame(minHeight: 44)
                    .disabled((row.trip.activeOrders ?? 0) >= row.trip.maxOrders)
                } else {
                    ProgressView("Calculating route…")
                }
            }
            .padding(12)
            .ticketPanel()
        }
    }

    private func searchPlaces(immediate: Bool, token: Int? = nil) async {
        if personalBrowse {
            places = []
            promoted = []
            searching = false
            return
        }
        guard model.pickupCityConfirmed || embedded else {
            places = []
            searching = false
            return
        }
        if immediate { searchGeneration += 1 }
        let current = token ?? searchGeneration
        searching = true
        defer { if current == searchGeneration { searching = false } }
        do {
            let response: PlaceSearchResponse = try await model.client().geo(
                "places",
                query: ["city": city, "q": search, "category": category]
            )
            guard current == searchGeneration else { return }
            places = DiscoveryCuration.order(response.places, city: city, query: search, category: category)
            promoted = DiscoveryCuration.promotedIDs(in: places, city: city, query: search, category: category)
            source = response.source
            error = nil
        } catch {
            guard current == searchGeneration else { return }
            places = []
            source = nil
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
        if personalBrowse {
            estimates = [:]
            let client: APIClient
            do { client = try model.client() } catch {
                self.error = error.localizedDescription
                return
            }
            for trip in trips.filter({ $0.driverId != model.user?.id }).prefix(12) {
                if Task.isCancelled { return }
                let house = Self.sampleHouse(near: trip)
                do {
                    let result = try await Routing.estimate(
                        client: client,
                        origin: LatLng(lat: trip.originLat, lng: trip.originLng),
                        destination: LatLng(lat: trip.destinationLat, lng: trip.destinationLng),
                        stops: (trip.stops ?? []).map { LatLng(lat: $0.lat, lng: $0.lng) },
                        restaurant: LatLng(lat: house.lat, lng: house.lng),
                        dropoff: LatLng(lat: handoff.lat, lng: handoff.lng)
                    )
                    if Task.isCancelled { return }
                    estimates[trip.id] = result.0
                } catch {
                    self.error = error.localizedDescription
                    return
                }
            }
            return
        }
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

extension DiscoverView {
    fileprivate static func sampleHouse(near trip: Trip) -> Place {
        Place(
            placeId: "sample:house-\(trip.originCity)",
            name: "Sample house — not a real address",
            address: "Fictional point near \(trip.originCity). Not a geocoded home.",
            lat: trip.originLat + 0.008,
            lng: trip.originLng + 0.008,
            rating: nil,
            ratingCount: nil,
            website: nil,
            mapsUrl: nil,
            photoName: nil,
            photoCredit: nil,
            contentSource: "sample"
        )
    }
}

struct RequestDraft: Identifiable {
    var trip: Trip
    var estimate: DetourEstimate
    var place: Place
    var source: String
    var handoff: Handoff
    var kind: String = "merchant"
    var id: String { trip.id + kind }
}

private struct DraftBody: Encodable {
    var tripId: String
    var placeId: String
    var requestText: String
    var merchandise: String
    var substitution: String
    var instructions: String
    var personal: Bool
    var bulky: Bool
    var screenshotBase64: String?
    var removeScreenshot: Bool
}

struct RequestSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var draft: RequestDraft
    var onDone: () -> Void
    @State private var requestText = ""
    @State private var merchandise = ""
    @State private var substitution = "ask"
    @State private var instructions = ""
    @State private var personal = false
    @State private var alreadyOrdered = false
    @State private var contact = ""
    @State private var access = ""
    @State private var quantity = ""
    @State private var windowChoice = "30 minutes before departure"
    @State private var orderName = ""
    @State private var orderNumber = ""
    @State private var referenceMissing = false
    @State private var pickupCode = ""
    @State private var weightText = ""
    @State private var fragile = false
    @State private var bulky = false
    @State private var heavy = false
    @State private var photoItem: PhotosPickerItem?
    @State private var screenshot: UIImage?
    @State private var showScreenshot = false
    @State private var loadedTrip = ""
    @State private var operationKey = UUID().uuidString
    @State private var busy = false
    @State private var error: String?
    @State private var confirmed: Order?
    @State private var submitted = false

    init(draft: RequestDraft, onDone: @escaping () -> Void) {
        self.draft = draft
        self.onDone = onDone
        _personal = State(initialValue: draft.kind == "personal")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let confirmed {
                        Text("Request stored")
                            .font(Theme.brand(.title))
                            .foregroundStyle(Theme.maroon)
                        Text(confirmed.restaurantName).font(Theme.section())
                        StatusPill(status: confirmed.status, title: confirmed.progressTitle)
                        Text(confirmed.itemSummary ?? "Pickup details saved.")
                            .font(Theme.text(.subheadline))
                        Text(confirmed.isPersonalPickup ? "Home pickup. No store payment is part of this request." : "Wait for your runner to accept before ordering, unless you already ordered. The delivery fee is simulated.")
                            .font(Theme.text(.subheadline))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        if let fee = confirmed.quoteCents {
                            Text("Delivery fee \(Fees.money(Double(fee) / 100))").font(Theme.price())
                        }
                        PrimaryButton(title: "Done") { onDone(); dismiss() }
                    } else {
                        Text(personal ? "Home or personal item" : "Restaurant or store")
                            .font(Theme.brand(.title2)).foregroundStyle(Theme.maroon)
                        Text(draft.place.name).font(Theme.section())
                        Text(draft.place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        if personal {
                            Text("This point is fictional and near \(draft.trip.originCity). It is not a real home or a precise driveway route.")
                                .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        }
                        CityRoute(origin: draft.trip.originCity, destination: draft.trip.destinationCity)
                        Text("\(Format.firstName(draft.trip.driver?.displayName)) · leaves \(Format.relative(draft.trip.departureAt))")
                            .foregroundStyle(Theme.muted)
                        Text("Meetup \(draft.handoff.label)").foregroundStyle(Theme.muted)
                        Text("Pickup details").font(Theme.text(.headline, weight: .semibold))
                        TextField(personal ? "Black backpack with a red luggage tag, one bag, about 8 lb. My roommate Jordan will meet you at the front entrance." : "Two takeout bags: one rice bowl and one sandwich. Keep the drink upright.", text: $requestText, axis: .vertical)
                            .lineLimit(4 ... 10)
                            .padding(12)
                            .sketchPanel()
                        if personal {
                            TextField("How many, and what it looks like", text: $quantity).padding(12).sketchPanel()
                            TextField("Approximate weight, pounds. Leave blank if unknown.", text: $weightText)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .sketchPanel()
                            TextField("Who will meet the runner", text: $contact).padding(12).sketchPanel()
                            TextField("Entrance, gate, or where they will meet", text: $access, axis: .vertical)
                                .lineLimit(2 ... 5)
                                .padding(12)
                                .sketchPanel()
                            Toggle("Bulky", isOn: $bulky)
                            Toggle("Fragile", isOn: $fragile)
                            Text("Optional item photo").font(Theme.text(.caption, weight: .semibold)).foregroundStyle(Theme.muted)
                            screenshotCard
                        } else {
                            Toggle("About 35 lb", isOn: $heavy)
                            Toggle("I've already ordered", isOn: $alreadyOrdered)
                            if alreadyOrdered {
                                Text("A runner is not guaranteed until acceptance. Home Run cannot undo a store purchase.")
                                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                                TextField("Name on the order", text: $orderName).padding(12).sketchPanel()
                                Toggle("Merchant did not provide a number", isOn: $referenceMissing)
                                if !referenceMissing {
                                    TextField("Order number", text: $orderNumber).padding(12).sketchPanel()
                                }
                                TextField("Pickup code, if you have one", text: $pickupCode).padding(12).sketchPanel()
                                screenshotCard
                            } else {
                                Text("Wait for your runner to accept before ordering.")
                                    .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                            }
                        }
                        Picker("Pickup window", selection: $windowChoice) {
                            Text("30 minutes before departure").tag("30 minutes before departure")
                            Text("When the runner is nearby").tag("When the runner is nearby")
                        }
                        TextField("Extra instructions", text: $instructions, axis: .vertical)
                            .lineLimit(2 ... 5)
                            .padding(12)
                            .sketchPanel()
                        Text(quoteLabel).font(Theme.price())
                        Text("Delivery fee only. Simulated. No card is charged.")
                            .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        if let website = restaurantURL(draft.place.website) {
                            Link("Restaurant website", destination: website).fontWeight(.bold)
                        }
                        RouteMap(path: draft.estimate.withPath)
                        Text(routeCaption(draft.estimate.source))
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                        if let error { ErrorBanner(message: error) }
                        PrimaryButton(title: "Send request", busy: busy) { submit() }
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .homeRunPage(road: false)
            .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: confirmed?.id)
            .sensoryFeedback(.success, trigger: confirmed?.id) { old, new in
                old == nil && new != nil
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task {
                personal = draft.kind == "personal"
                await restoreDraft()
            }
            .onDisappear { persistDraft() }
            .sheet(isPresented: $showScreenshot) {
                if let screenshot {
                    NavigationStack {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: screenshot)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("Basket screenshot")
                        }
                        .homeRunPage(road: false)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showScreenshot = false } } }
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await loadPhoto(item) }
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var screenshotCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let screenshot {
                Button { showScreenshot = true } label: {
                    Image(uiImage: screenshot)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Basket screenshot. Full screen.")
                }
                HStack {
                    PhotosPicker(selection: $photoItem, matching: .images) { Text("Replace") }
                    Button("Remove") { self.screenshot = nil; photoItem = nil }
                        .foregroundStyle(Theme.bad)
                }
                .font(Theme.text(.body, weight: .semibold))
            } else {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Add a screenshot")
                        .font(Theme.text(.body, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 88)
                }
                .sketchPanel()
            }
        }
    }

    private var measured: (meters: Double, seconds: Double, source: String) {
        if personal {
            let source = DemoRouteFixture.isPricedRoad(draft.estimate.source) ? draft.estimate.source : draft.estimate.source
            return (0, 0, source)
        }
        let meters = max(0, (draft.estimate.withKm - draft.estimate.baseKm) * 1000)
        let seconds = max(0, draft.estimate.detourMinutes * 60)
        return (meters, seconds, draft.estimate.source)
    }

    private var basketPounds: Double? {
        if personal {
            let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return Double(trimmed)
        }
        return heavy ? 35 : (bulky ? 20 : 5)
    }

    private var quoteLabel: String {
        guard DemoRouteFixture.isPricedRoad(measured.source) else { return "Price needs review" }
        guard let pounds = basketPounds else { return "Unknown weight needs a reviewed price." }
        switch PricingPolicy.evaluate(.init(extraMeters: measured.meters, extraSeconds: measured.seconds, weightPounds: pounds, weightConfirmed: true, bulky: bulky, agreedWaitingMinutes: 0)) {
        case .quoted(let quote):
            return "Delivery fee \(Fees.money(quote.dollars))"
        case .manualReview(let reason):
            return reason
        }
    }

    private func routeCaption(_ source: String) -> String {
        if source == "straight_line" {
            return "Approximate path. A driving route wasn't available."
        }
        if GoogleMapsStartup.isReady {
            if source == "google" {
                return "Driving route. Google Maps provides this map."
            }
            return "Google Maps provides this map. The road measurement is a separate estimate."
        }
        return "Driving route. Apple Maps provides this map."
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data), image.size.width > 0 else {
                error = "Use a photo of the basket or item list."
                return
            }
            screenshot = Self.fitted(image)
            error = nil
        } catch {
            self.error = "Use a photo of the basket or item list."
        }
    }

    private func restoreDraft() async {
        let staged = model.takeRepeatLines()
        if requestText.isEmpty, !staged.isEmpty {
            requestText = staged.map { "\($0.quantity)× \($0.name)" }.joined(separator: "\n")
        }
        let saved: ComposerDraft? = try? await model.client().store("draft")
        guard let saved, saved.tripId == draft.trip.id, saved.placeId == draft.place.placeId else { return }
        loadedTrip = saved.tripId
        if !saved.requestText.isEmpty { requestText = saved.requestText }
        if !saved.merchandise.isEmpty { merchandise = saved.merchandise }
        if !saved.substitution.isEmpty { substitution = saved.substitution }
        instructions = saved.instructions
        personal = saved.personal
        bulky = saved.bulky
        if let encoded = saved.screenshotBase64, let data = Data(base64Encoded: encoded), let image = UIImage(data: data) {
            screenshot = image
        }
    }

    private func persistDraft() {
        guard !submitted else { return }
        let dirty = !requestText.isEmpty || screenshot != nil || !merchandise.isEmpty || !instructions.isEmpty
        guard dirty || loadedTrip == draft.trip.id else { return }
        let body = DraftBody(
            tripId: draft.trip.id,
            placeId: draft.place.placeId,
            requestText: requestText,
            merchandise: merchandise,
            substitution: substitution,
            instructions: instructions,
            personal: personal,
            bulky: bulky,
            screenshotBase64: screenshot?.jpegData(compressionQuality: 0.72)?.base64EncodedString(),
            removeScreenshot: screenshot == nil
        )
        Task { let _: OkayBody? = try? await model.client().store("draft", method: "POST", body: body) }
    }

    private func pickupInstant() -> Date? {
        guard let departure = Format.parse(draft.trip.departureAt) else { return nil }
        let ready = windowChoice == "30 minutes before departure" ? departure.addingTimeInterval(-1_800) : departure.addingTimeInterval(-300)
        return ready > DemoClock.now ? ready : nil
    }

    private func submit() {
        guard !busy, confirmed == nil else { return }
        let description = requestText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            error = "Add pickup details."
            return
        }
        if personal && contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = "Add who will meet the runner. A phone number is not required."
            return
        }
        if !personal && alreadyOrdered {
            if orderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                error = "Add the name on the order."
                return
            }
            if !referenceMissing && orderNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                error = "Add the order number, or say the merchant did not provide one."
                return
            }
        }
        guard let ready = pickupInstant() else {
            error = "That pickup window is already past for this trip."
            return
        }
        let image = screenshot?.jpegData(compressionQuality: 0.72)?.base64EncodedString()
        busy = true
        Task {
            defer { busy = false }
            do {
                let arrival = (Format.parse(draft.trip.departureAt) ?? Date()).addingTimeInterval(draft.estimate.toDropoffMinutes * 60)
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
                    deliveryFee: nil,
                    estimateSource: draft.estimate.source,
                    estimatedArrivalAt: ISO8601DateFormatter().string(from: arrival),
                    customerNote: instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions,
                    extraMeters: measured.meters,
                    extraSeconds: measured.seconds,
                    weightPounds: basketPounds,
                    weightConfirmed: basketPounds != nil,
                    bulky: bulky,
                    itemSummary: description,
                    pickupReference: nil,
                    lines: nil,
                    operationKey: operationKey,
                    requestText: description,
                    merchandiseCents: nil,
                    substitution: nil,
                    personalItem: personal,
                    screenshotBase64: image,
                    pickupKind: personal ? "personal" : "merchant",
                    contactLabel: personal ? contact : nil,
                    accessInstructions: personal ? access : nil,
                    pickupWindow: windowChoice,
                    itemQuantity: personal ? quantity : nil,
                    fragile: fragile,
                    alreadyOrdered: alreadyOrdered,
                    pickupName: alreadyOrdered ? orderName : nil,
                    restaurantOrderNumber: alreadyOrdered && !referenceMissing ? orderNumber : nil,
                    referenceMissing: alreadyOrdered ? referenceMissing : nil,
                    pickupReadyAt: ISO8601DateFormatter().string(from: ready),
                    pickupCode: pickupCode.isEmpty ? nil : pickupCode,
                    pickupInstructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instructions,
                    readyConfirmed: nil
                )
                confirmed = try await model.client().store("orders", method: "POST", body: body)
                submitted = true
                let _: OkayBody = try await model.client().store("draft", method: "DELETE")
                await model.refreshBadges()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private static func merchandiseCents(_ raw: String) -> Int? {
        let cleaned = raw.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let decimal = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        var cents = decimal * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &cents, 0, .plain)
        let value = (rounded as NSDecimalNumber).intValue
        return (1...50_000).contains(value) ? value : nil
    }

    private static func fitted(_ image: UIImage) -> UIImage {
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        guard scale < 1 else { return image }
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private struct OkayBody: Decodable { var ok: Bool }

struct ItemDraft: Identifiable, Equatable {
    var id = UUID().uuidString
    var name = ""
    var quantity = 1
    var weight = ""
    var bulky = false
    var fragile = false
}

func restaurantURL(_ raw: String?) -> URL? {
    guard let raw, let url = URL(string: raw), url.scheme == "http" || url.scheme == "https" else { return nil }
    return url
}
