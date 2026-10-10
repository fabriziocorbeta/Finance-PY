import Foundation

// MARK: - DTOs

struct ChatDto: Codable, Identifiable {
    let id: String
    let title: String?
    let error: String?
    let createdAt: String
    let updatedAt: String
    let messages: [MessageDto]?
    let messageCount: Int?
    let lastMessageAt: String?
}

struct MessageDto: Codable, Identifiable {
    let id: String
    let type: String
    let role: String
    let content: String?
    let model: String?
    let createdAt: String
    let updatedAt: String
    let toolCalls: [ToolCallDto]?
}

struct ToolCallDto: Codable, Identifiable {
    let id: String
    let functionName: String?
    let functionArguments: String?
    let functionResult: String?
    let createdAt: String
}

struct ChatsListResponse: Codable {
    let chats: [ChatDto]
    let pagination: PaginationDto
}

// Structs for Requests
struct CreateChatRequest: Codable {
    let title: String?
    let message: String?
    let model: String?
}

struct SendMessageRequest: Codable {
    let message: String
    let model: String?
}


// MARK: - Chat API Methods

extension FinancePyApi {
    func fetchChats(page: Int = 1) async throws -> ChatsListResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: "20")
        ]
        return try await ApiClient.shared.request(path: "/api/v1/chats", queryItems: queryItems)
    }

    func fetchChat(id: String, page: Int = 1) async throws -> ChatDto {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: "50")
        ]
        return try await ApiClient.shared.request(path: "/api/v1/chats/\(id)", queryItems: queryItems)
    }

    func createChat(title: String?, message: String?, model: String? = nil) async throws -> ChatDto {
        let requestBody = CreateChatRequest(title: title, message: message, model: model)
        return try await ApiClient.shared.request(method: "POST", path: "/api/v1/chats", body: requestBody)
    }

    func sendMessage(chatId: String, content: String, model: String? = nil) async throws -> MessageDto {
        let requestBody = SendMessageRequest(message: content, model: model)
        return try await ApiClient.shared.request(method: "POST", path: "/api/v1/chats/\(chatId)/messages", body: requestBody)
    }

    func retryMessage(chatId: String) async throws -> MessageDto {
        return try await ApiClient.shared.request(method: "POST", path: "/api/v1/chats/\(chatId)/messages/retry")
    }
}
