import Foundation
import SwiftData

@Model
public final class Lesson {
    @Attribute(.unique) public var id: String
    public var order: Int
    public var estimatedDurationMinutes: Int
    public var title: String = ""
    public var skill: Skill = Skill.vocabulary
    public var unit: Unit?
    @Relationship(deleteRule: .cascade, inverse: \LearningItem.lesson)
    public var items: [LearningItem] = []

    public init(id: String, order: Int, estimatedDurationMinutes: Int, title: String = "", skill: Skill = .vocabulary) {
        self.id = id
        self.order = order
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.title = title
        self.skill = skill
    }
}
