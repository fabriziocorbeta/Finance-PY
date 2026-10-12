import XCTest
import Combine
@testable import FinancePY

@MainActor
final class ChatsListViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchChatsSuccess() async throws {
        let chatDto = ChatDto(id: "1", title: "Chat 1", error: nil, createdAt: "", updatedAt: "", messages: nil, messageCount: 0, lastMessageAt: nil)
        let response = ChatsListResponse(chats: [chatDto], pagination: PaginationDto(page: 1, perPage: 20, totalCount: 1, totalPages: 1))

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(response)

        MockURLProtocol.requestHandler = { request in
            let httpResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (httpResponse, data)
        }

        let viewModel = ChatsListViewModel()
        await viewModel.fetchChats()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
        XCTAssertEqual(viewModel.chats.count, 1)
        XCTAssertEqual(viewModel.chats.first?.title, "Chat 1")
    }

    func testFetchChatsError() async throws {
        MockURLProtocol.requestHandler = { request in
            let httpResponse = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (httpResponse, Data())
        }

        let viewModel = ChatsListViewModel()
        await viewModel.fetchChats()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.error)
        XCTAssertTrue(viewModel.chats.isEmpty)
    }
}
