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
    private let pollIntervalNanoseconds: UInt64

    init(chatId: String?, pollIntervalNanoseconds: UInt64 = 2_000_000_000) {
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
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
            self.isLoading = false
            if apply(chat) {
                startPolling()
            }
        } catch {
            self.isLoading = false
            self.error = UserFacingError.message(for: error, assistant: true)
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
                    if hasPendingReply(messages: self.messages) {
                        startPolling()
                    }
                } else {
                    let newChat = try await FinancePyApi.shared.createChat(title: nil, message: trimmedContent)
                    self.actualChatId = newChat.id
                    self.isSending = false
                    self.isNewChat = false
                    if apply(newChat) {
                        startPolling()
                    }
                }
            } catch {
                self.isSending = false
                self.error = UserFacingError.message(for: error, assistant: true)
            }
        }
    }

    private func startPolling() {
        guard !isPolling, let id = actualChatId else { return }
        isPolling = true

        let interval = pollIntervalNanoseconds
        pollTask?.cancel()
        // Holds self weakly between polls so leaving the screen (deinit) cancels
        // the loop instead of keeping it alive for the full 3 minutes.
        pollTask = Task { [weak self] in
            var attempts = 0
            var previousReply: String?

            while attempts < 90 {
                try? await Task.sleep(nanoseconds: interval)
                guard !Task.isCancelled, self != nil else { return }

                if let chat = try? await FinancePyApi.shared.fetchChat(id: id, page: 1) {
                    guard let self else { return }
                    let waiting = self.apply(chat)
                    // The reply streams into the same message, so keep polling until it stops growing.
                    let reply = self.messages.last.flatMap { $0.type == "assistant_message" ? $0.content : nil }
                    if !waiting && (chat.error != nil || reply == previousReply) {
                        break
                    }
                    previousReply = reply
                }
                // A failed fetch is retried on the next tick.

                attempts += 1
                if attempts >= 90 {
                    self?.error = "La IA todavía está procesando. Por favor, revisá más tarde."
                }
            }
            self?.isPolling = false
        }
    }

    func retryMessage() {
        guard let id = actualChatId else { return }

        isSending = true
        error = nil

        Task {
            do {
                _ = try await FinancePyApi.shared.retryMessage(chatId: id)
                // Reload the chat after initiating a retry
                await refresh()
                self.isSending = false
            } catch {
                self.isSending = false
                self.error = UserFacingError.message(for: error, assistant: true)
            }
        }
    }

    /// Applies a fetched chat; returns true while the assistant still owes a reply.
    @discardableResult
    private func apply(_ chat: ChatDto) -> Bool {
        title = chat.title ?? ""
        // The API already returns messages oldest-first (Message.ordered is created_at asc).
        messages = chat.messages ?? []

        // On an LLM failure the server drops the pending reply and stores a
        // friendly message on the chat; waiting further would never end.
        if let failure = UserFacingError.chatFailure(chat.error) {
            error = failure
            return false
        }
        return hasPendingReply(messages: messages)
    }

    private func hasPendingReply(messages: [MessageDto]) -> Bool {
        guard let last = messages.last else { return false }
        if last.type == "user_message" { return true }
        // The server creates the assistant reply up front with empty content.
        return last.type == "assistant_message" && (last.content ?? "").isEmpty
    }
}
