import Foundation
import SwiftData

@Model
public final class Unit {
    @Attribute(.unique) public var id: String
    public var theme: String
    /// Interface-language themes; see `theme(for:)`.
    public var themeEN: String? = nil
    public var themeTR: String? = nil
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
