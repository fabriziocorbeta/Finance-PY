import Foundation

enum NetworkError: LocalizedError {
    case unauthorized
    case invalidUrl
    case httpError(Int, String?)
    case invalidResponse
    case decodingError(Error)

    // Most screens render error.localizedDescription as-is, so this must be
    // user-facing Spanish -- never the raw "HTTP error 403: {json}" body.
    var errorDescription: String? {
        UserFacingError.message(for: self)
    }
}

// The one place that turns a thrown error (or a chat's stored failure) into
// Spanish text a user can act on.
enum UserFacingError {
    static let assistantDisabled = "El asistente IA no está activado para tu cuenta. Activalo desde Ajustes en la versión web."
    static let assistantBusy = "El asistente está ocupado. Probá de nuevo en unos minutos."
    static let serverBusy = "El servidor está ocupado. Probá de nuevo en unos minutos."
    static let sessionExpired = "Tu sesión expiró. Volvé a iniciar sesión."
    static let offline = "No hay conexión a internet. Revisá tu conexión y probá de nuevo."
    static let forbidden = "No tenés permiso para hacer esto."
    static let generic = "Algo salió mal. Probá de nuevo en unos minutos."

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .timedOut,
        .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
        .dataNotAllowed, .internationalRoamingOff
    ]

    /// `assistant: true` words "busy" responses as the AI assistant being busy.
    static func message(for error: Error, assistant: Bool = false) -> String {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return sessionExpired
            case .httpError(let status, let body):
                return message(status: status, body: body, assistant: assistant)
            case .invalidUrl, .invalidResponse, .decodingError:
                return generic
            }
        }
        if let urlError = error as? URLError {
            return offlineCodes.contains(urlError.code) ? offline : generic
        }
        return (error as? LocalizedError)?.errorDescription ?? generic
    }

    /// Text for a chat's `error` field: the server already sends the friendly
    /// message, but if it ever arrives as the stored JSON payload, only its
    /// "message" is shown (never "technical_message").
    static func chatFailure(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        guard raw.hasPrefix("{") else { return raw }
        let payload = raw.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        if let message = payload?["message"] as? String, !message.isEmpty {
            return message
        }
        return generic
    }

    private static func message(status: Int, body: String?, assistant: Bool) -> String {
        let payload = body?.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }

        switch status {
        case 401:
            return sessionExpired
        case 403:
            return payload?["error"] as? String == "feature_disabled" ? assistantDisabled : forbidden
        case 422:
            // Rails validation messages ("details") are already localized and actionable.
            let details = (payload?["details"] as? [String])?.filter { !$0.isEmpty } ?? []
            return details.isEmpty ? generic : details.joined(separator: "\n")
        case 429, 502, 503, 504:
            return assistant ? assistantBusy : serverBusy
        default:
            return generic
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
        do {
            return try await performRequest(method: method, path: path, queryItems: queryItems, body: body)
        } catch NetworkError.unauthorized {
            do {
                try await AuthRepository.shared.refreshAccessToken()
            } catch {
                tokenStorage.clear()
                throw NetworkError.unauthorized
            }
            return try await performRequest(method: method, path: path, queryItems: queryItems, body: body)
        }
    }

    private func performRequest<T: Decodable, Body: Encodable>(
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
            DecodingDiagnostics.log(error, type: T.self, path: path)
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

    // multipart/form-data upload (imports: PDF statements, Upay CSVs, ...).
    // Separate from request(...) because none of the JSON call sites need
    // this, and encoding a file inside a Codable body isn't a good fit for
    // the shared JSONEncoder path above.
    func uploadMultipart<T: Decodable>(
        path: String,
        fields: [String: String],
        fileField: String,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> T {
        do {
            return try await performUploadMultipart(
                path: path,
                fields: fields,
                fileField: fileField,
                fileData: fileData,
                fileName: fileName,
                mimeType: mimeType
            )
        } catch NetworkError.unauthorized {
            do {
                try await AuthRepository.shared.refreshAccessToken()
            } catch {
                tokenStorage.clear()
                throw NetworkError.unauthorized
            }
            return try await performUploadMultipart(
                path: path,
                fields: fields,
                fileField: fileField,
                fileData: fileData,
                fileName: fileName,
                mimeType: mimeType
            )
        }
    }

    private func performUploadMultipart<T: Decodable>(
        path: String,
        fields: [String: String],
        fileField: String,
        fileData: Data,
        fileName: String,
        mimeType: String
    ) async throws -> T {
        guard let url = URL(string: "\(baseUrl)\(path)") else {
            throw NetworkError.invalidUrl
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = tokenStorage.accessToken(), !token.isEmpty {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
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
            DecodingDiagnostics.log(error, type: T.self, path: path)
            throw NetworkError.decodingError(error)
        }
    }
}

private struct EmptyBody: Encodable {}

// Decode target for endpoints whose success response has no meaningful body
// (204 No Content, or a body callers don't need) -- see the T.self ==
// EmptyResponse.self short-circuit above.
struct EmptyResponse: Decodable {}
