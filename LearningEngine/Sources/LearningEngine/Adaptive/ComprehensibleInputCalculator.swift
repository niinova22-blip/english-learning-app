import Foundation

public struct ComprehensibleInputCalculator: Sendable {
    public var tooEasyThreshold: Double
    public var tooHardThreshold: Double

    public init(tooEasyThreshold: Double = 0.85, tooHardThreshold: Double = 0.50) {
        self.tooEasyThreshold = tooEasyThreshold
        self.tooHardThreshold = tooHardThreshold
    }

    /// Bands the candidate `item` purely on `snapshot.rollingComprehensionAccuracy`
    /// (the user's global rolling comprehension accuracy) against
    /// `tooEasyThreshold`/`tooHardThreshold`, or `.optimal` during cold start.
    ///
    /// Known scope limitation (intentional, per the original design): this
    /// does NOT yet use any property of `item` itself (its `frequencyRank`,
    /// `baseDifficulty`, etc.) or `snapshot.knownItemIDs` — the decision is
    /// entirely global/accuracy-based, matching the spec's threshold-based
    /// i+1 algorithm. `item` is accepted for a future per-item-aware version
    /// of this calculation, not because it currently influences the result.
    public func fit(of item: LearningItem, for snapshot: UserLevelSnapshot) -> DifficultyFit {
        if snapshot.isColdStart { return .optimal }
        if snapshot.rollingComprehensionAccuracy >= tooEasyThreshold { return .tooEasy }
        if snapshot.rollingComprehensionAccuracy <= tooHardThreshold { return .tooHard }
        return .optimal
    }
}
