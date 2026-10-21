import XCTest
@testable import FinancePY

final class ApiClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testSharedClientIsRoutedThroughMockAndNeverTargetsProduction() async {
        XCTAssertEqual(ApiClient.shared.baseUrl, MockURLProtocol.unroutableBaseUrl)

        // No handler installed: the mock must still be the one answering.
        do {
            let _: EmptyResponse = try await ApiClient.shared.request(path: "/test")
            XCTFail("Expected the mock to reject an unhandled request")
        } catch let error as NSError where error.domain == MockURLProtocol.unhandledRequestErrorDomain {
            // Expected
        } catch {
            XCTFail("Request was not intercepted by MockURLProtocol: \(error)")
        }
    }

    func testSharedUrlSessionIsInterceptedByMock() async {
        // AuthRepository talks to URLSession.shared directly.
        let url = URL(string: "\(MockURLProtocol.unroutableBaseUrl)/oauth/token")!
        do {
            _ = try await URLSession.shared.data(from: url)
            XCTFail("Expected the mock to reject an unhandled request")
        } catch let error as NSError where error.domain == MockURLProtocol.unhandledRequestErrorDomain {
            // Expected
        } catch {
            XCTFail("URLSession.shared was not intercepted by MockURLProtocol: \(error)")
        }
    }

    func testHostAppCanDetectUnitTestRun() {
        // FinancePYApp skips its launch auth check / sync when this is set.
        XCTAssertNotNil(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"])
    }

    func testRequestSuccess() async throws {
        struct TestDto: Codable { let id: String }
        let expectedDto = TestDto(id: "123")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(expectedDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let result: TestDto = try await ApiClient.shared.request(path: "/test")
        XCTAssertEqual(result.id, "123")
    }

    func testRequestWithBodySuccess() async throws {
        struct TestDto: Codable { let id: String }
        struct TestBody: Codable { let name: String }
        let expectedDto = TestDto(id: "123")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(expectedDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let result: TestDto = try await ApiClient.shared.request(method: "POST", path: "/test", body: TestBody(name: "Test"))
        XCTAssertEqual(result.id, "123")
    }

    func testRequestEmptyResponse() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let _: EmptyResponse = try await ApiClient.shared.request(method: "DELETE", path: "/test")
    }

    func testUploadMultipartSuccess() async throws {
        struct TestDto: Codable { let success: Bool }
        let expectedDto = TestDto(success: true)
        let data = try JSONEncoder().encode(expectedDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let result: TestDto = try await ApiClient.shared.uploadMultipart(
            path: "/upload",
            fields: ["key": "value"],
            fileField: "file",
            fileData: "test".data(using: .utf8)!,
            fileName: "test.txt",
            mimeType: "text/plain"
        )
        XCTAssertTrue(result.success)
    }

    func testRequest401Unauthorized() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            let _: EmptyResponse = try await ApiClient.shared.request(path: "/test")
            XCTFail("Expected unauthorized error")
        } catch NetworkError.unauthorized {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequest4xxError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }

        do {
            let _: EmptyResponse = try await ApiClient.shared.request(path: "/test")
            XCTFail("Expected http error")
        } catch NetworkError.httpError(let code, let message) {
            XCTAssertEqual(code, 400)
            XCTAssertEqual(message, "Bad Request")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRequest5xxError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Server Error".data(using: .utf8)!)
        }

        do {
            let _: EmptyResponse = try await ApiClient.shared.request(path: "/test")
            XCTFail("Expected http error")
        } catch NetworkError.httpError(let code, let message) {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(message, "Server Error")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMalformedResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }

        do {
            struct TestDto: Codable { let id: String }
            let _: TestDto = try await ApiClient.shared.request(path: "/test")
            XCTFail("Expected decoding error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
