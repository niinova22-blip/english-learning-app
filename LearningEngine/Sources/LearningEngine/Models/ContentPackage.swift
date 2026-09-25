import Foundation
import SwiftData

public enum LearningGoal: String, Codable, CaseIterable, Sendable {
    case yds, toefl, business, conversational, custom

    /// Exam goals talk about an "exam date"; the others about a "target date".
    public var isExam: Bool {
        switch self {
        case .yds, .toefl: return true
        case .business, .conversational, .custom: return false
        }
    }
}

@Model
public final class ContentPackage {
    @Attribute(.unique) public var id: String
    public var name: String
    public var goal: LearningGoal
    public var levelLower: String
    public var levelUpper: String
    public var version: Int = 1
    /// App Store product that unlocks this package; nil for packages that are
    /// not sold (they always stay in preview).
    public var storeProductID: String?
    /// Language the package is written for ("tr" = Turkish speakers);
    /// nil = English-medium, for everyone.
    public var audience: String?
    /// One sentence for the package picker, in the package's medium language.
    public var summary: String?
    /// Interface-language names and summaries; see `name(for:)`.
    public var nameEN: String? = nil
    public var nameTR: String? = nil
    public var summaryEN: String? = nil
    public var summaryTR: String? = nil
    public var weightVocabulary: Double = 1
    public var weightGrammar: Double = 0
    public var weightReading: Double = 0
    public var weightListening: Double = 0
    public var weightWriting: Double = 0
    public var weightSpeaking: Double = 0
    public var weightPronunciation: Double = 0
    @Relationship(deleteRule: .cascade, inverse: \Unit.package)
    public var units: [Unit] = []

    public init(
        id: String, name: String, goal: LearningGoal, levelLower: String, levelUpper: String,
        version: Int = 1, skillWeights: SkillWeights = .vocabularyOnly, storeProductID: String? = nil,
        audience: String? = nil, summary: String? = nil
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.levelLower = levelLower
        self.levelUpper = levelUpper
        self.version = version
        self.skillWeights = skillWeights
        self.storeProductID = storeProductID
        self.audience = audience
        self.summary = summary
    }

    /// Falls back to vocabulary-only if stored values were ever invalid.
    public var skillWeights: SkillWeights {
        get {
            (try? SkillWeights([
                .vocabulary: weightVocabulary, .grammar: weightGrammar, .reading: weightReading,
                .listening: weightListening, .writing: weightWriting, .speaking: weightSpeaking,
                .pronunciation: weightPronunciation
            ])) ?? .vocabularyOnly
        }
        set {
            weightVocabulary = newValue.weight(of: .vocabulary)
            weightGrammar = newValue.weight(of: .grammar)
            weightReading = newValue.weight(of: .reading)
            weightListening = newValue.weight(of: .listening)
            weightWriting = newValue.weight(of: .writing)
            weightSpeaking = newValue.weight(of: .speaking)
            weightPronunciation = newValue.weight(of: .pronunciation)
        }
    }
}
