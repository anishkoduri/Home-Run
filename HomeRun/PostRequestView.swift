import PhotosUI
import SwiftUI

/// Customer posts a pickup without choosing a runner. Open trips stay on Discover.
struct PostRequestView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var city: String
    var initialPlace: Place? = nil
    var startPersonal = false
    var dropoffLabel: String? = nil
    var dropoffLat: Double? = nil
    var dropoffLng: Double? = nil
    var dropoffType: String? = nil

    @State private var personal: Bool

    init(city: String, initialPlace: Place? = nil, startPersonal: Bool = false, dropoffLabel: String? = nil, dropoffLat: Double? = nil, dropoffLng: Double? = nil, dropoffType: String? = nil) {
        self.city = city
        self.initialPlace = initialPlace
        self.startPersonal = startPersonal
        self.dropoffLabel = dropoffLabel
        self.dropoffLat = dropoffLat
        self.dropoffLng = dropoffLng
        self.dropoffType = dropoffType
        _personal = State(initialValue: startPersonal)
    }
    @State private var seeded = false
    @State private var search = ""
    @State private var places: [Place] = []
    @State private var place: Place?
    @State private var details = ""
    @State private var quantity = ""
    @State private var weight = ""
    @State private var pickupAddress = ""
    @State private var unit = ""
    @State private var resolved: Place?
    @State private var addressNote = ""
    @State private var contact = ""
    @State private var access = ""
    @State private var window = "This afternoon"
    @State private var delivery = "Memorial Student Center"
    @State private var deliveryQuery = ""
    @State private var deliveryPlace: Place?
    @State private var seededDropoffLat: Double?
    @State private var seededDropoffLng: Double?
    @State private var seededDropoffLabel: String?
    @State private var seededDropoffType: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var attempted = false
    @State private var busy = false
    @State private var error: String?
    @State private var posted: Order?
    @FocusState private var focus: Field?

    enum Field: Hashable { case details, quantity, weight, address, unit, contact, access, delivery }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let posted {
                        Text("Request posted").font(Theme.brand(.title)).foregroundStyle(Theme.maroon)
                        Text("Awaiting a runner. The delivery fee is not final until you approve a runner's offer.")
                            .font(Theme.text(.subheadline))
                        Text(posted.itemSummary ?? "").font(Theme.text(.body))
                        PrimaryButton(title: "Done") { dismiss() }
                    } else {
                        Text(personal ? "Home or personal item" : "Order details")
                            .font(Theme.brand(.title2)).foregroundStyle(Theme.maroon)
                        Text(city).font(Theme.text(.subheadline)).foregroundStyle(Theme.muted)
                        if initialPlace == nil && !startPersonal {
                            ChoiceBar(options: [false, true], label: { $0 ? "Home or personal item" : "Restaurant or store" }, selection: $personal)
                        }
                        if personal {
                            addressBlock
                        } else if initialPlace != nil, let place {
                            Text(place.name).font(Theme.text(.headline, weight: .semibold))
                            Text(place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        } else {
                            merchantBlock
                        }
                        RequiredLabel(title: "Item description", required: true)
                        EntryField("Item description", text: $details, prompt: "What should be picked up", axis: .vertical, identifier: "request-details", focused: focus == .details)
                            .frame(minHeight: 88)
                            .padding(12)
                            .sketchPanel()
                            .id(Field.details)
                        RequiredLabel(title: "Quantity", required: true)
                        EntryField("Quantity", text: $quantity, prompt: "How many, and what it looks like", identifier: "request-quantity", focused: focus == .quantity)
                            .padding(12).sketchPanel().id(Field.quantity)
                        RequiredLabel(title: "Weight", required: false)
                        EntryField("Weight", text: $weight, prompt: "Pounds, or leave blank if unknown", keyboard: .decimalPad)
                            .padding(12).sketchPanel().focused($focus, equals: .weight)
                        RequiredLabel(title: "Contact name", required: true)
                        EntryField("Contact name", text: $contact, prompt: "Who will meet the runner", identifier: "request-contact", focused: focus == .contact)
                            .padding(12).sketchPanel().id(Field.contact)
                        RequiredLabel(title: "Access instructions", required: false)
                        EntryField("Access instructions", text: $access, prompt: "Gate, door, or where to meet", axis: .vertical)
                            .frame(minHeight: 72).padding(12).sketchPanel()
                        RequiredLabel(title: "Pickup window", required: true)
                        EntryField("Pickup window", text: $window, identifier: "request-window")
                            .padding(12).sketchPanel().id(Field.access)
                        RequiredLabel(title: "Delivery or meetup", required: true)
                        EntryField("Delivery or meetup", text: $delivery, prompt: "Campus meetup or street address", identifier: "request-delivery", focused: focus == .delivery)
                            .padding(12).sketchPanel().id(Field.delivery)
                        Button("Find delivery address") { Task { await findDelivery() } }
                            .font(Theme.text(.caption, weight: .semibold))
                        if let deliveryPlace {
                            Text(deliveryPlace.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("Add an item photo").font(Theme.text(.body, weight: .semibold))
                        }
                        Text(priceLine)
                            .font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                        if let error { ErrorBanner(message: error) }
                        if attempted, let first = invalid {
                            Text(first.message).font(Theme.text(.caption)).foregroundStyle(Theme.bad)
                        }
                        PrimaryButton(title: personal ? "Post home pickup" : "Post request", busy: busy) { Task { await submit(proxy) } }
                            .accessibilityIdentifier("post-pickup-submit")
                    }
                }
                .padding(20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .homeRunPage(road: false)
        .navigationTitle(personal ? "Home or personal item" : "Order details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !seeded else { return }
            seeded = true
            personal = startPersonal
            if let initialPlace {
                place = initialPlace
                search = initialPlace.name
                pickupAddress = initialPlace.address
                resolved = initialPlace
            }
            if let dropoffLabel {
                delivery = dropoffLabel
                seededDropoffLabel = dropoffLabel
                seededDropoffLat = dropoffLat
                seededDropoffLng = dropoffLng
                seededDropoffType = dropoffType
            }
        }
    }

    private var merchantBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            RequiredLabel(title: "Restaurant or store", required: true)
            EntryField("Restaurant or store", text: $search, prompt: "Search \(city)", identifier: "request-place")
                .padding(12).sketchPanel()
            Button("Search") { Task { await searchPlaces() } }.font(Theme.text(.body, weight: .semibold))
            if let place {
                Text(place.name).font(Theme.text(.headline, weight: .semibold))
                Text(place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
            ForEach(places.prefix(6)) { item in
                Button(item.name) { place = item; pickupAddress = item.address; resolved = item }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            RequiredLabel(title: "Pickup street address", required: true)
            EntryField("Pickup street address", text: $pickupAddress, prompt: "Street address in \(city)", identifier: "request-address", focused: focus == .address)
                .padding(12).sketchPanel().id(Field.address)
            RequiredLabel(title: "Apartment or unit", required: false)
            EntryField("Apartment or unit", text: $unit, prompt: "Apt, suite, or unit")
                .padding(12).sketchPanel().focused($focus, equals: .unit)
            Button("Find address") { Task { await findPickup() } }
                .font(Theme.text(.body, weight: .semibold))
                .accessibilityIdentifier("find-pickup-address")
            if let resolved {
                Text(resolved.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
            if !addressNote.isEmpty {
                Text(addressNote).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
            }
        }
    }

    private var priceLine: String {
        let pounds = Double(weight.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 8
        if let priced = RequestRanking.quoted(meters: RequestRanking.preliminaryMeters, seconds: RequestRanking.preliminarySeconds, pounds: pounds, bulky: false) {
            return "About \(Fees.money(Double(priced.customer) / 100)). That is a short local estimate plus 15%. A nearby runner can change the distance part. No card is charged."
        }
        return "The delivery price is the runner's extra time and distance, plus 15%. No card is charged."
    }

    private var invalid: (field: Field, message: String)? {
        if details.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            return (.details, "Describe the item.")
        }
        if quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (.quantity, "Add a quantity.")
        }
        if personal && pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).count < 4 {
            return (.address, "Add the pickup street address.")
        }
        if !personal && place == nil {
            return (.details, "Choose a restaurant or store.")
        }
        if contact.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return (.contact, "Add a contact name.")
        }
        if window.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (.access, "Add a pickup window.")
        }
        if delivery.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            return (.delivery, "Add a delivery meetup or address.")
        }
        return nil
    }

    private func searchPlaces() async {
        do {
            let response: PlaceSearchResponse = try await model.client().geo("places", query: ["city": city, "q": search])
            places = response.places
            error = places.isEmpty ? "No places matched that search." : nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func findPickup() async {
        await resolve(pickupAddress, city: city) { found in
            resolved = found
            if let found { pickupAddress = found.address }
            addressNote = found == nil ? "That address wasn't confirmed. You can edit it and try again. A precise route quote waits until it is confirmed." : ""
        }
    }

    private func findDelivery() async {
        let query = deliveryQuery.isEmpty ? delivery : deliveryQuery
        await resolve(query, city: "College Station") { deliveryPlace = $0 }
    }

    private func resolve(_ query: String, city: String, apply: (Place?) -> Void) async {
        do {
            let response: PlaceSearchResponse = try await model.client().geo("geocode", query: ["city": city, "q": query])
            apply(response.places.first)
            if response.places.isEmpty { error = "No matching address yet. Your text is still here." }
        } catch {
            apply(nil)
            self.error = error.localizedDescription
        }
    }

    private func submit(_ proxy: ScrollViewProxy) async {
        attempted = true
        if let invalid {
            focus = invalid.field
            withAnimation { proxy.scrollTo(invalid.field, anchor: .center) }
            error = invalid.message
            return
        }
        let pickup = place ?? resolved
        let resolvedLocation = pickup != nil && (personal ? resolved != nil : true)
        if personal && resolved == nil {
            addressNote = "Posted for review without a confirmed map point. A runner cannot lock a route price until the address is confirmed."
        }
        busy = true
        defer { busy = false }
        let pounds = Double(weight.trimmingCharacters(in: .whitespacesAndNewlines))
        let body = PostBody(
            restaurantName: personal ? "Personal item" : (place?.name ?? "Pickup"),
            restaurantAddress: personal ? pickupAddress : (place?.address ?? pickupAddress),
            restaurantLat: pickup?.lat ?? Places.city(named: city)?.lat ?? Places.destination.lat,
            restaurantLng: pickup?.lng ?? Places.city(named: city)?.lng ?? Places.destination.lng,
            restaurantPlaceId: pickup?.placeId ?? "",
            placeSource: pickup?.contentSource ?? "sample",
            destinationType: deliveryPlace == nil ? (delivery == seededDropoffLabel ? (seededDropoffType ?? "campus") : "campus") : "address",
            destinationLabel: delivery,
            destinationLat: deliveryPlace?.lat ?? (delivery == seededDropoffLabel ? seededDropoffLat : nil) ?? Places.destination.lat,
            destinationLng: deliveryPlace?.lng ?? (delivery == seededDropoffLabel ? seededDropoffLng : nil) ?? Places.destination.lng,
            pickupKind: personal ? "personal" : "merchant",
            requestText: details,
            itemQuantity: quantity,
            contactLabel: contact,
            accessInstructions: access,
            pickupWindow: window,
            pickupCity: city,
            pickupUnit: unit,
            locationResolved: resolvedLocation,
            operationKey: UUID().uuidString,
            weightPounds: pounds,
            weightConfirmed: pounds == nil ? nil : true
        )
        do {
            let order: Order = try await model.client().store("orders", method: "POST", body: body)
            posted = order
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct PostBody: Encodable {
    var restaurantName: String
    var restaurantAddress: String
    var restaurantLat: Double
    var restaurantLng: Double
    var restaurantPlaceId: String
    var placeSource: String
    var destinationType: String
    var destinationLabel: String
    var destinationLat: Double
    var destinationLng: Double
    var pickupKind: String
    var requestText: String
    var itemQuantity: String
    var contactLabel: String
    var accessInstructions: String
    var pickupWindow: String
    var pickupCity: String
    var pickupUnit: String
    var locationResolved: Bool
    var operationKey: String
    var weightPounds: Double?
    var weightConfirmed: Bool?
}
