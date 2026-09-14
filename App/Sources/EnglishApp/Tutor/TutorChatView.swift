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
            .navigationTitle("Tutor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Chat") { viewModel.startNewChat() }
                }
            }
        }
    }

    private var messageList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.messages) { message in
                    messageRow(message)
                }
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding()
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
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.turn.text)
                .padding(10)
                .background(
                    message.turn.role == .user
                        ? Color.blue.opacity(0.15)
                        : Color.gray.opacity(0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if message.failed {
                Button("Retry") { Task { await viewModel.retryLastMessage() } }
                    .font(.caption)
            }
        }
    }

    private var inputBar: some View {
        HStack {
            TextField("Ask your tutor...", text: $draftText)
                .textFieldStyle(.roundedBorder)
            Button("Send") {
                let text = draftText
                draftText = ""
                Task { await viewModel.send(text) }
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding()
    }
}
