import Foundation

enum NetworkError: LocalizedError {
    case unauthorized
    case invalidUrl
    case httpError(Int, String?)
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired or unauthorized. Please log in again."
        case .invalidUrl:
            return "Invalid request URL."
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message ?? "No details")"
        case .invalidResponse:
            return "Invalid response received from server."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

final class ApiClient {
    static let shared = ApiClient()

    let baseUrl = "https://finance.cd-co.com.py"
    private let tokenStorage = KeychainTokenStorage.shared
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }

    func request<T: Decodable>(path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        try await request(method: "GET", path: path, queryItems: queryItems, body: Optional<EmptyBody>.none)
    }

    // Generic mutation entry point for every domain screen's create/update
    // (goals, budgets, receivables, products, sales, purchase_orders,
    // fleet_vehicles/fuel_logs, rules, tags, transactions, ...): one place
    // that encodes the body with the same snake_case convention the decoder
    // already expects back, and shares the 401/error handling with GET
    // instead of every call site reimplementing it slightly differently.
    @discardableResult
    func request<T: Decodable, Body: Encodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: Body?
    ) async throws -> T {
        guard var components = URLComponents(string: "\(baseUrl)\(path)") else {
            throw NetworkError.invalidUrl
        }
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidUrl
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = tokenStorage.accessToken(), !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(body)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            tokenStorage.clear()
            throw NetworkError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8)
            throw NetworkError.httpError(httpResponse.statusCode, errorBody)
        }

        // DELETE and some action endpoints (e.g. sales#cancel) return 204/an
        // empty body -- decoding EmptyResponse for those call sites skips
        // JSONDecoder entirely instead of failing on zero bytes.
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    // Convenience for mutations with no request body (POST .../complete,
    // .../cancel, .../receive, DELETE, etc.) -- avoids every call site
    // writing `body: Optional<EmptyBody>.none` by hand.
    @discardableResult
    func request<T: Decodable>(method: String, path: String, queryItems: [URLQueryItem]? = nil) async throws -> T {
        try await request(method: method, path: path, queryItems: queryItems, body: Optional<EmptyBody>.none)
    }
}

private struct EmptyBody: Encodable {}

// Decode target for endpoints whose success response has no meaningful body
// (204 No Content, or a body callers don't need) -- see the T.self ==
// EmptyResponse.self short-circuit above.
struct EmptyResponse: Decodable {}
