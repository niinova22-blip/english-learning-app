import Foundation

public enum PackageAccessLevel: Sendable, Equatable {
    case owned, preview
}

/// SwiftData-free snapshot of a package's unit/lesson structure.
public struct UnitOutline: Sendable, Equatable {
    public let id: String
    public let order: Int
    public let lessonIDs: [String]

    public init(id: String, order: Int, lessonIDs: [String]) {
        self.id = id
        self.order = order
        self.lessonIDs = lessonIDs
    }
}

public struct PackageOutline: Sendable, Equatable {
    public let units: [UnitOutline]

    public init(units: [UnitOutline]) {
        self.units = units
    }
}
