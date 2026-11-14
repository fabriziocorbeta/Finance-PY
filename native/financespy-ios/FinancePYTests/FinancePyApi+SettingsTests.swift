import XCTest
@testable import FinancePY

final class FinancePyApiSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchUsageSuccess() async throws {
        let usage = UsageDto(authenticationMethod: "oauth", message: "OK")
        let data = try JSONEncoder().encode(usage)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let result = try await FinancePyApi.shared.fetchUsage()
        XCTAssertEqual(result.message, "OK")
    }

    func testApi4xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.fetchUsage()
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 400)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testApi5xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Server Error".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.fetchUsage()
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testApiMalformed() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.fetchUsage()
            XCTFail("Expected error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDeleteAccountSendsCurrentPassword() async throws {
        var capturedBody: [String: String]?
        var capturedMethod: String?
        var capturedPath: String?

        MockURLProtocol.requestHandler = { request in
            capturedMethod = request.httpMethod
            capturedPath = request.url?.path
            capturedBody = try self.decodedBody(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        try await FinancePyApi.shared.deleteAccount(currentPassword: "secret-password")

        XCTAssertEqual(capturedMethod, "DELETE")
        XCTAssertEqual(capturedPath, "/api/v1/users/me")
        XCTAssertEqual(capturedBody?["current_password"], "secret-password")
    }

    func testResetDataSendsCurrentPassword() async throws {
        var capturedBody: [String: String]?
        var capturedMethod: String?
        var capturedPath: String?

        MockURLProtocol.requestHandler = { request in
            capturedMethod = request.httpMethod
            capturedPath = request.url?.path
            capturedBody = try self.decodedBody(from: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "{}".data(using: .utf8)!)
        }

        try await FinancePyApi.shared.resetData(currentPassword: "secret-password")

        XCTAssertEqual(capturedMethod, "DELETE")
        XCTAssertEqual(capturedPath, "/api/v1/users/reset")
        XCTAssertEqual(capturedBody?["current_password"], "secret-password")
    }

    private func decodedBody(from request: URLRequest) throws -> [String: String]? {
        let data: Data?
        if let httpBody = request.httpBody {
            data = httpBody
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            var collected = Data()
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count > 0 {
                    collected.append(buffer, count: count)
                } else {
                    break
                }
            }
            data = collected
        } else {
            data = nil
        }
        guard let data, !data.isEmpty else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: String]
    }
}
