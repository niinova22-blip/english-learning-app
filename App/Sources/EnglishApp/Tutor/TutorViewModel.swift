import Foundation
import TutorEngine

/// Thrown when a tutor request takes longer than `TutorViewModel`'s
/// timeout to respond. The spec requires generation timeouts to
/// surface as an inline, retryable error rather than an infinite
/// spinner. Note this only reliably bounds latency if the underlying
/// `TutorEngine.respond(to:)` call cooperates with task cancellation:
/// `withThrowingTaskGroup` won't actually return until the losing
/// child task completes, so against a non-cancellation-checking engine
/// (e.g. `MLXTutorEngine` today) the spinner can in practice outlive
/// this bound. Known, deliberately deferred limitation — not fixed here.
struct TutorTimeoutError: LocalizedError {
    var errorDescription: String? { "Öğretmen yanıt vermekte çok gecikti. Lütfen tekrar dene." }
}

@MainActor
@Observable
final class TutorViewModel {
    enum State: Equatable {
        case idle
        case loading
        case response(String)
        case failure(String)
    }

    enum Context {
        case card(TutorContext)
        case question(prompt: String, options: [String], correctIndex: Int, selectedIndex: Int?, explanationTR: String, passage: String? = nil)
    }

    struct TutorContext {
        let headword: String
        let definition: String
        let exampleSentences: [String]
        let translationTR: String
    }

    private(set) var state: State = .idle
    private let engine: any TutorEngine
    private let context: Context
    private let timeoutNanoseconds: UInt64

    convenience init(engine: any TutorEngine, context: TutorContext, timeoutSeconds: UInt64 = 30) {
        self.init(engine: engine, context: .card(context), timeoutSeconds: timeoutSeconds)
    }

    init(engine: any TutorEngine, context: Context, timeoutSeconds: UInt64 = 30) {
        self.engine = engine
        self.context = context
        self.timeoutNanoseconds = timeoutSeconds * 1_000_000_000
    }

    func ask(_ quickAction: QuickAction) async {
        await send(.quickAction(quickAction))
    }

    func ask(freeText question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await send(.freeText(trimmed))
    }

    private func send(_ ask: TutorAsk) async {
        state = .loading
        do {
            let response: String
            switch context {
            case .card(let card):
                let request = TutorRequest(
                    headword: card.headword, definition: card.definition,
                    exampleSentences: card.exampleSentences, translationTR: card.translationTR, ask: ask
                )
                response = try await withTimeout { try await self.engine.respond(to: request) }
            case .question(let prompt, let options, let correctIndex, let selectedIndex, let explanationTR, let passage):
                let request = QuestionTutorRequest(
                    prompt: prompt, options: options, correctIndex: correctIndex,
                    selectedIndex: selectedIndex, explanationTR: explanationTR, ask: ask,
                    passage: passage
                )
                response = try await withTimeout { try await self.engine.respond(to: request) }
            }
            state = .response(response)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    private func withTimeout(_ work: @escaping @Sendable () async throws -> String) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(nanoseconds: self.timeoutNanoseconds)
                throw TutorTimeoutError()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw TutorTimeoutError()
            }
            return result
        }
    }
}
