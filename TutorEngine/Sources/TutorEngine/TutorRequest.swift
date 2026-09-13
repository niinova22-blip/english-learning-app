import Foundation

/// A fixed, no-typing-required thing the learner can ask about the
/// current card.
public enum QuickAction: Sendable, Equatable {
    case simplerExplanation
    case anotherExample
    case compareToSimilarWords
}

/// Either a quick action or a free-text question the learner typed.
public enum TutorAsk: Sendable, Equatable {
    case quickAction(QuickAction)
    case freeText(String)
}

/// Everything needed to answer one tutor ask: the current card's
/// content plus what the learner is asking for. No conversation
/// history — each request is independent.
public struct TutorRequest: Sendable, Equatable {
    public let headword: String
    public let definition: String
    public let exampleSentences: [String]
    public let translationTR: String
    public let ask: TutorAsk

    public init(
        headword: String,
        definition: String,
        exampleSentences: [String],
        translationTR: String,
        ask: TutorAsk
    ) {
        self.headword = headword
        self.definition = definition
        self.exampleSentences = exampleSentences
        self.translationTR = translationTR
        self.ask = ask
    }
}

/// Something that can answer a `TutorRequest`. `MLXTutorEngine` (Task 2)
/// is the real, on-device implementation; test code defines its own
/// fake conforming type rather than sharing one from this package.
public protocol TutorEngine {
    func respond(to request: TutorRequest) async throws -> String
    func respond(to chat: ChatRequest) async throws -> String
}
