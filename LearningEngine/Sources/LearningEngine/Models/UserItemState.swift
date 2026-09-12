import Foundation
import SwiftData

@Model
public final class UserItemState {
    @Attribute(.unique) public var id: String
    public var userID: String
    public var itemID: String
    public var stability: Double
    public var difficulty: Double
    public var dueDate: Date
    public var reps: Int
    public var lapses: Int
    public var lastReviewedAt: Date?

    public init(userID: String, itemID: String, stability: Double, difficulty: Double, dueDate: Date, reps: Int, lapses: Int, lastReviewedAt: Date?) {
        self.id = "\(userID)_\(itemID)"
        self.userID = userID
        self.itemID = itemID
        self.stability = stability
        self.difficulty = difficulty
        self.dueDate = dueDate
        self.reps = reps
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
    }

    func apply(_ result: FSRSReviewResult) {
        stability = result.card.stability
        difficulty = result.card.difficulty
        dueDate = result.dueDate
        reps = result.card.reps
        lapses = result.card.lapses
        lastReviewedAt = result.card.lastReviewedAt
    }
}
