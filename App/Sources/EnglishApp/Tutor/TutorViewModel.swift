import Foundation
import TutorEngine

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
                response = try await withTutorTimeout(nanoseconds: timeoutNanoseconds) { try await self.engine.respond(to: request) }
            case .question(let prompt, let options, let correctIndex, let selectedIndex, let explanationTR, let passage):
                let request = QuestionTutorRequest(
                    prompt: prompt, options: options, correctIndex: correctIndex,
                    selectedIndex: selectedIndex, explanationTR: explanationTR, ask: ask,
                    passage: passage
                )
                response = try await withTutorTimeout(nanoseconds: timeoutNanoseconds) { try await self.engine.respond(to: request) }
            }
            state = .response(response)
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
