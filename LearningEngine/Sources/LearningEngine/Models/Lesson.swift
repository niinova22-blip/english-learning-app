import Foundation
import SwiftData

@Model
public final class Lesson {
    @Attribute(.unique) public var id: String
    public var order: Int
    public var estimatedDurationMinutes: Int
    public var unit: Unit?
    @Relationship(deleteRule: .cascade, inverse: \LearningItem.lesson)
    public var items: [LearningItem] = []

    public init(id: String, order: Int, estimatedDurationMinutes: Int) {
        self.id = id
        self.order = order
        self.estimatedDurationMinutes = estimatedDurationMinutes
    }
}
