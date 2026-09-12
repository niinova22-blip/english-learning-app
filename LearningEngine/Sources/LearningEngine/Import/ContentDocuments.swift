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
}

public struct LessonDocument: Decodable {
    public let id: String
    public let order: Int
    public let estimatedDurationMinutes: Int
    public let items: [LearningItemDocument]
}

public struct UnitDocument: Decodable {
    public let id: String
    public let theme: String
    public let order: Int
    public let lessons: [LessonDocument]
}

public struct ContentPackageDocument: Decodable {
    public let id: String
    public let name: String
    public let goal: String
    public let levelLower: String
    public let levelUpper: String
    public let units: [UnitDocument]
}
