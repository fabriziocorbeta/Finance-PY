import SwiftUI

struct ChatsListView: View {
    @StateObject private var viewModel = ChatsListViewModel()
    @State private var showingNewChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.chats.isEmpty {
                    ProgressView()
                } else if let error = viewModel.error, viewModel.chats.isEmpty {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if viewModel.chats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("No tienes chats todavía")
                            .font(.title2)
                        Text("Preguntame sobre tus finanzas, transacciones o pedime ayuda para organizar tu presupuesto.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        NavigationLink(destination: ChatView(chatId: "new")) {
                            Text("Nuevo chat")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                } else {
                    List(viewModel.chats) { chat in
                        NavigationLink(destination: ChatView(chatId: chat.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chat.title ?? "Nuevo chat")
                                    .font(.headline)
                                HStack {
                                    Text("\(chat.messageCount ?? 0) mensajes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let dateString = chat.lastMessageAt {
                                        Text(String(dateString.prefix(10)))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Asistente IA")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ChatView(chatId: "new")) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.fetchChats()
            }
        }
    }
}
