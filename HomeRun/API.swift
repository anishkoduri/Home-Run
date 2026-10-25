import Foundation

struct APIError: LocalizedError {
    var message: String
    var code: String?
    var errorDescription: String? { message }
}

struct APIClient {
    var baseURL: URL
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
        let data = try await send(path: "store", action: action, method: method, query: query, body: body, snakeBody: true)
        do { return try storeDecoder.decode(T.self, from: data) }
        catch { throw APIError(message: "The server sent a response the app couldn't read.") }
    }

    func geo<T: Decodable>(_ action: String, method: String = "GET", query: [String: String] = [:], body: (any Encodable)? = nil) async throws -> T {
        let data = try await send(path: "geo", action: action, method: method, query: query, body: body, snakeBody: false)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError(message: "The location service sent a response the app couldn't read.") }
    }

    private func send(path: String, action: String, method: String, query: [String: String], body: (any Encodable)?, snakeBody: Bool) async throws -> Data {
        guard var parts = URLComponents(url: baseURL.appending(path: "api").appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError(message: "That server address isn't a valid URL.")
        }
        var items = [URLQueryItem(name: "action", value: action)]
        items.append(contentsOf: query.map { URLQueryItem(name: $0.key, value: $0.value) })
        parts.queryItems = items
        guard let url = parts.url else { throw APIError(message: "That server address isn't a valid URL.") }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = try snakeBody ? storeEncoder.encode(AnyEncodable(body)) : JSONEncoder().encode(AnyEncodable(body))
        }

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError(message: "Can't reach Home Run. Check the server address and your connection.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200 ..< 300).contains(status) else {
            let failure = try? JSONDecoder().decode(FailureBody.self, from: responseData)
            throw APIError(message: failure?.error ?? "Request failed (\(status)).", code: failure?.code)
        }
        return responseData
    }
}

private struct FailureBody: Decodable { var error: String; var code: String? }

private struct AnyEncodable: Encodable {
    var value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
