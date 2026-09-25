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

    /// Bumped by `startNewChat()`. A `requestResponse` captures the epoch
    /// current at the moment it starts and, after resuming from its
    /// `await`, only touches `messages`/`isLoading` if the epoch is still
    /// current — this is what lets a stale reply (or a stale failure) from
    /// a conversation the user has since abandoned via "New Chat" be
    /// silently dropped instead of landing in the new, unrelated session.
    private var conversationEpoch = 0

    private let learnerLanguage: LearnerLanguage

    init(engine: any TutorEngine, historyCap: Int = 20, learnerLanguage: LearnerLanguage = AppLanguage.current.learnerLanguage) {
        self.engine = engine
        self.historyCap = historyCap
        self.learnerLanguage = learnerLanguage
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }
        messages.append(DisplayMessage(id: UUID(), turn: ChatTurn(role: .user, text: trimmed)))
        let epoch = beginRequest()
        await requestResponse(epoch: epoch)
    }

    func retryLastMessage() async {
        guard !isLoading, let last = messages.last, last.turn.role == .user, last.failed else { return }
        messages[messages.count - 1].failed = false
        let epoch = beginRequest()
        await requestResponse(epoch: epoch)
    }

    func startNewChat() {
        conversationEpoch += 1
        messages = []
        isLoading = false
    }

    /// Synchronous (non-async) so the `isLoading` guard in `send`/
    /// `retryLastMessage` and this flip to `true` happen with no `await`
    /// in between — there is no suspension point where a second call could
    /// slip past the guard before the flag is set. Callers must invoke
    /// this immediately after their guard, before their first `await`.
    private func beginRequest() -> Int {
        isLoading = true
        return conversationEpoch
    }

    /// The context actually sent to the model:
    /// - failed learner messages are left out (they were never answered
    ///   and can no longer be retried), except the last message, which is
    ///   the one being sent or retried;
    /// - capped to the most recent `historyCap` turns;
    /// - a leading assistant turn left over from the cap is dropped, so the
    ///   context always starts with a learner turn.
    /// Only what's sent is filtered — `messages` (what's displayed) is never
    /// touched.
    private func historyToSend() -> [ChatTurn] {
        let lastIndex = messages.indices.last
        let eligible = messages.indices
            .filter { !messages[$0].failed || $0 == lastIndex }
            .map { messages[$0].turn }
        var capped = Array(eligible.suffix(historyCap))
        if capped.first?.role == .assistant {
            capped.removeFirst()
        }
        return capped
    }

    private func requestResponse(epoch: Int) async {
        do {
            let reply = try await engine.respond(to: ChatRequest(history: historyToSend(), learnerLanguage: learnerLanguage))
            guard epoch == conversationEpoch else { return }
            messages.append(DisplayMessage(id: UUID(), turn: ChatTurn(role: .assistant, text: reply)))
            isLoading = false
        } catch {
            guard epoch == conversationEpoch else { return }
            if let lastIndex = messages.indices.last, messages[lastIndex].turn.role == .user {
                messages[lastIndex].failed = true
            }
            isLoading = false
        }
    }
}
