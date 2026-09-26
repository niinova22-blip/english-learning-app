import Foundation

/// Step-by-step lesson cards for a grammar topic, written in both interface
/// languages. Stored as JSON on `ItemContent.lessonCardsJSON`; a grammar item
/// without cards keeps showing its old `explanationTR` text.
public struct LessonCards: Codable, Equatable, Sendable {
    /// One piece of the English formula; `role` (subject|verb|aux|object|other)
    /// picks its color.
    public struct PatternPart: Codable, Equatable, Sendable {
        public let text: String
        public let role: String
        public init(text: String, role: String) { self.text = text; self.role = role }
    }

    public struct Example: Codable, Equatable, Sendable {
        public let en: String
        public let tr: String
        /// The word(s) of `en` to emphasize.
        public let highlight: String
        public init(en: String, tr: String, highlight: String) { self.en = en; self.tr = tr; self.highlight = highlight }
    }

    public struct Mistake: Codable, Equatable, Sendable {
        public let wrong: String
        public let right: String
        public let note: LocalizedTextDocument
        public init(wrong: String, right: String, note: LocalizedTextDocument) { self.wrong = wrong; self.right = right; self.note = note }
    }

    public struct Topic: Codable, Equatable, Sendable {
        public let title: LocalizedTextDocument
        public let purpose: LocalizedTextDocument
        public let pattern: [PatternPart]
        public let patternNote: LocalizedTextDocument?
        public let examples: [Example]
        public let mistake: Mistake
        public init(
            title: LocalizedTextDocument, purpose: LocalizedTextDocument, pattern: [PatternPart],
            patternNote: LocalizedTextDocument?, examples: [Example], mistake: Mistake
        ) {
            self.title = title
            self.purpose = purpose
            self.pattern = pattern
            self.patternNote = patternNote
            self.examples = examples
            self.mistake = mistake
        }
    }

    /// A single warm-up question shown after the cards (3 options).
    public struct Check: Codable, Equatable, Sendable {
        public let prompt: String
        public let options: [String]
        public let correctIndex: Int
        public let explanation: LocalizedTextDocument
        public init(prompt: String, options: [String], correctIndex: Int, explanation: LocalizedTextDocument) {
            self.prompt = prompt
            self.options = options
            self.correctIndex = correctIndex
            self.explanation = explanation
        }
    }

    public let topics: [Topic]
    public let check: Check
    /// YDS only: the exam trap for this topic.
    public let examTip: LocalizedTextDocument?

    public init(topics: [Topic], check: Check, examTip: LocalizedTextDocument?) {
        self.topics = topics
        self.check = check
        self.examTip = examTip
    }
}

extension LocalizedTextDocument {
    /// The requested side, else the other side, else "" — never a blank block.
    public func text(for code: String) -> String {
        func nonBlank(_ value: String?) -> String? {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        let (first, second) = code == "tr" ? (tr, en) : (en, tr)
        return nonBlank(first) ?? nonBlank(second) ?? ""
    }
}

extension ItemContent {
    /// Decoded `lessonCardsJSON`; nil when absent or unreadable.
    public var lessonCards: LessonCards? {
        guard let lessonCardsJSON, let data = lessonCardsJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LessonCards.self, from: data)
    }
}

extension Question {
    /// Answer explanation in the interface language; the base `explanationTR`
    /// (which is English in English-medium packages) when that side is missing.
    public func explanation(for languageCode: String) -> String {
        LocalizedTitles.pick(base: explanationTR, en: explanationEN, tr: explanationTRText, languageCode: languageCode)
    }
}

extension ContentPackage {
    /// The package intro paragraph, the other language when one side is
    /// missing, nil when the package has none.
    public func intro(for languageCode: String) -> String? {
        let text = LocalizedTextDocument(en: introEN, tr: introTR).text(for: languageCode)
        return text.isEmpty ? nil : text
    }
}
