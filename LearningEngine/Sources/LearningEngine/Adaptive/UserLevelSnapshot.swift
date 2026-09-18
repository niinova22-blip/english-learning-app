import Foundation

public struct UserLevelSnapshot: Sendable, Equatable {
    public var knownItemIDs: Set<String>
    public var rollingComprehensionAccuracy: Double
    public var averageReactionTimeMs: Double

    public init(knownItemIDs: Set<String>, rollingComprehensionAccuracy: Double, averageReactionTimeMs: Double) {
        self.knownItemIDs = knownItemIDs
        self.rollingComprehensionAccuracy = rollingComprehensionAccuracy
        self.averageReactionTimeMs = averageReactionTimeMs
    }

    /// True when there's no meaningful review history yet (both fields still at their defaults).
    public var isColdStart: Bool {
        rollingComprehensionAccuracy == 0 && averageReactionTimeMs == 0
    }
}
