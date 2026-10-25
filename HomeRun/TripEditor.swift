import SwiftUI

struct TripEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var trip: Trip
    var onSaved: () -> Void

    @State private var origin: String
    @State private var departure: Date
    @State private var hasCutoff: Bool
    @State private var cutoff: Date
    @State private var hasEta: Bool
    @State private var eta: Date
    @State private var spots: Int
    @State private var detourMinutes: Double
    @State private var detourMiles: Double
    @State private var itemPounds: Double
    @State private var totalPounds: Double
    @State private var allowsCustom: Bool
    @State private var notes: String
    @State private var stops: [TripStop]
    @State private var newStop = ""
    @State private var updateSeries: Bool
    @State private var error: String?
    @State private var busy = false

    init(trip: Trip, onSaved: @escaping () -> Void) {
        self.trip = trip
        self.onSaved = onSaved
        let departure = Format.parse(trip.departureAt) ?? DemoClock.now.addingTimeInterval(3_600)
        _origin = State(initialValue: trip.originCity)
        _departure = State(initialValue: departure)
        _hasCutoff = State(initialValue: trip.cutoffAt != nil)
        _cutoff = State(initialValue: trip.cutoffAt.flatMap(Format.parse) ?? departure.addingTimeInterval(-3_600))
        _hasEta = State(initialValue: trip.etaAt != nil)
        _eta = State(initialValue: trip.etaAt.flatMap(Format.parse) ?? departure.addingTimeInterval(3_600))
        _spots = State(initialValue: trip.maxOrders)
        _detourMinutes = State(initialValue: trip.maxDetourMinutes ?? 30)
        _detourMiles = State(initialValue: trip.maxDetourMiles ?? 15)
        _itemPounds = State(initialValue: trip.maxItemPounds ?? 50)
        _totalPounds = State(initialValue: trip.maxTotalPounds ?? 50)
        _allowsCustom = State(initialValue: trip.allowsCustom ?? false)
        _notes = State(initialValue: trip.notes ?? "")
        _stops = State(initialValue: trip.stops ?? [])
        _updateSeries = State(initialValue: false)
    }

    private var locked: Bool { (trip.activeOrders ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if trip.templateId != nil {
                        Text("This date only. The original trip and its other dates stay as they are.")
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                    } else if locked {
                        Text("Accepted pickups keep the city, time, and limits. Notes and extra stops can still change.")
                            .font(Theme.text(.caption))
                            .foregroundStyle(Theme.muted)
                    }
                    Picker("Driving from", selection: $origin) {
                        ForEach(Places.selectableCities) { Text($0.name).tag($0.name) }
                    }
                    .disabled(locked || trip.templateId != nil)
                    LabeledContent("To") { Text("College Station") }
                    DatePicker("Departure", selection: $departure)
                        .disabled(locked)
                    Toggle("Cutoff before departure", isOn: $hasCutoff).disabled(locked)
                    if hasCutoff { DatePicker("Cutoff", selection: $cutoff).disabled(locked) }
                    Toggle("Arrival estimate", isOn: $hasEta).disabled(locked)
                    if hasEta { DatePicker("Arrival", selection: $eta).disabled(locked) }
                    Stepper("Pickup limit: \(spots)", value: $spots, in: 1...6)
                    Stepper("Extra minutes: \(Int(detourMinutes))", value: $detourMinutes, in: 0...120, step: 5).disabled(locked)
                    Stepper("Extra miles: \(Int(detourMiles))", value: $detourMiles, in: 0...80, step: 1).disabled(locked)
                    Stepper("Item limit: \(Int(itemPounds)) lb", value: $itemPounds, in: 1...80, step: 1).disabled(locked)
                    Stepper("Total limit: \(Int(totalPounds)) lb", value: $totalPounds, in: 1...120, step: 1).disabled(locked)
                    Toggle("Custom items allowed", isOn: $allowsCustom).disabled(locked)
                    EntryField("Notes", text: $notes, axis: .vertical).padding(12).sketchPanel()
                    Text("Planned stops").font(Theme.section())
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.restaurantName).font(Theme.text(.body, weight: .semibold))
                            EntryField("Timing", text: binding(for: index, \.arrivesAt))
                                .font(Theme.text(.caption))
                            HStack {
                                Button("Up") { move(index, -1) }.disabled(index == 0)
                                Button("Down") { move(index, 1) }.disabled(index == stops.count - 1)
                                Button("Remove") { stops.remove(at: index) }.foregroundStyle(Theme.bad)
                            }
                            .font(Theme.text(.caption, weight: .semibold))
                        }
                        .padding(8)
                        .sketchPanel()
                    }
                    EntryField("Add a stop name", text: $newStop).padding(12).sketchPanel()
                    Button("Add stop") { addStop() }
                        .font(Theme.text(.body, weight: .semibold))
                        .disabled(newStop.trimmingCharacters(in: .whitespaces).isEmpty || stops.count >= 8)
                    if trip.templateId == nil, trip.recurrence != nil {
                        Toggle("Also update future dates that have not been edited", isOn: $updateSeries)
                    }
                    if let error { ErrorBanner(message: error) }
                    PrimaryButton(title: "Save trip", busy: busy) { Task { await save() } }
                }
                .padding(20)
            }
            .homeRunPage(road: true)
            .environment(\.onTheRoad, true)
            .toolbarBackground(Theme.runnerPaper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle(trip.templateId == nil ? "Edit trip" : "Edit this date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func binding(for index: Int, _ key: WritableKeyPath<TripStop, String?>) -> Binding<String> {
        Binding(
            get: { stops[index][keyPath: key] ?? "" },
            set: { stops[index][keyPath: key] = $0.isEmpty ? nil : $0 }
        )
    }

    private func move(_ index: Int, _ delta: Int) {
        let next = index + delta
        guard stops.indices.contains(next) else { return }
        stops.swapAt(index, next)
    }

    private func addStop() {
        let name = newStop.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let city = Places.city(named: origin)
        stops.append(TripStop(
            id: UUID().uuidString,
            tripId: trip.id,
            placeId: nil,
            restaurantName: name,
            address: nil,
            lat: (city?.lat ?? trip.originLat) + Double(stops.count + 1) * 0.01,
            lng: city?.lng ?? trip.originLng,
            stopOrder: stops.count,
            kind: "pickup",
            available: true,
            arrivesAt: nil
        ))
        newStop = ""
    }

    private func save() async {
        busy = true
        defer { busy = false }
        let formatter = ISO8601DateFormatter()
        let body = TripEditBody(
            notes: notes,
            maxOrders: spots,
            originCity: origin,
            departureAt: formatter.string(from: departure),
            cutoffAt: hasCutoff ? formatter.string(from: cutoff) : nil,
            etaAt: hasEta ? formatter.string(from: eta) : nil,
            maxDetourMinutes: detourMinutes,
            maxDetourMiles: detourMiles,
            maxItemPounds: itemPounds,
            maxTotalPounds: totalPounds,
            allowsCustom: allowsCustom,
            stops: stops.enumerated().map { index, stop in
                StopEditBody(id: stop.id, placeId: stop.placeId, restaurantName: stop.restaurantName, address: stop.address, lat: stop.lat, lng: stop.lng, kind: stop.kind ?? "pickup", available: stop.available ?? true, arrivesAt: stop.arrivesAt)
            },
            scope: updateSeries ? "series" : "occurrence"
        )
        do {
            let _: OkayBody = try await model.client().store("trips", method: "PATCH", query: ["id": trip.id], body: body)
            onSaved()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct TripEditBody: Encodable {
    var notes: String
    var maxOrders: Int
    var originCity: String
    var departureAt: String
    var cutoffAt: String?
    var etaAt: String?
    var maxDetourMinutes: Double
    var maxDetourMiles: Double
    var maxItemPounds: Double
    var maxTotalPounds: Double
    var allowsCustom: Bool
    var stops: [StopEditBody]
    var scope: String
}

private struct StopEditBody: Encodable {
    var id: String?
    var placeId: String?
    var restaurantName: String
    var address: String?
    var lat: Double
    var lng: Double
    var kind: String?
    var available: Bool?
    var arrivesAt: String?
}

private struct OkayBody: Decodable { var ok: Bool }
