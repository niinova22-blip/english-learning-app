import SwiftUI
import TutorEngine

struct TutorChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var draftText = ""

    init(engine: any TutorEngine) {
        _viewModel = State(initialValue: ChatViewModel(engine: engine))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Tutor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New chat") { viewModel.startNewChat() }
                        .tint(Theme.primary)
                }
            }
        }
    }

    private static let bottomAnchorID = "TutorChatView.bottom"

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        Text("You can ask anything about English.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryInk)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                    }
                    if viewModel.isLoading {
                        ProgressView().tint(Theme.primary)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchorID)
                }
                .padding()
            }
            // Keep the newest message and the loading indicator on screen
            // once the conversation is longer than one screen.
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    scrollToBottom(proxy)
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
    }

    private func messageRow(_ message: ChatViewModel.DisplayMessage) -> some View {
        HStack {
            if message.turn.role == .assistant {
                bubble(for: message)
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble(for: message)
            }
        }
    }

    private func bubble(for message: ChatViewModel.DisplayMessage) -> some View {
        let isUser = message.turn.role == .user
        return VStack(alignment: .trailing, spacing: 4) {
            Text(message.turn.text)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .padding(12)
                .background(isUser ? Theme.primary.opacity(0.14) : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isUser ? Color.clear : Theme.border, lineWidth: 1)
                )
            if message.failed {
                Label("No reply", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
                if message.id == viewModel.messages.last?.id, !viewModel.isLoading {
                    Button("Try again") { Task { await viewModel.retryLastMessage() } }
                        .font(.caption.weight(.semibold))
                        .tint(Theme.primary)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask your tutor...", text: $draftText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .appGlass(in: Capsule())
            Button {
                let text = draftText
                draftText = ""
                Task { await viewModel.send(text) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 40, height: 40)
                    .background(Theme.primary, in: Circle())
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
            .opacity(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading ? 0.4 : 1)
            .accessibilityLabel("Send")
        }
        .padding()
        .background(Theme.paper)
    }
}
