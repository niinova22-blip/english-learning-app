import Foundation
import SwiftData

public enum LearningItemType: String, Codable, CaseIterable, Sendable {
    case vocabulary, grammarPoint, phrase, collocation
}

@Model
public final class LearningItem {
    @Attribute(.unique) public var id: String
    public var type: LearningItemType
    public var frequencyRank: Int
    public var baseDifficulty: Double
    public var lesson: Lesson?
    @Relationship(deleteRule: .cascade, inverse: \ItemContent.item)
    public var content: ItemContent?

    public init(id: String, type: LearningItemType, frequencyRank: Int, baseDifficulty: Double) {
        self.id = id
        self.type = type
        self.frequencyRank = frequencyRank
        self.baseDifficulty = baseDifficulty
    }
}
