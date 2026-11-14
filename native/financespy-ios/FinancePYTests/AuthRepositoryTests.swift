import XCTest
import Security
import SwiftUI
import UIKit
@testable import FinancePY

extension TokenResponse: Encodable {
    private enum CodingKeys: String, CodingKey {
        case accessToken, refreshToken, tokenType, expiresIn
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encode(expiresIn, forKey: .expiresIn)
    }
}

@MainActor
final class AuthRepositoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testExchangeCodeSuccess() async throws {
        let authRepo = AuthRepository.shared
        // Mock currentCodeVerifier
        _ = PkceGenerator.generate()
        // Use reflection or just login flow since currentCodeVerifier is private(set).
        // It's easier to build Authorization URL which sets the verifier
        _ = try authRepo.buildAuthorizationUrl()

        let tokenResponse = TokenResponse(accessToken: "access", refreshToken: "refresh", tokenType: "Bearer", expiresIn: 3600)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(tokenResponse)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        try await authRepo.exchangeCode("test_code")
        let isLoggedIn = await authRepo.isLoggedIn()
        XCTAssertTrue(isLoggedIn)

        await authRepo.logout() // clean up
    }

    func testExchangeCode4xxError() async throws {
        let authRepo = AuthRepository.shared
        _ = try authRepo.buildAuthorizationUrl()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }

        do {
            try await authRepo.exchangeCode("test_code")
            XCTFail("Expected tokenExchangeFailed error")
        } catch AuthError.tokenExchangeFailed(let status, let message) {
            XCTAssertEqual(status, 400)
            XCTAssertEqual(message, "Bad Request")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExchangeCode5xxError() async throws {
        let authRepo = AuthRepository.shared
        _ = try authRepo.buildAuthorizationUrl()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Server Error".data(using: .utf8)!)
        }

        do {
            try await authRepo.exchangeCode("test_code")
            XCTFail("Expected tokenExchangeFailed error")
        } catch AuthError.tokenExchangeFailed(let status, let message) {
            XCTAssertEqual(status, 500)
            XCTAssertEqual(message, "Server Error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExchangeCodeMalformedResponse() async throws {
        let authRepo = AuthRepository.shared
        _ = try authRepo.buildAuthorizationUrl()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }

        do {
            try await authRepo.exchangeCode("test_code")
            XCTFail("Expected decoding error")
        } catch is DecodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testKeychainStoresTokensWithAfterFirstUnlockThisDeviceOnly() {
        let storage = KeychainTokenStorage.shared
        storage.clear()
        defer { storage.clear() }

        storage.save(accessToken: "new-access", refreshToken: "new-refresh")

        XCTAssertEqual(storage.accessToken(), "new-access")
        XCTAssertEqual(storage.refreshToken(), "new-refresh")
        XCTAssertEqual(storage.accessibility(forAccessToken: true), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        XCTAssertEqual(storage.accessibility(forAccessToken: false), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    func testKeychainMigratesLegacyAfterFirstUnlockTokensOnRead() {
        let storage = KeychainTokenStorage.shared
        storage.clear()
        defer { storage.clear() }

        storage.saveLegacyForTesting(accessToken: "legacy-access", refreshToken: "legacy-refresh")
        XCTAssertEqual(storage.accessibility(forAccessToken: true), kSecAttrAccessibleAfterFirstUnlock as String)
        XCTAssertEqual(storage.accessibility(forAccessToken: false), kSecAttrAccessibleAfterFirstUnlock as String)

        XCTAssertEqual(storage.accessToken(), "legacy-access")
        XCTAssertEqual(storage.refreshToken(), "legacy-refresh")
        XCTAssertEqual(storage.accessibility(forAccessToken: true), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        XCTAssertEqual(storage.accessibility(forAccessToken: false), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    func testSecurityOverlayWindowManagerStateAndLevel() {
        XCTAssertGreaterThan(SecurityOverlayWindowManager.overlayWindowLevel, UIWindow.Level.alert)

        let activeLocked = SecurityOverlayWindowManager.overlayState(
            isLoggedIn: true,
            appLockEnabled: true,
            isLocked: true,
            scenePhase: .active,
            isAuthenticating: false
        )
        XCTAssertTrue(activeLocked.showLock)
        XCTAssertFalse(activeLocked.showPrivacy)

        let inactiveUnlocked = SecurityOverlayWindowManager.overlayState(
            isLoggedIn: true,
            appLockEnabled: false,
            isLocked: false,
            scenePhase: .inactive,
            isAuthenticating: false
        )
        XCTAssertFalse(inactiveUnlocked.showLock)
        XCTAssertTrue(inactiveUnlocked.showPrivacy)

        let inactiveDuringBiometrics = SecurityOverlayWindowManager.overlayState(
            isLoggedIn: true,
            appLockEnabled: true,
            isLocked: true,
            scenePhase: .inactive,
            isAuthenticating: true
        )
        XCTAssertTrue(inactiveDuringBiometrics.showLock)
        XCTAssertFalse(inactiveDuringBiometrics.showPrivacy)
    }

    func testModelContainerFactoryRemovesStoreWalAndShmFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("default.store")
        let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
        let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")

        for url in [storeURL, walURL, shmURL] {
            try Data("corrupt".utf8).write(to: url)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }

        ModelContainerFactory.removeStoreFiles(at: storeURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: walURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: shmURL.path))
    }

    func testAppLockManagerLockAndUnlockTransitions() {
        let manager = AppLockManager()
        XCTAssertFalse(manager.isLocked)

        manager.lock()
        XCTAssertTrue(manager.isLocked)

        manager.unlock()
        XCTAssertFalse(manager.isLocked)
    }
}
