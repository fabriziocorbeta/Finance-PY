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
        let accessStatus = save(key: Keys.accessToken, value: accessToken)
        let refreshStatus = save(key: Keys.refreshToken, value: refreshToken)
        if accessStatus == errSecSuccess && refreshStatus == errSecSuccess {
            UserDefaults.standard.set(true, forKey: Self.migrationKey)
        }
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

        var canMarkMigrated = true
        for key in [Keys.accessToken, Keys.refreshToken] {
            let result = readRawWithStatus(key: key)
            switch result.status {
            case errSecSuccess:
                if let existingValue = result.value {
                    if save(key: key, value: existingValue) != errSecSuccess {
                        canMarkMigrated = false
                    }
                } else {
                    canMarkMigrated = false
                }
            case errSecItemNotFound:
                continue
            default:
                canMarkMigrated = false
            }
        }

        if canMarkMigrated {
            UserDefaults.standard.set(true, forKey: Self.migrationKey)
        }
    }

    #if DEBUG
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
    #endif

    @discardableResult
    private func save(
        key: String,
        value: String,
        accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    ) -> OSStatus {
        guard let data = value.data(using: .utf8) else { return errSecParam }

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

        return SecItemAdd(attributes as CFDictionary, nil)
    }

    private func readRaw(key: String) -> String? {
        readRawWithStatus(key: key).value
    }

    private func readRawWithStatus(key: String) -> (status: OSStatus, value: String?) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess else {
            return (status, nil)
        }

        guard let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return (errSecDecode, nil)
        }

        return (errSecSuccess, value)
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
