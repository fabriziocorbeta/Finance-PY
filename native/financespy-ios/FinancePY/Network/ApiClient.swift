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
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = tokenStorage.accessToken(), !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
