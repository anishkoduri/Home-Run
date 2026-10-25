import Foundation

actor PlaceSearch {
    static let shared = PlaceSearch()

    private var cache: [String: (at: Date, value: Data)] = [:]

    func search(query: String, city: String, restaurantsOnly: Bool) async throws -> PlaceSearchResponse {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2, q.count <= 80 else { throw APIError(message: "Enter 2–80 characters.", code: "bad_request") }
        let key = "\(restaurantsOnly)|\(city)|\(q.lowercased())"
        if let hit = cache[key], Date().timeIntervalSince(hit.at) < 30 * 60,
           let cached = try? JSONDecoder().decode(PlaceSearchResponse.self, from: hit.value) {
            return cached
        }
        let text = restaurantsOnly ? "\(q) in \(city), TX" : "\(q), \(city), TX"
        let bias = Self.bias(for: city)
        var response: PlaceSearchResponse?
        if let key = Self.googleKey {
            response = try? await Self.google(text: text, bias: bias, key: key)
            if response?.places.isEmpty == true { response = nil }
        }
        if response == nil {
            response = try await Self.openStreetMap(text: text, bias: bias, restaurantsOnly: restaurantsOnly)
        }
        let data = try JSONEncoder().encode(response)
        cache[key] = (Date(), data)
        return response ?? PlaceSearchResponse(source: "osm", places: [])
    }

    func detour(_ body: DetourRequest) async throws -> DetourEstimate {
        let stops = Array(body.stops.prefix(8))
        let points = [body.origin, body.destination, body.restaurant, body.dropoff] + stops
        guard points.allSatisfy({ abs($0.lat) <= 90 && abs($0.lng) <= 180 }) else {
            throw APIError(message: "Missing or invalid coordinates.", code: "bad_request")
        }
        async let base = route([body.origin] + stops + [body.destination])
        async let toDropoff = route([body.origin] + stops + [body.restaurant, body.dropoff])
        async let finish = route([body.dropoff, body.destination])
        let legs = try await (base, toDropoff, finish)
        let withMinutes = legs.1.minutes + legs.2.minutes
        let source = [legs.0.source, legs.1.source, legs.2.source].contains("osrm") ? "osrm" : "google"
        return DetourEstimate(
            source: source,
            baseMinutes: Self.oneDecimal(legs.0.minutes),
            withMinutes: Self.oneDecimal(withMinutes),
            toDropoffMinutes: Self.oneDecimal(legs.1.minutes),
            detourMinutes: Self.oneDecimal(max(0, withMinutes - legs.0.minutes)),
            baseKm: Self.oneDecimal(legs.0.km),
            withKm: Self.oneDecimal(legs.1.km + legs.2.km),
            basePath: Self.thin(legs.0.path),
            withPath: Self.thin(legs.1.path + legs.2.path)
        )
    }

    private func route(_ points: [LatLng]) async throws -> Leg {
        guard points.count >= 2 else { throw APIError(message: "No driving route found.", code: "no_route") }
        if let key = Self.googleKey, let leg = try? await Self.googleRoute(points, key: key) { return leg }
        return try await Self.osrm(points)
    }

    private static func google(text: String, bias: CityBias?, key: String) async throws -> PlaceSearchResponse {
        var payload: [String: Any] = ["textQuery": text, "pageSize": 20, "regionCode": "US"]
        if let bias {
            payload["locationBias"] = [
                "circle": [
                    "center": ["latitude": bias.lat, "longitude": bias.lng],
                    "radius": bias.radius,
                ],
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places:searchText")!)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.websiteUri,places.googleMapsUri", forHTTPHeaderField: "X-Goog-FieldMask")
        let (response, raw) = try await URLSession.shared.data(for: request)
        guard let http = raw as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "Google Places is unavailable right now.", code: "provider_error")
        }
        let decoded = try JSONDecoder().decode(GooglePlaces.self, from: response)
        let places = (decoded.places ?? []).compactMap { place -> Place? in
            guard let lat = place.location?.latitude, let lng = place.location?.longitude else { return nil }
            let website = place.websiteUri.flatMap { $0.hasPrefix("http://") || $0.hasPrefix("https://") ? $0 : nil }
            return Place(
                placeId: place.id,
                name: place.displayName?.text ?? "Unnamed place",
                address: place.formattedAddress ?? "",
                lat: lat,
                lng: lng,
                rating: place.rating,
                ratingCount: place.userRatingCount,
                website: website,
                mapsUrl: place.googleMapsUri
            )
        }
        return PlaceSearchResponse(source: "google", places: places)
    }

    private static func openStreetMap(text: String, bias: CityBias?, restaurantsOnly: Bool) async throws -> PlaceSearchResponse {
        func ask(bounded: Bool) async throws -> [[String: Any]] {
            var parts = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
            var items = [
                URLQueryItem(name: "q", value: text),
                URLQueryItem(name: "format", value: "jsonv2"),
                URLQueryItem(name: "limit", value: "20"),
                URLQueryItem(name: "countrycodes", value: "us"),
                URLQueryItem(name: "extratags", value: "1"),
            ]
            if let bias {
                let dLat = (bias.radius / 1000) / 111
                let dLng = (bias.radius / 1000) / (111 * cos(bias.lat * .pi / 180))
                items.append(URLQueryItem(name: "viewbox", value: "\(bias.lng - dLng),\(bias.lat + dLat),\(bias.lng + dLng),\(bias.lat - dLat)"))
                items.append(URLQueryItem(name: "bounded", value: bounded ? "1" : "0"))
            }
            parts.queryItems = items
            var request = URLRequest(url: parts.url!)
            request.setValue("HomeRun/1.0 (student food delivery)", forHTTPHeaderField: "User-Agent")
            request.setValue("en", forHTTPHeaderField: "Accept-Language")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                throw APIError(message: "Place search is unavailable right now.", code: "provider_error")
            }
            return rows
        }
        var rows = try await ask(bounded: bias != nil)
        if rows.isEmpty, bias != nil { rows = try await ask(bounded: false) }
        let food: Set<String> = ["restaurant", "fast_food", "cafe", "food_court", "ice_cream", "bakery", "deli", "pub", "bar", "biergarten"]
        let matched = rows.filter { !restaurantsOnly || food.contains($0["type"] as? String ?? "") }
        let chosen = (matched.isEmpty ? rows : matched).prefix(20)
        let places = chosen.compactMap { row -> Place? in
            guard let lat = Double(row["lat"] as? String ?? ""), let lng = Double(row["lon"] as? String ?? "") else { return nil }
            let display = row["display_name"] as? String ?? ""
            let name = (row["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? display.split(separator: ",").first.map(String.init) ?? "Place"
            let tags = row["extratags"] as? [String: Any]
            let site = (tags?["website"] as? String) ?? (tags?["contact:website"] as? String)
            let website = site.flatMap { $0.hasPrefix("http://") || $0.hasPrefix("https://") ? $0 : nil }
            let osmType = row["osm_type"] as? String ?? "node"
            let osmId = row["osm_id"].map { "\($0)" } ?? UUID().uuidString
            return Place(
                placeId: "osm:\(osmType.prefix(1))\(osmId)",
                name: name,
                address: display.split(separator: ",").dropFirst(name == display ? 0 : 1).prefix(4).joined(separator: ","),
                lat: lat,
                lng: lng,
                rating: nil,
                ratingCount: nil,
                website: website,
                mapsUrl: "https://www.openstreetmap.org/\(osmType)/\(osmId)"
            )
        }
        return PlaceSearchResponse(source: "osm", places: places)
    }

    private static func googleRoute(_ points: [LatLng], key: String) async throws -> Leg {
        func waypoint(_ point: LatLng) -> [String: Any] {
            ["location": ["latLng": ["latitude": point.lat, "longitude": point.lng]]]
        }
        let intermediates = points.dropFirst().dropLast().map(waypoint)
        let payload: [String: Any] = [
            "origin": waypoint(points[0]),
            "destination": waypoint(points[points.count - 1]),
            "intermediates": intermediates,
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_UNAWARE",
        ]
        var request = URLRequest(url: URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline", forHTTPHeaderField: "X-Goog-FieldMask")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "Google routing is unavailable right now.", code: "provider_error")
        }
        let decoded = try JSONDecoder().decode(GoogleRoutes.self, from: data)
        guard let route = decoded.routes?.first, let encoded = route.polyline?.encodedPolyline else {
            throw APIError(message: "No driving route found.", code: "no_route")
        }
        let seconds = Double(route.duration?.replacingOccurrences(of: "s", with: "") ?? "") ?? 0
        return Leg(minutes: seconds / 60, km: Double(route.distanceMeters ?? 0) / 1000, path: decode(encoded), source: "google")
    }

    private static func osrm(_ points: [LatLng]) async throws -> Leg {
        let coords = points.map { "\($0.lng),\($0.lat)" }.joined(separator: ";")
        let url = URL(string: "https://router.project-osrm.org/route/v1/driving/\(coords)?overview=simplified&geometries=geojson")!
        var request = URLRequest(url: url)
        request.setValue("HomeRun/1.0 (student food delivery)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["code"] as? String == "Ok",
              let route = (json["routes"] as? [[String: Any]])?.first,
              let duration = route["duration"] as? Double,
              let distance = route["distance"] as? Double,
              let geometry = route["geometry"] as? [String: Any],
              let coordinates = geometry["coordinates"] as? [[Double]] else {
            throw APIError(message: "No driving route found.", code: "no_route")
        }
        let path = coordinates.compactMap { pair -> [Double]? in
            guard pair.count == 2 else { return nil }
            return [pair[1], pair[0]]
        }
        return Leg(minutes: duration / 60, km: distance / 1000, path: path, source: "osrm")
    }

    private static func decode(_ polyline: String) -> [[Double]] {
        var path: [[Double]] = []
        var index = polyline.startIndex
        var lat = 0
        var lng = 0
        while index < polyline.endIndex {
            for which in 0...1 {
                var shift = 0
                var result = 0
                var byte = 0
                repeat {
                    byte = Int(polyline[index].asciiValue ?? 63) - 63
                    index = polyline.index(after: index)
                    result |= (byte & 0x1f) << shift
                    shift += 5
                } while byte >= 0x20 && index < polyline.endIndex
                let delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
                if which == 0 { lat += delta } else { lng += delta }
            }
            path.append([Double(lat) / 1e5, Double(lng) / 1e5])
        }
        return path
    }

    private static func bias(for city: String) -> CityBias? {
        if let match = Places.origins.first(where: { $0.name == city }) {
            return CityBias(lat: match.lat, lng: match.lng, radius: 45_000)
        }
        if city == Places.destination.name {
            return CityBias(lat: Places.destination.lat, lng: Places.destination.lng, radius: 15_000)
        }
        return nil
    }

    private static var googleKey: String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private static func thin(_ path: [[Double]], max: Int = 120) -> [[Double]] {
        guard path.count > max else { return path }
        let step = Double(path.count - 1) / Double(max - 1)
        return (0..<max).map { path[Int((Double($0) * step).rounded())] }
    }

    private static func oneDecimal(_ value: Double) -> Double { (value * 10).rounded() / 10 }
}

struct DetourRequest: Codable {
    var origin: LatLng
    var destination: LatLng
    var stops: [LatLng]
    var restaurant: LatLng
    var dropoff: LatLng
}

private struct CityBias {
    var lat: Double
    var lng: Double
    var radius: Double
}

private struct Leg {
    var minutes: Double
    var km: Double
    var path: [[Double]]
    var source: String
}

private struct GooglePlaces: Decodable {
    var places: [GooglePlace]?
}

private struct GooglePlace: Decodable {
    var id: String
    var displayName: GoogleText?
    var formattedAddress: String?
    var location: GoogleLocation?
    var rating: Double?
    var userRatingCount: Int?
    var websiteUri: String?
    var googleMapsUri: String?
}

private struct GoogleText: Decodable { var text: String? }
private struct GoogleLocation: Decodable { var latitude: Double; var longitude: Double }

private struct GoogleRoutes: Decodable { var routes: [GoogleRoute]? }
private struct GoogleRoute: Decodable {
    var duration: String?
    var distanceMeters: Int?
    var polyline: GooglePolyline?
}
private struct GooglePolyline: Decodable { var encodedPolyline: String? }
