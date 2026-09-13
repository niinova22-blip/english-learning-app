import Foundation
import TutorEngine

@MainActor
@Observable
final class ChatViewModel {
    struct DisplayMessage: Identifiable, Equatable {
        let id: UUID
        var turn: ChatTurn
        var failed: Bool = false
    }

    private(set) var messages: [DisplayMessage] = []
    private(set) var isLoading = false
    private let engine: any TutorEngine
    private let historyCap: Int

    init(engine: any TutorEngine, historyCap: Int = 20) {
        self.engine = engine
        self.historyCap = historyCap
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(DisplayMessage(id: UUID(), turn: ChatTurn(role: .user, text: trimmed)))
        await requestResponse()
    }

    func retryLastMessage() async {
        guard let last = messages.last, last.turn.role == .user, last.failed else { return }
        messages[messages.count - 1].failed = false
        await requestResponse()
    }

    func startNewChat() {
        messages = []
    }

    private func requestResponse() async {
        isLoading = true
        defer { isLoading = false }

        let cappedHistory = messages.suffix(historyCap).map(\.turn)
        do {
            let reply = try await engine.respond(to: ChatRequest(history: Array(cappedHistory)))
            messages.append(DisplayMessage(id: UUID(), turn: ChatTurn(role: .assistant, text: reply)))
        } catch {
            if let lastIndex = messages.indices.last, messages[lastIndex].turn.role == .user {
                messages[lastIndex].failed = true
            }
        }
    }
}
