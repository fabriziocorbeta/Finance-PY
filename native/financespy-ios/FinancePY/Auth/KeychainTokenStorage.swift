import Foundation
import Security

final class KeychainTokenStorage {
    static let shared = KeychainTokenStorage()
    private let service = "py.com.cdco.financespy.ios"

    private enum Keys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
    }

    private init() {}

    func save(accessToken: String, refreshToken: String) {
        save(key: Keys.accessToken, value: accessToken)
        save(key: Keys.refreshToken, value: refreshToken)
    }

    func accessToken() -> String? {
        return read(key: Keys.accessToken)
    }

    func refreshToken() -> String? {
        return read(key: Keys.refreshToken)
    }

    func clear() {
        delete(key: Keys.accessToken)
        delete(key: Keys.refreshToken)
    }

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
