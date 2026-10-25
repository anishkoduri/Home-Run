import Foundation

enum Fees {
    static let formula = "$8 base + $0.50 per added minute"

    static func estimate(_ minutes: Double) -> Double {
        let raw = 8 + 0.5 * max(0, minutes)
        return ceil(raw * 2) / 2
    }

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.currency(code: "USD"))
    }
}

struct City: Identifiable, Hashable {
    var name: String
    var lat: Double
    var lng: Double
    var id: String { name }
}

struct MeetupPoint: Identifiable, Hashable {
    var id: String
    var label: String
    var detail: String
    var lat: Double
    var lng: Double
}

enum Places {
    static let origins: [City] = [
        City(name: "Houston", lat: 29.7604, lng: -95.3698),
        City(name: "Dallas–Fort Worth", lat: 32.8, lng: -97.0),
        City(name: "Austin", lat: 30.2672, lng: -97.7431),
        City(name: "San Antonio", lat: 29.4241, lng: -98.4936),
        City(name: "Waco", lat: 31.5493, lng: -97.1467),
    ]
    static let destination = City(name: "College Station", lat: 30.615, lng: -96.341)
    static let meetups: [MeetupPoint] = [
        MeetupPoint(id: "msc", label: "Memorial Student Center", detail: "Joe Routt Blvd entrance", lat: 30.6122, lng: -96.3416),
        MeetupPoint(id: "zachry", label: "Zachry Engineering Complex", detail: "Main entrance on Bizzell St", lat: 30.6211, lng: -96.3403),
        MeetupPoint(id: "evans", label: "Evans Library", detail: "Front steps", lat: 30.6171, lng: -96.3389),
        MeetupPoint(id: "commons", label: "The Commons", detail: "Northside, by the lobby doors", lat: 30.6152, lng: -96.3365),
        MeetupPoint(id: "northgate", label: "Northgate", detail: "University Dr & College Main", lat: 30.6197, lng: -96.3442),
        MeetupPoint(id: "rec", label: "Student Rec Center", detail: "Front circle drive", lat: 30.6075, lng: -96.3433),
    ]
}

enum Format {
    static func dayTime(_ iso: String) -> String {
        guard let date = parse(iso) else { return iso }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func time(_ iso: String) -> String {
        guard let date = parse(iso) else { return iso }
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func relative(_ iso: String) -> String {
        guard let date = parse(iso) else { return iso }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today · \(date.formatted(date: .omitted, time: .shortened))" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow · \(date.formatted(date: .omitted, time: .shortened))" }
        return dayTime(iso)
    }

    static func minutes(_ value: Double?) -> String {
        guard let value else { return "—" }
        let rounded = Int(value.rounded())
        if rounded < 60 { return "\(rounded) min" }
        return "\(rounded / 60) hr \(rounded % 60) min"
    }

    static func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    static func firstName(_ name: String?) -> String {
        personalName(name) ?? "there"
    }

    /// A spoken first name. Numeric ids and single characters stay off greetings.
    static func personalName(_ name: String?) -> String? {
        guard let raw = name?.split(separator: " ").first else { return nil }
        let word = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard word.count >= 2, word.contains(where: \.isLetter), !word.allSatisfy(\.isNumber) else { return nil }
        return word
    }

    static func shortId(_ id: String) -> String { "HR-\(id.prefix(4).uppercased())" }

    static func combine(day: Date, time: Date) -> String {
        let calendar = Calendar.current
        let dateParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        var parts = DateComponents()
        parts.year = dateParts.year
        parts.month = dateParts.month
        parts.day = dateParts.day
        parts.hour = timeParts.hour
        parts.minute = timeParts.minute
        let combined = calendar.date(from: parts) ?? day
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: combined)
    }

    static func parse(_ iso: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        for candidate in [iso, iso.replacingOccurrences(of: " ", with: "T")] {
            if let date = fractional.date(from: candidate) ?? plain.date(from: candidate) { return date }
            let shortened = trimFraction(candidate)
            if shortened != candidate, let date = fractional.date(from: shortened) ?? plain.date(from: shortened) {
                return date
            }
        }
        return nil
    }

    private static func trimFraction(_ iso: String) -> String {
        guard let dot = iso.firstIndex(of: ".") else { return iso }
        var index = iso.index(after: dot)
        var digits = 0
        while index < iso.endIndex, iso[index].isNumber {
            digits += 1
            index = iso.index(after: index)
        }
        guard digits > 3 else { return iso }
        let keep = iso.index(dot, offsetBy: 4)
        return String(iso[..<keep] + iso[index...])
    }
}

func initials(_ name: String?) -> String {
    let parts = (name ?? "?").split(separator: " ").prefix(2)
    let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
    return letters.isEmpty ? "?" : letters
}

enum Routing {
    static func estimate(client: APIClient, origin: LatLng, destination: LatLng, stops: [LatLng], restaurant: LatLng, dropoff: LatLng) async throws -> (DetourEstimate, String?) {
        let body = DetourBody(origin: origin, destination: destination, stops: stops, restaurant: restaurant, dropoff: dropoff)
        do {
            let estimate: DetourEstimate = try await client.geo("detour", method: "POST", body: body)
            return (estimate, nil)
        } catch let error as APIError where error.code == "unauthenticated" {
            throw error
        } catch {
            return (straightLine(body), (error as? LocalizedError)?.errorDescription ?? "Routing is unavailable.")
        }
    }

    private static func straightLine(_ input: DetourBody) -> DetourEstimate {
        let base = [input.origin] + input.stops + [input.destination]
        var best = Double.infinity
        var bestPath: [LatLng] = []
        let slots = input.stops.count + 1
        for index in 1 ... slots {
            let path = [input.origin] + Array(input.stops.prefix(index - 1)) + [input.restaurant] + Array(input.stops.dropFirst(index - 1)) + [input.dropoff, input.destination]
            let distance = pathKm(path)
            if distance < best { best = distance; bestPath = path }
        }
        let baseMinutes = minutes(pathKm(base))
        let withMinutes = minutes(best)
        return DetourEstimate(
            source: "straight_line",
            baseMinutes: rounded(baseMinutes),
            withMinutes: rounded(withMinutes),
            toDropoffMinutes: rounded(minutes(pathKm(Array(bestPath.dropLast())))),
            detourMinutes: rounded(max(0, withMinutes - baseMinutes)),
            baseKm: rounded(pathKm(base)),
            withKm: rounded(best),
            basePath: base.map { [$0.lat, $0.lng] },
            withPath: bestPath.map { [$0.lat, $0.lng] }
        )
    }

    private static func km(_ a: LatLng, _ b: LatLng) -> Double {
        let radius = 6371.0
        let rad = Double.pi / 180
        let dLat = (b.lat - a.lat) * rad
        let dLng = (b.lng - a.lng) * rad
        let h = pow(sin(dLat / 2), 2) + cos(a.lat * rad) * cos(b.lat * rad) * pow(sin(dLng / 2), 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }

    private static func pathKm(_ points: [LatLng]) -> Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + km($1.0, $1.1) }
    }

    private static func minutes(_ distance: Double) -> Double { ((distance * 1.3) / 80) * 60 }
    private static func rounded(_ value: Double) -> Double { (value * 10).rounded() / 10 }
}

func watch(_ load: () async -> Void) async {
    await load()
    while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(20))
        guard !Task.isCancelled else { return }
        await load()
    }
}

struct LatLng: Codable, Equatable {
    var lat: Double
    var lng: Double
}

private struct DetourBody: Encodable {
    var origin: LatLng
    var destination: LatLng
    var stops: [LatLng]
    var restaurant: LatLng
    var dropoff: LatLng
}
