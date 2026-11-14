import Foundation
import Security

final class KeychainTokenStorage {
    static let shared = KeychainTokenStorage()
    private let service = "py.com.cdco.financespy.ios"
    private static let migrationKey = "py.com.cdco.financespy.ios.keychain_migrated_v2"

    private enum Keys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
    }

    private init() {
        migrateIfNeeded()
    }

    func save(accessToken: String, refreshToken: String) {
        save(key: Keys.accessToken, value: accessToken)
        save(key: Keys.refreshToken, value: refreshToken)
        UserDefaults.standard.set(true, forKey: Self.migrationKey)
    }

    func accessToken() -> String? {
        migrateIfNeeded()
        return readRaw(key: Keys.accessToken)
    }

    func refreshToken() -> String? {
        migrateIfNeeded()
        return readRaw(key: Keys.refreshToken)
    }

    func clear() {
        delete(key: Keys.accessToken)
        delete(key: Keys.refreshToken)
    }

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.migrationKey) else { return }

        for key in [Keys.accessToken, Keys.refreshToken] {
            if let existingValue = readRaw(key: key) {
                save(key: key, value: existingValue)
            }
        }

        UserDefaults.standard.set(true, forKey: Self.migrationKey)
    }

    func saveLegacyForTesting(accessToken: String, refreshToken: String) {
        UserDefaults.standard.removeObject(forKey: Self.migrationKey)
        save(key: Keys.accessToken, value: accessToken, accessible: kSecAttrAccessibleAfterFirstUnlock)
        save(key: Keys.refreshToken, value: refreshToken, accessible: kSecAttrAccessibleAfterFirstUnlock)
    }

    func accessibility(forAccessToken: Bool = true) -> String? {
        let account = forAccessToken ? Keys.accessToken : Keys.refreshToken
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let attributes = result as? [String: Any] else {
            return nil
        }

        return attributes[kSecAttrAccessible as String] as? String
    }

    private func save(
        key: String,
        value: String,
        accessible: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ) {
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
            kSecAttrAccessible as String: accessible
        ]

        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func readRaw(key: String) -> String? {
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
