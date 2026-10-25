import SwiftUI

struct DiscoverView: View {
    @Environment(AppModel.self) private var model
    var initialCity: String = Places.origins[0].name
    var initialQuery: String = ""

    @State private var city: String
    @State private var search: String
    @State private var places: [Place] = []
    @State private var source: String?
    @State private var restaurant: (place: Place, source: String)?
    @State private var meetup = Places.meetups[0]
    @State private var trips: [Trip] = []
    @State private var estimates: [String: DetourEstimate] = [:]
    @State private var searching = false
    @State private var error: String?
    @State private var request: RequestDraft?

    init(initialCity: String = Places.origins[0].name, initialQuery: String = "") {
        self.initialCity = initialCity
        self.initialQuery = initialQuery
        _city = State(initialValue: initialCity)
        _search = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick a restaurant, then see which drivers can grab it.").foregroundStyle(Theme.muted)
                    Picker("City", selection: $city) {
                        ForEach(Places.origins) { Text($0.name).tag($0.name) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        TextField("Restaurant name", text: $search)
                        Button("Search") { Task { await searchPlaces() } }.disabled(searching)
                    }
                    .padding(10)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    if let error { ErrorBanner(message: error) }
                    if searching { ProgressView("Searching \(city)…") }
                    if restaurant == nil {
                        ForEach(places) { place in
                            Button { restaurant = (place, source ?? "osm") } label: {
                                VStack(alignment: .leading) {
                                    Text(place.name).fontWeight(.bold).foregroundStyle(Theme.ink)
                                    Text(place.address).font(.caption).foregroundStyle(Theme.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    } else if let restaurant {
                        Card {
                            Text(restaurant.place.name).font(.headline)
                            Text(restaurant.place.address).font(.caption).foregroundStyle(Theme.muted)
                            Button("Change") { self.restaurant = nil }.fontWeight(.bold)
                        }
                        Text("Handoff").font(.title3.weight(.bold))
                        ForEach(Places.meetups) { point in
                            Button { meetup = point } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(point.label).fontWeight(.semibold)
                                        Text(point.detail).font(.caption).foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    if meetup.id == point.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.maroon) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Drivers").font(.title3.weight(.bold))
                        Text("Fee: \(Fees.formula).").font(.caption).foregroundStyle(Theme.muted)
                        if ranked.isEmpty {
                            Text("No upcoming trips from \(city).").foregroundStyle(Theme.muted)
                        }
                        ForEach(ranked, id: \.trip.id) { row in
                            Card {
                                TripSummary(trip: row.trip)
                                if row.own {
                                    Text("This is your trip.").font(.caption).foregroundStyle(Theme.muted)
                                } else if let estimate = row.estimate {
                                    Text("\(Format.minutes(estimate.detourMinutes)) added · \(Fees.money(Fees.estimate(estimate.detourMinutes)))")
                                        .font(.subheadline.weight(.bold)).foregroundStyle(Theme.maroon)
                                    if estimate.source == "straight_line" {
                                        Text("Approximate · routing unavailable").font(.caption).foregroundStyle(Theme.muted)
                                    }
                                    Button("Request delivery") {
                                        request = RequestDraft(trip: row.trip, estimate: estimate, place: restaurant.place, source: restaurant.source)
                                    }
                                    .fontWeight(.bold)
                                    .disabled((row.trip.activeOrders ?? 0) >= row.trip.maxOrders)
                                } else {
                                    ProgressView("Calculating route…")
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.cream)
            .navigationTitle("Discover")
            .task(id: city) { await loadTrips() }
            .task(id: restaurant?.place.placeId) { await estimateAll() }
            .sheet(item: $request) { draft in
                RequestSheet(draft: draft, meetup: meetup) { request = nil }
            }
        }
    }

    private struct Ranked { var trip: Trip; var estimate: DetourEstimate?; var own: Bool }

    private var ranked: [Ranked] {
        trips.map { trip in
            Ranked(trip: trip, estimate: estimates[trip.id], own: trip.driverId == model.user?.id)
        }
        .sorted { lhs, rhs in
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

    private func estimateAll() async {
        guard let restaurant else { return }
        estimates = [:]
        let client: APIClient
        do { client = try model.client() } catch {
            self.error = error.localizedDescription
            return
        }
        let candidates = trips.filter { $0.driverId != model.user?.id }
        for trip in candidates.prefix(12) {
            let result = await Routing.estimate(
                client: client,
                origin: LatLng(lat: trip.originLat, lng: trip.originLng),
                destination: LatLng(lat: trip.destinationLat, lng: trip.destinationLng),
                stops: (trip.stops ?? []).map { LatLng(lat: $0.lat, lng: $0.lng) },
                restaurant: LatLng(lat: restaurant.place.lat, lng: restaurant.place.lng),
                dropoff: LatLng(lat: meetup.lat, lng: meetup.lng)
            )
            estimates[trip.id] = result.0
        }
    }
}

struct RequestDraft: Identifiable {
    var trip: Trip
    var estimate: DetourEstimate
    var place: Place
    var source: String
    var id: String { trip.id }
}

struct RequestSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var draft: RequestDraft
    var meetup: MeetupPoint
    var onDone: () -> Void
    @State private var note = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ask \(Format.firstName(draft.trip.driver?.displayName)) to grab \(draft.place.name)")
                        .font(.title2.weight(.bold)).foregroundStyle(Theme.maroon)
                    Text("\(draft.trip.originCity) → \(draft.trip.destinationCity)")
                    Text("Leaves \(Format.relative(draft.trip.departureAt))").foregroundStyle(Theme.muted)
                    Text("Handoff at \(meetup.label)").foregroundStyle(Theme.muted)
                    Text("Added drive \(Format.minutes(draft.estimate.detourMinutes))")
                    Text("Delivery fee \(Fees.money(Fees.estimate(draft.estimate.detourMinutes)))").fontWeight(.bold)
                    TextField("Note for the driver", text: $note, axis: .vertical)
                        .lineLimit(3 ... 5)
                        .padding(12)
                        .background(Theme.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Don't order food yet. Wait for the driver to accept. Home Run doesn't process payments.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                    if let error { ErrorBanner(message: error) }
                    PrimaryButton(title: "Send request", busy: busy) { submit() }
                }
                .padding(20)
            }
            .background(Theme.cream)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func submit() {
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
                    destinationType: "campus",
                    destinationLabel: meetup.label,
                    destinationLat: meetup.lat,
                    destinationLng: meetup.lng,
                    detourMinutes: draft.estimate.detourMinutes,
                    deliveryFee: fee,
                    estimateSource: draft.estimate.source,
                    estimatedArrivalAt: formatter.string(from: arrival),
                    customerNote: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
                )
                let _: Order = try await model.client().store("orders", method: "POST", body: body)
                await model.refreshBadges()
                onDone()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
