import XCTest
import Combine
@testable import FinancePY

@MainActor
final class ChatViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testInitialStateForNewChat() {
        let viewModel = ChatViewModel(chatId: "new")
        XCTAssertTrue(viewModel.isNewChat)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.messages.count, 0)
    }

    func testInitialStateForExistingChat() async throws {
        // Mock the fetch chat request
        let chatDto = ChatDto(id: "existing_1", title: "Test Chat", error: nil, createdAt: "", updatedAt: "", messages: [], messageCount: 0, lastMessageAt: nil)
        let chatData = try JSONEncoder().encode(chatDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, chatData)
        }

        let viewModel = ChatViewModel(chatId: "existing_1")
        XCTAssertFalse(viewModel.isNewChat)

        // Wait for refresh to complete (since it's called in init inside Task)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        XCTAssertEqual(viewModel.title, "Test Chat")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }

    func testSendMessageNewChat() async throws {
        // First mock response for createChat
        let newChatDto = ChatDto(id: "new_created", title: "Created Chat", error: nil, createdAt: "", updatedAt: "", messages: [
            MessageDto(id: "m1", type: "user_message", role: "user", content: "Hello", model: nil, createdAt: "", updatedAt: "", toolCalls: nil)
        ], messageCount: 1, lastMessageAt: nil)
        let chatData = try JSONEncoder().encode(newChatDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, chatData)
        }

        let viewModel = ChatViewModel(chatId: nil)
        viewModel.sendMessage(content: "Hello")

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(viewModel.isNewChat)
        XCTAssertEqual(viewModel.title, "Created Chat")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages.first?.content, "Hello")
    }

    func testFetchChatError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let viewModel = ChatViewModel(chatId: "existing_1")

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.error, UserFacingError.generic)
    }

    // MARK: - Assistant failures

    func testChatErrorStopsPollingAndShowsFriendlyMessage() async throws {
        let friendly = "El asistente no está disponible en este momento. Probá de nuevo en unos minutos."
        let counter = RequestCounter()
        MockURLProtocol.requestHandler = { request in
            let n = counter.increment()
            // First load: reply still pending. Then the LLM fails: the server
            // drops the pending reply and stores the friendly error on the chat.
            let body = n == 1
                ? Self.chatJSON(messages: [Self.userMessageJSON, Self.assistantMessageJSON(content: "")])
                : Self.chatJSON(error: friendly, messages: [Self.userMessageJSON])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let viewModel = ChatViewModel(chatId: "c1", pollIntervalNanoseconds: 10_000_000)
        try await waitUntil { viewModel.error != nil }

        XCTAssertEqual(viewModel.error, friendly)
        XCTAssertEqual(viewModel.messages.map(\.id), ["u1"])

        let requestsAfterError = counter.value
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(counter.value, requestsAfterError, "polling must stop once chat.error is set")
    }

    func testStreamedReplyStopsPollingOnceItStopsGrowing() async throws {
        let counter = RequestCounter()
        MockURLProtocol.requestHandler = { request in
            let n = counter.increment()
            let content = n == 1 ? "" : (n == 2 ? "Hola" : "Hola, ¿en qué te ayudo?")
            let body = Self.chatJSON(messages: [Self.userMessageJSON, Self.assistantMessageJSON(content: content)])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }

        let viewModel = ChatViewModel(chatId: "c1", pollIntervalNanoseconds: 10_000_000)
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.messages.last?.content, "Hola, ¿en qué te ayudo?")
        let requestsWhenDone = counter.value
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(counter.value, requestsWhenDone, "polling must stop once the reply is complete")
    }

    func testFeatureDisabledShowsSpanishTextInChatsList() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            let body = #"{"error":"feature_disabled","message":"AI features are not enabled for this user"}"#
            return (response, Data(body.utf8))
        }

        let viewModel = ChatsListViewModel()
        await viewModel.fetchChats()

        XCTAssertEqual(viewModel.error, UserFacingError.assistantDisabled)
    }

    func testApiErrorsMapToSpanishUserText() {
        let disabledBody = #"{"error":"feature_disabled","message":"AI features are not enabled for this user"}"#
        XCTAssertEqual(UserFacingError.message(for: NetworkError.httpError(403, disabledBody), assistant: true),
                       "El asistente IA no está activado para tu cuenta. Activalo desde Ajustes en la versión web.")
        XCTAssertEqual(NetworkError.httpError(403, disabledBody).localizedDescription, UserFacingError.assistantDisabled)
        XCTAssertEqual(UserFacingError.message(for: NetworkError.httpError(503, nil), assistant: true),
                       "El asistente está ocupado. Probá de nuevo en unos minutos.")
        XCTAssertEqual(UserFacingError.message(for: NetworkError.httpError(429, "{}"), assistant: true), UserFacingError.assistantBusy)
        XCTAssertEqual(UserFacingError.message(for: NetworkError.unauthorized), UserFacingError.sessionExpired)
        XCTAssertEqual(UserFacingError.message(for: URLError(.notConnectedToInternet)), UserFacingError.offline)
        XCTAssertEqual(UserFacingError.message(for: NetworkError.httpError(500, "<html>boom</html>")), UserFacingError.generic)
        XCTAssertEqual(UserFacingError.message(for: NetworkError.httpError(422, #"{"error":"x","details":["El título no puede estar vacío"]}"#)),
                       "El título no puede estar vacío")
    }

    func testChatFailureNeverShowsTechnicalMessage() {
        XCTAssertNil(UserFacingError.chatFailure(nil))
        XCTAssertNil(UserFacingError.chatFailure("  "))
        XCTAssertEqual(UserFacingError.chatFailure("Probá de nuevo."), "Probá de nuevo.")
        let stored = #"{"message":"Probá de nuevo.","technical_message":"503 Service Unavailable","type":"Faraday::ServerError"}"#
        XCTAssertEqual(UserFacingError.chatFailure(stored), "Probá de nuevo.")
        XCTAssertEqual(UserFacingError.chatFailure(#"{"technical_message":"503"}"#), UserFacingError.generic)
    }

    // MARK: - Helpers

    private static let userMessageJSON = #"{"id":"u1","type":"user_message","role":"user","content":"Hola","created_at":"2026-10-21T10:00:00Z","updated_at":"2026-10-21T10:00:00Z"}"#

    private static func assistantMessageJSON(content: String) -> String {
        #"{"id":"a1","type":"assistant_message","role":"assistant","content":"\#(content)","model":"m","created_at":"2026-10-21T10:00:01Z","updated_at":"2026-10-21T10:00:01Z"}"#
    }

    private static func chatJSON(error: String? = nil, messages: [String]) -> String {
        let errorJSON = error.map { "\"\($0)\"" } ?? "null"
        return #"{"id":"c1","title":"Chat","error":\#(errorJSON),"created_at":"2026-10-21T10:00:00Z","updated_at":"2026-10-21T10:00:00Z","messages":[\#(messages.joined(separator: ","))]}"#
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int { lock.withLock { count } }

    func increment() -> Int { lock.withLock { count += 1; return count } }
}
