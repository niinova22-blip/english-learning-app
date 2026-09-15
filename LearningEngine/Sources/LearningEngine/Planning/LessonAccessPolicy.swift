import Foundation

/// Owned packages expose every lesson; previews expose only the lessons of
/// the unit with the lowest `order`.
public struct LessonAccessPolicy: Sendable {
    public init() {}

    public func accessibleLessonIDs(in outline: PackageOutline, level: PackageAccessLevel) -> Set<String> {
        switch level {
        case .owned:
            return Set(outline.units.flatMap(\.lessonIDs))
        case .preview:
            guard let firstUnit = outline.units.min(by: { $0.order < $1.order }) else { return [] }
            return Set(firstUnit.lessonIDs)
        }
    }
}
