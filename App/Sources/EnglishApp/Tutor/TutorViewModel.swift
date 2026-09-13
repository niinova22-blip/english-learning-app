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
    var errorDescription: String? { "The tutor took too long to respond. Please try again." }
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

    struct TutorContext {
        let headword: String
        let definition: String
        let exampleSentences: [String]
        let translationTR: String
    }

    private(set) var state: State = .idle
    private let engine: any TutorEngine
    private let context: TutorContext
    private let timeoutNanoseconds: UInt64

    init(engine: any TutorEngine, context: TutorContext, timeoutSeconds: UInt64 = 30) {
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
        let request = TutorRequest(
            headword: context.headword,
            definition: context.definition,
            exampleSentences: context.exampleSentences,
            translationTR: context.translationTR,
            ask: ask
        )
        do {
            let response = try await respondWithTimeout(to: request)
            state = .response(response)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    private func respondWithTimeout(to request: TutorRequest) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await self.engine.respond(to: request) }
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
