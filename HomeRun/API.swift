import Foundation

struct APIError: LocalizedError {
    var message: String
    var code: String?
    var errorDescription: String? { message }
}

struct APIClient {
    var token: String?

    private let storeDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let storeEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    func store<T: Decodable>(_ action: String, method: String = "GET", query: [String: String] = [:], body: (any Encodable)? = nil) async throws -> T {
        let payload = try body.map { try storeEncoder.encode(AnyEncodable($0)) }
        let data = try await AppDatabase.shared.perform(action: action, method: method, query: query, body: payload, token: token)
        do { return try storeDecoder.decode(T.self, from: data) }
        catch { throw APIError(message: "Home Run couldn't read that response.") }
    }

    func geo<T: Decodable>(_ action: String, method: String = "GET", query: [String: String] = [:], body: (any Encodable)? = nil) async throws -> T {
        let data: Data
        if action == "places" || action == "geocode" {
            let response = try await PlaceSearch.shared.search(
                query: query["q"] ?? "",
                city: query["city"] ?? Places.destination.name,
                restaurantsOnly: action == "places",
                category: query["category"] ?? "all"
            )
            data = try JSONEncoder().encode(response)
        } else if action == "city" {
            let city = try await PlaceSearch.shared.lookupTexasCity(query["q"] ?? "")
            data = try JSONEncoder().encode(city)
        } else if action == "detour" {
            let payload = try JSONEncoder().encode(AnyEncodable(body ?? EmptyBody()))
            let request = try JSONDecoder().decode(DetourRequest.self, from: payload)
            data = try JSONEncoder().encode(try await PlaceSearch.shared.detour(request))
        } else {
            throw APIError(message: "Unknown action", code: "not_found")
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError(message: "The location service sent a response the app couldn't read.") }
    }
}

private struct EmptyBody: Encodable {}

private struct AnyEncodable: Encodable {
    var value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
