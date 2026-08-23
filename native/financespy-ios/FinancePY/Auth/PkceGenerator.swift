import Foundation
import CryptoKit

struct PkcePair {
    let codeVerifier: String
    let codeChallenge: String
}

enum PkceGenerator {
    static func generate() -> PkcePair {
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(for: verifier)
        return PkcePair(codeVerifier: verifier, codeChallenge: challenge)
    }

    private static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return base64UrlEncode(Data(buffer))
    }

    private static func generateCodeChallenge(for verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        let hash = SHA256.hash(data: data)
        return base64UrlEncode(Data(hash))
    }

    private static func base64UrlEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
