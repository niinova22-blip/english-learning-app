import Foundation

public struct ComprehensibleInputCalculator: Sendable {
    public var tooEasyThreshold: Double
    public var tooHardThreshold: Double

    public init(tooEasyThreshold: Double = 0.85, tooHardThreshold: Double = 0.50) {
        self.tooEasyThreshold = tooEasyThreshold
        self.tooHardThreshold = tooHardThreshold
    }

    public func fit(of item: LearningItem, for snapshot: UserLevelSnapshot) -> DifficultyFit {
        if snapshot.isColdStart { return .optimal }
        if snapshot.rollingComprehensionAccuracy >= tooEasyThreshold { return .tooEasy }
        if snapshot.rollingComprehensionAccuracy <= tooHardThreshold { return .tooHard }
        return .optimal
    }
}
