import Foundation
import AuthenticationServices

enum AuthError: LocalizedError {
    case invalidUrl
    case sessionFailed(Error)
    case missingAuthorizationCode
    case missingCodeVerifier
    case invalidState
    case tokenExchangeFailed(Int, String?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid authorization URL."
        case .sessionFailed(let error):
            return "Authentication session failed: \(error.localizedDescription)"
        case .missingAuthorizationCode:
            return "Authorization code missing from callback."
        case .missingCodeVerifier:
            return "PKCE code verifier is missing."
        case .invalidState:
            return "OAuth state mismatch — possible callback spoofing."
        case .tokenExchangeFailed(let status, let message):
            return "Token exchange failed (\(status)): \(message ?? "Unknown error")"
        case .invalidResponse:
            return "Invalid server response."
        }
    }
}

struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int
}

@MainActor
final class WebAuthPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return UIWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

final class AuthRepository: ObservableObject {
    static let shared = AuthRepository()

    private let clientId = "Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM"
    private let redirectUri = "financespy://oauth/callback"
    private let baseUrl = "https://finance.cd-co.com.py"
    private let scope = "read_write"

    private(set) var currentCodeVerifier: String?
    private var currentState: String?
    private let tokenStorage = KeychainTokenStorage.shared

    private init() {}

    func buildAuthorizationUrl() throws -> URL {
        let pkce = PkceGenerator.generate()
        self.currentCodeVerifier = pkce.codeVerifier
        let state = PkceGenerator.generateState()
        self.currentState = state

        var components = URLComponents(string: "\(baseUrl)/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]

        guard let url = components?.url else {
            throw AuthError.invalidUrl
        }
        return url
    }

    @MainActor
    func login() async throws {
        let authUrl = try buildAuthorizationUrl()

        let callbackUrl: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authUrl,
                callbackURLScheme: "financespy"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: AuthError.sessionFailed(error))
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: AuthError.missingAuthorizationCode)
                }
            }

            session.presentationContextProvider = WebAuthPresentationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }

        try await handleCallbackUrl(callbackUrl)
    }

    func handleCallbackUrl(_ url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            throw AuthError.missingAuthorizationCode
        }

        guard let expectedState = currentState else {
            throw AuthError.invalidState
        }
        let receivedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard let receivedState, receivedState == expectedState else {
            throw AuthError.invalidState
        }
        currentState = nil

        try await exchangeCode(code)
    }

    func exchangeCode(_ code: String) async throws {
        guard let verifier = currentCodeVerifier else {
            throw AuthError.missingCodeVerifier
        }

        guard let tokenUrl = URL(string: "\(baseUrl)/oauth/token") else {
            throw AuthError.invalidUrl
        }

        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectUri,
            "code_verifier": verifier
        ]

        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8)
            throw AuthError.tokenExchangeFailed(httpResponse.statusCode, errorBody)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)

        tokenStorage.save(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? ""
        )
        self.currentCodeVerifier = nil
    }

    func isLoggedIn() async -> Bool {
        guard let token = tokenStorage.accessToken(), !token.isEmpty else {
            return false
        }
        return true
    }

    func logout() async {
        tokenStorage.clear()
        self.currentCodeVerifier = nil
    }
}
