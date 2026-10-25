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
    @State private var showCities = false

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
                    if !embedded {
                        PageHeader(title: "Discover", detail: "Find a place, then a trip.")
                            .padding(.horizontal, -20)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        PickupCityButton(city: city) { showCities = true }
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
                                Task { await searchPlaces(immediate: true) }
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
                if !embedded { city = model.pickupCity }
                await searchPlaces(immediate: true)
            }
            .task(id: city) {
                restaurant = nil
                await loadTrips()
                await searchPlaces(immediate: true)
            }
            .refreshable {
                await loadTrips()
                await searchPlaces(immediate: true)
            }
            .sheet(isPresented: $showCities) {
                PickupCitySheet { name in
                    city = name
                    model.confirmPickupCity(name)
                    restaurant = nil
                }
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

    private func searchPlaces(immediate: Bool, token: Int? = nil) async {
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
            places = response.places
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
    @State private var lines: [ItemDraft] = [ItemDraft()]
    @State private var personal = false
    @State private var reference = ""
    @State private var operationKey = UUID().uuidString
    @State private var busy = false
    @State private var error: String?
    @State private var confirmed: Order?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let confirmed {
                        Text("Request stored")
                            .font(Theme.brand(.title))
                            .foregroundStyle(Theme.maroon)
                        Text(confirmed.restaurantName).font(Theme.section())
                        StatusPill(status: confirmed.status)
                        Text("This is the status Home Run saved. The driver has not accepted it yet, and no payment was taken.")
                            .font(Theme.text(.subheadline))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        PrimaryButton(title: "Done") { onDone(); dismiss() }
                    } else {
                        Text("Ask \(Format.firstName(draft.trip.driver?.displayName)) to grab \(draft.place.name)")
                            .font(Theme.brand(.title2)).foregroundStyle(Theme.maroon)
                        CityRoute(origin: draft.trip.originCity, destination: draft.trip.destinationCity)
                        Text("Leaves \(Format.relative(draft.trip.departureAt))").foregroundStyle(Theme.muted)
                        Text("Handoff at \(draft.handoff.label)").foregroundStyle(Theme.muted)
                        Text("Added drive \(Format.minutes(draft.estimate.detourMinutes))")
                        Toggle(personal ? "Personal item pickup" : "I order and pay the store separately", isOn: $personal)
                        ForEach($lines) { $line in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("What should they pick up?", text: $line.name).padding(12).sketchPanel()
                                Stepper("Quantity \(line.quantity)", value: $line.quantity, in: 1...12)
                                TextField("Weight each, pounds. Leave blank if unknown.", text: $line.weight)
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .sketchPanel()
                                Toggle("Bulky", isOn: $line.bulky)
                                Toggle("Fragile", isOn: $line.fragile)
                                if lines.count > 1 {
                                    Button("Remove item") { lines.removeAll { $0.id == line.id } }
                                        .foregroundStyle(Theme.bad)
                                }
                            }
                            .padding(12)
                            .ticketPanel()
                        }
                        Button("Add item") { lines.append(ItemDraft()) }.font(Theme.text(.body, weight: .semibold))
                        Text(quoteLabel).font(Theme.price())
                        Text("Paid to the store separately. This delivery fee is simulated.")
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                        TextField("Pickup reference", text: $reference)
                            .padding(12)
                            .sketchPanel()
                        if let website = restaurantURL(draft.place.website) {
                            Link("Restaurant website", destination: website).fontWeight(.bold)
                        }
                        RouteMap(path: draft.estimate.withPath)
                        Text(routeCaption(draft.estimate.source))
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
            .onAppear {
                let staged = model.takeRepeatLines()
                if !staged.isEmpty {
                    lines = staged.map {
                        ItemDraft(id: $0.id, name: $0.name, quantity: $0.quantity, weight: $0.weightPounds.map { String($0) } ?? "", bulky: $0.bulky, fragile: $0.fragile)
                    }
                }
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var measured: (meters: Double, seconds: Double, source: String) {
        let meters = max(0, (draft.estimate.withKm - draft.estimate.baseKm) * 1000)
        let seconds = max(0, draft.estimate.detourMinutes * 60)
        return (meters, seconds, draft.estimate.source)
    }

    private var quoteLabel: String {
        guard DemoRouteFixture.isPricedRoad(measured.source) else {
            return "Price needs review"
        }
        guard lines.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return "Name each item to see the delivery fee."
        }
        let confirmed = lines.allSatisfy { Double($0.weight) != nil }
        guard confirmed else { return "Unknown weight needs a reviewed price." }
        let pounds = lines.reduce(0.0) { $0 + (Double($1.weight) ?? 0) * Double($1.quantity) }
        switch PricingPolicy.evaluate(.init(extraMeters: measured.meters, extraSeconds: measured.seconds, weightPounds: pounds, weightConfirmed: true, bulky: lines.contains { $0.bulky }, agreedWaitingMinutes: 0)) {
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

    private func submit() {
        guard !busy, confirmed == nil else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let prepared = lines.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                guard !prepared.isEmpty else {
                    error = "Add at least one item."
                    return
                }
                guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    error = "Add the pickup reference the runner should look for."
                    return
                }
                let orderLines = prepared.map { line in
                    OrderLine(
                        id: line.id,
                        name: line.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        quantity: line.quantity,
                        weightPounds: Double(line.weight),
                        weightConfirmed: Double(line.weight) != nil,
                        bulky: line.bulky,
                        fragile: line.fragile,
                        note: nil
                    )
                }
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
                    deliveryFee: nil,
                    estimateSource: draft.estimate.source,
                    estimatedArrivalAt: formatter.string(from: arrival),
                    customerNote: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
                    extraMeters: max(0, (draft.estimate.withKm - draft.estimate.baseKm) * 1000),
                    extraSeconds: max(0, draft.estimate.detourMinutes * 60),
                    weightPounds: nil,
                    weightConfirmed: nil,
                    bulky: nil,
                    itemSummary: nil,
                    pickupReference: reference.trimmingCharacters(in: .whitespacesAndNewlines),
                    lines: orderLines,
                    operationKey: operationKey
                )
                confirmed = try await model.client().store("orders", method: "POST", body: body)
                await model.refreshBadges()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

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
