import Foundation
import Combine
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var messages: [MessageDto] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: String?
    @Published var isNewChat = false

    private var actualChatId: String?
    private var isPolling = false
    private var pollTask: Task<Void, Never>?

    init(chatId: String?) {
        if chatId == "new" || chatId == nil {
            self.actualChatId = nil
            self.isNewChat = true
        } else {
            self.actualChatId = chatId
            self.isNewChat = false
            Task {
                await refresh()
            }
        }
    }

    deinit {
        pollTask?.cancel()
    }

    func refresh() async {
        guard let id = actualChatId else { return }
        isLoading = true
        error = nil

        do {
            let chat = try await FinancePyApi.shared.fetchChat(id: id, page: 1)
            self.title = chat.title ?? ""
            self.messages = chat.messages ?? []
            self.isLoading = false
            checkAndPoll(messages: self.messages)
        } catch {
            self.isLoading = false
            self.error = "Error al cargar chat: \(error.localizedDescription)"
        }
    }

    func sendMessage(content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        isSending = true
        error = nil

        Task {
            do {
                if let id = actualChatId {
                    let messageResponse = try await FinancePyApi.shared.sendMessage(chatId: id, content: trimmedContent)
                    self.messages.append(messageResponse)
                    self.isSending = false
                    checkAndPoll(messages: self.messages)
                } else {
                    let newChat = try await FinancePyApi.shared.createChat(title: nil, message: trimmedContent)
                    self.actualChatId = newChat.id
                    self.title = newChat.title ?? ""
                    self.messages = newChat.messages ?? []
                    self.isSending = false
                    self.isNewChat = false
                    checkAndPoll(messages: self.messages)
                }
            } catch {
                self.isSending = false
                self.error = "Error al enviar mensaje: \(error.localizedDescription)"
            }
        }
    }

    private func checkAndPoll(messages: [MessageDto]) {
        guard !messages.isEmpty else { return }

        if hasPendingReply(messages: messages) {
            startPolling()
        }
    }

    private func startPolling() {
        guard !isPolling else { return }
        isPolling = true

        pollTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.pollForAssistantResponse()
        }
    }

    private func pollForAssistantResponse() async {
        guard let id = actualChatId else {
            isPolling = false
            return
        }

        var attempts = 0

        while attempts < 90 && !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            do {
                let chat = try await FinancePyApi.shared.fetchChat(id: id, page: 1)
                let newMessages = chat.messages ?? []

                self.title = chat.title ?? ""
                self.messages = newMessages

                if !hasPendingReply(messages: newMessages) {
                    break
                }
            } catch {
                // Keep trying on intermittent failures
            }

            attempts += 1
            if attempts >= 90 {
                self.error = "La IA todavía está procesando. Por favor, revisá más tarde."
            }
        }
        isPolling = false
    }

    private func hasPendingReply(messages: [MessageDto]) -> Bool {
        return messages.last?.type == "user_message"
    }
}
