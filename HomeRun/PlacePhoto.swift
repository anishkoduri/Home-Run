import SwiftUI

/// Resolves a Places API (New) photo resource into bytes. Sample and missing photos use the branded mark.
struct PlacePhoto: View {
    var place: Place
    var side: CGFloat = 64

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Theme.tint
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if place.photoName == nil || failed {
                GroceryBagSketch()
            } else {
                ProgressView()
            }
        }
        .frame(width: side, height: side)
        .clipShape(InkCard())
        .overlay(InkCard().stroke(Theme.ink.opacity(0.55), lineWidth: 1.2))
        .accessibilityLabel(place.photoName == nil ? "No photo for \(place.name)" : "Photo of \(place.name)")
        .task(id: place.photoName) { await load() }
    }

    private func load() async {
        image = nil
        failed = false
        guard let name = place.photoName else { return }
        do {
            let data = try await PlaceSearch.shared.photoData(resourceName: name)
            guard !Task.isCancelled, let decoded = UIImage(data: data) else { return }
            image = decoded
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}

struct PlaceGallery: View {
    var place: Place
    @Environment(\.dismiss) private var dismiss

    private var names: [String] {
        if let photos = place.photoNames, !photos.isEmpty { return photos }
        if let photo = place.photoName { return [photo] }
        return []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if names.isEmpty {
                    GroceryBagSketch()
                    Text("No photo is available for \(place.name).")
                        .font(Theme.text(.body))
                        .foregroundStyle(Theme.muted)
                } else {
                    TabView {
                        ForEach(names, id: \.self) { name in
                            PlacePhoto(place: Place(placeId: place.placeId, name: place.name, address: place.address, lat: place.lat, lng: place.lng, photoName: name, photoCredit: place.photoCredit, contentSource: place.contentSource), side: 280)
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 320)
                }
                if let credit = place.photoCredit {
                    Text("Photo: \(credit)")
                        .font(Theme.text(.caption))
                        .foregroundStyle(Theme.muted)
                }
                Text(place.address).font(Theme.text(.caption)).foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(20)
            .homeRunPage(road: false)
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct PickupCityButton: View {
    var city: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pickup city")
                        .font(Theme.text(.caption, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    Text(city)
                        .font(Theme.section(.title3))
                        .foregroundStyle(Theme.ink)
                    Text("to College Station")
                        .font(Theme.text(.caption, weight: .semibold))
                        .foregroundStyle(Theme.maroon)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(Theme.text(.caption, weight: .bold))
                    .foregroundStyle(Theme.maroon)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pickup-city")
        .accessibilityLabel("Pickup city, \(city)")
        .accessibilityHint("Opens the city list")
    }
}

struct PickupCitySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var error: String?
    @State private var busy = false
    var onSelect: (String) -> Void

    private var matches: [City] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cities = Places.selectableCities
        guard !needle.isEmpty else { return cities }
        return cities.filter { $0.name.localizedCaseInsensitiveContains(needle) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(Theme.bad) }
                ForEach(matches) { city in
                    Button(city.name) {
                        onSelect(city.name)
                        dismiss()
                    }
                    .accessibilityIdentifier("pickup-city-option-\(city.name)")
                }
                if matches.isEmpty, query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                    Button(busy ? "Looking up…" : "Look up \(query) in Texas") {
                        Task { await lookup() }
                    }
                    .disabled(busy)
                }
            }
            .searchable(text: $query, prompt: "Any Texas city")
            .navigationTitle("Pickup city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func lookup() async {
        busy = true
        defer { busy = false }
        do {
            let city: City = try await model.client().geo("city", query: ["q": query])
            onSelect(city.name)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
