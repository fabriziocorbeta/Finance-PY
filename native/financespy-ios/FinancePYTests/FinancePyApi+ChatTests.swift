import XCTest
@testable import FinancePY

final class FinancePyApiChatTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchChatsSuccess() async throws {
        let chat = ChatDto(id: "1", title: "Chat 1", error: nil, createdAt: "2023", updatedAt: "2023", messages: [], messageCount: 0, lastMessageAt: nil)
        let pagination = PaginationDto(page: 1, perPage: 20, totalCount: 1, totalPages: 1)
        let responseDto = ChatsListResponse(chats: [chat], pagination: pagination)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(responseDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let result = try await FinancePyApi.shared.fetchChats()
        XCTAssertEqual(result.chats.count, 1)
        XCTAssertEqual(result.chats.first?.id, "1")
    }

    func testFetchChats5xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        do {
            _ = try await FinancePyApi.shared.fetchChats()
            XCTFail()
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail()
        }
    }

    func testApi4xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.fetchChats()
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 400)
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
            _ = try await FinancePyApi.shared.fetchChats()
            XCTFail("Expected error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDecodeChatShowWithToolCall() async throws {
        let jsonString = """
        {
            "id": "chat123",
            "created_at": "2023-10-15T10:00:00Z",
            "updated_at": "2023-10-15T10:00:00Z",
            "messages": [
                {
                    "id": "msg123",
                    "type": "assistant_message",
                    "role": "assistant",
                    "created_at": "2023-10-15T10:01:00Z",
                    "updated_at": "2023-10-15T10:01:00Z",
                    "tool_calls": [
                        {
                            "id": "tool123",
                            "function_name": "get_weather",
                            "function_arguments": {"location": "San Francisco", "unit": "celsius"},
                            "function_result": [{"temperature": 22, "condition": "sunny"}],
                            "created_at": "2023-10-15T10:01:05Z"
                        }
                    ]
                }
            ]
        }
        """
        let data = jsonString.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let chat = try await FinancePyApi.shared.fetchChat(id: "chat123")
        XCTAssertEqual(chat.id, "chat123")
        let toolCall = chat.messages?.first?.toolCalls?.first
        XCTAssertEqual(toolCall?.functionName, "get_weather")

        let args = toolCall?.functionArguments
        XCTAssertNotNil(args)
        XCTAssertTrue(args!.contains("San Francisco"))
        XCTAssertTrue(args!.contains("celsius"))

        let res = toolCall?.functionResult
        XCTAssertNotNil(res)
        XCTAssertTrue(res!.contains("temperature"))
        XCTAssertTrue(res!.contains("sunny"))
    }

    func testEncodeSendMessageRequest() throws {
        let request = SendMessageRequest(content: "Hello, World!", model: "gpt-4")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertNotNil(jsonObject)
        XCTAssertEqual(jsonObject?["content"] as? String, "Hello, World!")
        XCTAssertEqual(jsonObject?["model"] as? String, "gpt-4")
    }

    func testDecodeRetryMessageResponse() async throws {
        let jsonString = """
        {
            "message": "Retry initiated",
            "message_id": "msg_retry_123"
        }
        """
        let data = jsonString.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 202, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let response = try await FinancePyApi.shared.retryMessage(chatId: "chat123")
        XCTAssertEqual(response.message, "Retry initiated")
        XCTAssertEqual(response.messageId, "msg_retry_123")
    }
}
