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
    public let learnerLanguage: LearnerLanguage

    public init(
        headword: String,
        definition: String,
        exampleSentences: [String],
        translationTR: String,
        ask: TutorAsk,
        learnerLanguage: LearnerLanguage = .turkish
    ) {
        self.headword = headword
        self.definition = definition
        self.exampleSentences = exampleSentences
        self.translationTR = translationTR
        self.ask = ask
        self.learnerLanguage = learnerLanguage
    }
}

/// Something that can answer tutor asks: a card-scoped `TutorRequest`, a
/// multi-turn `ChatRequest`, a practice-question `QuestionTutorRequest`, or a
/// coach `CoachRequest`, served by one loaded model. `MLXTutorEngine`
/// is the real, on-device implementation; test code defines its own fake
/// conforming types rather than sharing one from this package.
public protocol TutorEngine {
    func respond(to request: TutorRequest) async throws -> String
    func respond(to chat: ChatRequest) async throws -> String
    func respond(to question: QuestionTutorRequest) async throws -> String
    func respond(to coach: CoachRequest) async throws -> String
}

/// Everything needed to answer a tutor ask about one practice question: the
/// question as the learner saw it, the key, and which option they picked.
/// Like `TutorRequest`, it carries no conversation history.
public struct QuestionTutorRequest: Sendable, Equatable {
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int
    /// Nil if the learner opened the tutor before answering.
    public let selectedIndex: Int?
    /// The authored Turkish explanation, so the model does not contradict it.
    public let explanationTR: String
    public let ask: TutorAsk
    /// Body of the reading passage the question belongs to, if any.
    public let passage: String?
    public let learnerLanguage: LearnerLanguage

    public init(
        prompt: String, options: [String], correctIndex: Int,
        selectedIndex: Int?, explanationTR: String, ask: TutorAsk,
        passage: String? = nil,
        learnerLanguage: LearnerLanguage = .turkish
    ) {
        self.passage = passage
        self.prompt = prompt
        self.options = options
        self.correctIndex = correctIndex
        self.selectedIndex = selectedIndex
        self.explanationTR = explanationTR
        self.ask = ask
        self.learnerLanguage = learnerLanguage
    }
}
