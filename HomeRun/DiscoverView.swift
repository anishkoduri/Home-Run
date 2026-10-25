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
    @State private var searching = false
    @State private var error: String?
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
                        PageHeader(title: "Discover", detail: "Find a place. A trip is not required to post.")
                            .padding(.horizontal, -20)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        PickupCityButton(city: model.pickupCityConfirmed ? city : "Choose pickup city") {
                            model.cityPickerOpen = true
                        }
                        if model.pickupCityConfirmed || embedded {
                            NavigationLink {
                                PostRequestView(city: city, startPersonal: true)
                            } label: {
                                Text("Home or personal item")
                                    .font(Theme.text(.body, weight: .semibold))
                                    .foregroundStyle(Theme.maroon)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Theme.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.maroon, lineWidth: 1.2))
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("home-or-personal")
                        } else {
                            Button {
                                model.cityPickerOpen = true
                            } label: {
                                Text("Home or personal item")
                                    .font(Theme.text(.body, weight: .semibold))
                                    .foregroundStyle(Theme.maroon)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Theme.surface)
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.maroon, lineWidth: 1.2))
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("home-or-personal")
                        }
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
                            EntryField("Restaurant or store", text: $search, prompt: Text("Restaurant or store").foregroundStyle(Theme.muted))
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
                    if restaurant == nil {
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
                            EntryField("Street address in College Station", text: $addressQuery)
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
                        if handoffMode == "campus" || handoff.type == "address" {
                            NavigationLink {
                                PostRequestView(
                                    city: city,
                                    initialPlace: restaurant.place,
                                    dropoffLabel: handoff.label,
                                    dropoffLat: handoff.lat,
                                    dropoffLng: handoff.lng,
                                    dropoffType: handoff.type
                                )
                            } label: {
                                Text("Continue")
                                    .font(Theme.text(.body, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(Theme.maroon)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(PressStyle())
                            .accessibilityIdentifier("continue-order")
                        } else {
                            Text("Choose a delivery address to continue.")
                                .font(Theme.text(.caption))
                                .foregroundStyle(Theme.muted)
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
                        Text(Fees.formula).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
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

    private struct Ranked { var trip: Trip; var own: Bool }

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
            Ranked(trip: trip, own: trip.driverId == model.user?.id)
        }
        .sorted { lhs, rhs in
            if lhs.trip.id == focusTripID { return true }
            if rhs.trip.id == focusTripID { return false }
            if lhs.trip.createdAt != rhs.trip.createdAt { return lhs.trip.createdAt > rhs.trip.createdAt }
            return lhs.trip.id > rhs.trip.id
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

    private func searchPlaces(immediate: Bool, token: Int? = nil) async {
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
}

func restaurantURL(_ raw: String?) -> URL? {
    guard let raw, let url = URL(string: raw), url.scheme == "http" || url.scheme == "https" else { return nil }
    return url
}
