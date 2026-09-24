import Foundation
import SwiftData

/// Bridges SwiftData-persisted UserItemState/ReviewLog to the stateless FSRSScheduler.
public struct FSRSStateStore: Sendable {
    public init() {}

    @discardableResult
    public func recordReview(
        userID: String,
        itemID: String,
        rating: FSRSRating,
        now: Date,
        in context: ModelContext,
        scheduler: FSRSScheduler,
        reactionTimeMs: Int = 0
    ) throws -> UserItemState {
        let state = try stageReview(
            userID: userID, itemID: itemID, rating: rating, now: now,
            in: context, scheduler: scheduler, reactionTimeMs: reactionTimeMs
        )
        try context.save()
        return state
    }

    /// Same as `recordReview` but leaves the context unsaved, so a caller can
    /// commit the review together with other changes in a single save (and
    /// `rollback()` everything if that save fails).
    @discardableResult
    public func stageReview(
        userID: String,
        itemID: String,
        rating: FSRSRating,
        now: Date,
        in context: ModelContext,
        scheduler: FSRSScheduler,
        reactionTimeMs: Int = 0
    ) throws -> UserItemState {
        let stateID = "\(userID)_\(itemID)"
        let descriptor = FetchDescriptor<UserItemState>(predicate: #Predicate { $0.id == stateID })
        let existing = try context.fetch(descriptor).first

        let priorCard = existing.map {
            FSRSCard(stability: $0.stability, difficulty: $0.difficulty, reps: $0.reps, lapses: $0.lapses, lastReviewedAt: $0.lastReviewedAt)
        }
        let result = scheduler.review(card: priorCard, rating: rating, now: now)

        let state: UserItemState
        if let existing {
            existing.apply(result)
            state = existing
        } else {
            state = UserItemState(
                userID: userID,
                itemID: itemID,
                stability: result.card.stability,
                difficulty: result.card.difficulty,
                dueDate: result.dueDate,
                reps: result.card.reps,
                lapses: result.card.lapses,
                lastReviewedAt: result.card.lastReviewedAt
            )
            context.insert(state)
        }

        let log = ReviewLog(userID: userID, itemID: itemID, rating: rating, reviewedAt: now, reactionTimeMs: reactionTimeMs)
        context.insert(log)
        return state
    }
}
