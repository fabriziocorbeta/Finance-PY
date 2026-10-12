import XCTest
@testable import FinancePY

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
        let pkce = PkceGenerator.generate()
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
}
