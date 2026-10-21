import Foundation

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    // `.invalid` never resolves (RFC 6761), so even an unintercepted request can't reach a real server.
    static let unroutableBaseUrl = "https://financepy-tests.invalid"

    static let unhandledRequestErrorDomain = "MockURLProtocol.unhandledRequest"

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            // Finishing with no response traps URLSession's async API (SIGILL) on stray requests from earlier tests.
            let error = NSError(
                domain: MockURLProtocol.unhandledRequestErrorDomain,
                code: 0,
                userInfo: [NSURLErrorFailingURLErrorKey: request.url as Any]
            )
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}
