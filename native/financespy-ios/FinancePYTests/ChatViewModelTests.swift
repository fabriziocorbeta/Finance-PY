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

        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.error!.contains("500"))
    }
}
