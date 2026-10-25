import SwiftUI

struct PostTripView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var origin = ""
    @State private var day = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var time = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var maxOrders = 3
    @State private var notes = ""
    @State private var stopQuery = ""
    @State private var stopResults: [Place] = []
    @State private var stops: [Place] = []
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Route").font(Theme.display(.headline))
                    Picker("Driving from", selection: $origin) {
                        Text("Choose a city").tag("")
                        ForEach(Places.origins) { Text($0.name).tag($0.name) }
                    }
                    .accessibilityLabel("Driving from")
                    LabeledContent("To") { Text(Places.destination.name).font(Theme.text(.body, weight: .semibold)) }
                    DatePicker("Departure date", selection: $day, displayedComponents: .date)
                    DatePicker("Departure time", selection: $time, displayedComponents: .hourAndMinute)
                    Stepper("Max orders: \(maxOrders)", value: $maxOrders, in: 1 ... 6)
                }
                .padding(16)
                .sketchPanel()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Planned stops").font(Theme.display(.headline))
                    ForEach(stops) { stop in
                        HStack {
                            Text(stop.name).font(Theme.text(.body))
                            Spacer()
                            Button("Remove") { stops.removeAll { $0.placeId == stop.placeId } }
                                .font(Theme.text(.caption, weight: .semibold))
                                .foregroundStyle(Theme.bad)
                        }
                    }
                    TextField("Search a restaurant", text: $stopQuery)
                        .padding(12)
                        .frame(minHeight: 44)
                        .sketchPanel()
                    Button("Find stop") { Task { await findStop() } }
                        .font(Theme.text(.body, weight: .semibold))
                        .frame(minHeight: 44)
                        .disabled(origin.isEmpty || stops.count >= 3)
                    ForEach(stopResults) { place in
                        Button(place.name) {
                            if !stops.contains(where: { $0.placeId == place.placeId }) { stops.append(place) }
                            stopResults = []
                            stopQuery = ""
                        }
                        .font(Theme.text(.body, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 44)
                    }
                }
                .padding(16)
                .sketchPanel()

                TextField("Notes for customers", text: $notes, axis: .vertical)
                    .padding(12)
                    .frame(minHeight: 44)
                    .sketchPanel()
                if let error { ErrorBanner(message: error) }
                PrimaryButton(title: "Publish trip", busy: busy) { publish() }
            }
            .padding(20)
        }
        .navigationTitle("Post a trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .homeRunPage(road: false)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private func findStop() async {
        do {
            let response: PlaceSearchResponse = try await model.client().geo("places", query: ["city": origin, "q": stopQuery])
            stopResults = response.places
            if response.places.isEmpty { error = "No restaurants found." }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func publish() {
        guard let city = Places.origins.first(where: { $0.name == origin }) else {
            error = "Choose where you're driving from."
            return
        }
        let departure = Format.combine(day: day, time: time)
        guard let when = Format.parse(departure), when > Date() else {
            error = "Departure must be in the future."
            return
        }
        busy = true
        Task {
            defer { busy = false }
            do {
                let body = NewTripBody(
                    trip: .init(
                        originCity: city.name,
                        originLat: city.lat,
                        originLng: city.lng,
                        destinationCity: Places.destination.name,
                        destinationLat: Places.destination.lat,
                        destinationLng: Places.destination.lng,
                        departureAt: departure,
                        maxOrders: maxOrders,
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
                    ),
                    stops: stops.map {
                        .init(placeId: $0.placeId, restaurantName: String($0.name.prefix(120)), address: $0.address, lat: $0.lat, lng: $0.lng)
                    }
                )
                let _: Trip = try await model.client().store("trips", method: "POST", body: body)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
