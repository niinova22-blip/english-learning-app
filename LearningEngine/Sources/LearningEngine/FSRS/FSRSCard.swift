import Foundation

public struct FSRSCard: Sendable, Equatable {
    public var stability: Double
    public var difficulty: Double
    public var reps: Int
    public var lapses: Int
    public var lastReviewedAt: Date?

    public init(stability: Double, difficulty: Double, reps: Int, lapses: Int, lastReviewedAt: Date?) {
        self.stability = stability
        self.difficulty = difficulty
        self.reps = reps
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
    }
}
