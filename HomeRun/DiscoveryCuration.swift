import Foundation

/// Editorial browsing order. This is a product preference, not a popularity rank, a sponsorship, or a Google rating.
enum DiscoveryCuration {
    struct Preference: Equatable {
        var name: String
        /// Nil means any selected metro, and only when that metro's own results already include the business.
        var city: String?
        var categories: Set<String>
    }

    /// Edit recommendations here. A preference never inserts a place that the search did not return.
    static let preferences: [Preference] = [
        Preference(name: "Trader Joe's", city: nil, categories: ["groceries", "stores"]),
        Preference(name: "Aga's Restaurant & Catering", city: "Houston", categories: ["food"]),
    ]

    static func order(_ places: [Place], city: String, query: String, category: String) -> [Place] {
        let picks = matching(places, city: city, query: query, category: category)
        guard !picks.isEmpty else { return places }
        var rest = places
        var front: [Place] = []
        for pick in picks {
            if let index = rest.firstIndex(where: { $0.placeId == pick.placeId }) {
                front.append(rest.remove(at: index))
            }
        }
        return front + rest
    }

    static func promotedIDs(in places: [Place], city: String, query: String, category: String) -> Set<String> {
        Set(matching(places, city: city, query: query, category: category).map(\.placeId))
    }

    private static func matching(_ places: [Place], city: String, query: String, category: String) -> [Place] {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.isEmpty else { return [] }
        var chosen: [Place] = []
        for preference in preferences where applies(preference, city: city, category: category) {
            guard let place = places.first(where: { matches($0, preference) }) else { continue }
            if !chosen.contains(where: { $0.placeId == place.placeId }) {
                chosen.append(place)
            }
        }
        return chosen
    }

    private static func applies(_ preference: Preference, city: String, category: String) -> Bool {
        if let required = preference.city, required.caseInsensitiveCompare(city) != .orderedSame { return false }
        if category == "all" { return true }
        return preference.categories.contains(category)
    }

    private static func matches(_ place: Place, _ preference: Preference) -> Bool {
        if place.outsideCity == true { return false }
        let placeName = normalized(place.name)
        let preferenceName = normalized(preference.name)
        return placeName == preferenceName || placeName.hasPrefix(preferenceName + " ") || placeName.hasPrefix(preferenceName + "-")
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum CityPickerGate {
    /// Launch, tab changes, role changes, and dismissal never open the picker by themselves.
    static func opens(userTappedControl: Bool, actionNeedsCity: Bool, cityConfirmed: Bool) -> Bool {
        if userTappedControl { return true }
        return actionNeedsCity && !cityConfirmed
    }
}

enum TripCopy {
    static func requestsOpen(_ trip: Trip) -> String {
        let taken = trip.activeOrders ?? 0
        if taken >= trip.maxOrders { return "Requests closed" }
        return "Requests open"
    }

    static func pickupLimit(_ trip: Trip) -> String {
        "Pickup limit \(trip.activeOrders ?? 0) of \(trip.maxOrders)"
    }
}
