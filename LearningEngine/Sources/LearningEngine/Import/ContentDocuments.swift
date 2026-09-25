import Foundation

public struct LearningItemDocument: Decodable {
    public let id: String
    public let type: String
    public let headword: String
    public let frequencyRank: Int
    public let baseDifficulty: Double
    public let definition: String
    public let exampleSentences: [String]
    public let translationTR: String
    public let collocations: [String]
    /// Grammar topic explanation (Turkish). Absent for vocabulary items.
    public let explanationTR: String?
}

public struct PassageDocument: Decodable {
    public let id: String
    public let title: String
    public let body: String
}

public struct QuestionDocument: Decodable {
    public let id: String
    public let kind: String
    public let order: Int
    public let prompt: String
    public let options: [String]
    public let correctIndex: Int
    public let explanationTR: String
    /// Set on reading and cloze questions; must match the owning lesson's
    /// passage id.
    public let passageID: String?
}

public struct LessonDocument: Decodable {
    public let id: String
    public let order: Int
    public let estimatedDurationMinutes: Int
    public let title: String
    public let skill: String
    public let items: [LearningItemDocument]
    public let passage: PassageDocument?
    public let questions: [QuestionDocument]?
    /// Optional interface-language titles; `title` is the fallback.
    public let titleLocalized: LocalizedTextDocument?
}

public struct UnitDocument: Decodable {
    public let id: String
    public let theme: String
    public let order: Int
    public let lessons: [LessonDocument]
    public let themeLocalized: LocalizedTextDocument?
}

public struct ContentPackageDocument: Decodable {
    public let id: String
    public let name: String
    public let goal: String
    public let levelLower: String
    public let levelUpper: String
    public let version: Int
    /// Optional App Store product id; absent for packages that are not sold.
    public let storeProductID: String?
    /// Optional: "tr" for Turkish-medium packages; absent = everyone.
    public let audience: String?
    /// Optional one-line description for the package picker.
    public let summary: String?
    public let nameLocalized: LocalizedTextDocument?
    public let summaryLocalized: LocalizedTextDocument?
    /// Keyed by `Skill` raw value; validated and converted by `ContentImporter`.
    public let skillWeights: [String: Double]
    public let units: [UnitDocument]
}
