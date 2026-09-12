import Foundation
import SwiftData

@Model
public final class Unit {
    @Attribute(.unique) public var id: String
    public var theme: String
    public var order: Int
    public var package: ContentPackage?
    @Relationship(deleteRule: .cascade, inverse: \Lesson.unit)
    public var lessons: [Lesson] = []

    public init(id: String, theme: String, order: Int) {
        self.id = id
        self.theme = theme
        self.order = order
    }
}
