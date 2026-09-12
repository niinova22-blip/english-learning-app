import Foundation
import SwiftData

public enum LearningGoal: String, Codable, CaseIterable, Sendable {
    case yds, toefl, business, conversational, custom
}

@Model
public final class ContentPackage {
    @Attribute(.unique) public var id: String
    public var name: String
    public var goal: LearningGoal
    public var levelLower: String
    public var levelUpper: String
    @Relationship(deleteRule: .cascade, inverse: \Unit.package)
    public var units: [Unit] = []

    public init(id: String, name: String, goal: LearningGoal, levelLower: String, levelUpper: String) {
        self.id = id
        self.name = name
        self.goal = goal
        self.levelLower = levelLower
        self.levelUpper = levelUpper
    }
}
