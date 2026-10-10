import Foundation
import Combine

@MainActor
final class ChatsListViewModel: ObservableObject {
    @Published var chats: [ChatDto] = []
    @Published var isLoading = false
    @Published var error: String?

    func fetchChats() async {
        isLoading = true
        error = nil

        do {
            let response = try await FinancePyApi.shared.fetchChats()
            chats = response.chats
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
