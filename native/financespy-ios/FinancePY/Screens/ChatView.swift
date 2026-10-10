import SwiftUI

struct ChatView: View {
    let chatId: String?
    @StateObject private var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @Environment(\.dismiss) private var dismiss

    init(chatId: String?) {
        self.chatId = chatId
        self._viewModel = StateObject(wrappedValue: ChatViewModel(chatId: chatId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.8))
            }

            if viewModel.isLoading && viewModel.messages.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isSending {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                                .id("sending_indicator")
                            }

                            // Padding at the bottom
                            Color.clear.frame(height: 10).id("bottom")
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isSending) { isSending in
                        if isSending {
                            withAnimation {
                                proxy.scrollTo("sending_indicator", anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }

            Divider()

            // Input Area
            HStack {
                TextField("Escribe un mensaje...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .disabled(viewModel.isSending)

                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending ? .gray : .blue)
                        .padding(10)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
        .navigationTitle(viewModel.isNewChat ? "Nuevo chat" : (viewModel.title.isEmpty ? "Chat" : viewModel.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendMessage() {
        viewModel.sendMessage(content: inputText)
        inputText = ""
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

struct MessageBubble: View {
    let message: MessageDto

    var isUser: Bool {
        message.role == "user"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isUser {
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.blue)
                    .clipShape(Circle())
            } else {
                Spacer()
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content ?? (message.type == "user_message" ? "" : "Pensando..."))
                    .padding(12)
                    .background(isUser ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])

                if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                    ForEach(toolCalls) { toolCall in
                        if let functionName = toolCall.functionName {
                            Text("🛠️ Usó: \(functionName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            if isUser {
                Image(systemName: "person.fill")
                    .foregroundColor(.primary)
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(Circle())
            } else {
                Spacer()
            }
        }
    }
}

// Extension to apply corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
