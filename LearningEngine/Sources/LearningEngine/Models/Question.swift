import Foundation
import SwiftData

public enum QuestionKind: String, Codable, CaseIterable, Sendable {
    case grammar, reading, cloze, sentenceCompletion, translation
    case paragraphCompletion, irrelevantSentence, dialogueCompletion, restatement, strategy
}

/// One multiple-choice question. Always exactly five options (YDS format,
/// shown as A-E); `correctIndex` is 0-4. Options keep their authored order —
/// 7a deliberately does not shuffle them.
@Model
public final class Question {
    @Attribute(.unique) public var id: String
    public var prompt: String = ""
    public var options: [String] = []
    public var correctIndex: Int = 0
    public var explanationTR: String = ""
    public var kind: QuestionKind = QuestionKind.grammar
    public var order: Int = 0
    public var lesson: Lesson?
    public var passage: Passage?

    public init(
        id: String, prompt: String, options: [String], correctIndex: Int,
        explanationTR: String, kind: QuestionKind, order: Int
    ) {
        self.id = id
        self.prompt = prompt
        self.options = options
        self.correctIndex = correctIndex
        self.explanationTR = explanationTR
        self.kind = kind
        self.order = order
    }
}
