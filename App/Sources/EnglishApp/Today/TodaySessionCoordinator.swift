import Foundation
import SwiftData
import LearningEngine

struct TodaySessionCoordinator {
    let context: ModelContext
    let userID: String
    let sessionSize: Int
    let now: Date

    init(context: ModelContext, userID: String, sessionSize: Int = 10, now: Date = Date()) {
        self.context = context
        self.userID = userID
        self.sessionSize = sessionSize
        self.now = now
    }

    func buildTodaySession() throws -> [LearningItem] {
        let allItems = try context.fetch(FetchDescriptor<LearningItem>())

        let userIDValue = userID
        let statesDescriptor = FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue })
        let allStates = try context.fetch(statesDescriptor)
        let dueStates = allStates.filter { $0.dueDate <= now }

        let snapshot = try computeSnapshot()
        let builder = DailySessionBuilder()
        var session = builder.buildSession(
            candidateItems: allItems,
            dueStates: dueStates,
            phase: .fullInterleaving,
            topicAccuracy: [:],
            snapshot: snapshot,
            sessionSize: sessionSize,
            now: now
        )

        // The engine's own comprehensible-input filtering can judge every
        // candidate "too easy" once rolling accuracy climbs (e.g. after one
        // all-Good/Easy session), even for items the user has literally never
        // seen. That's a legitimate difficulty judgment for items with review
        // history, but it should never be able to permanently lock away
        // never-reviewed content (no matching UserItemState row at all) — so
        // if the engine comes up short of sessionSize, backfill from
        // never-seen items, bypassing the i+1 filter for those specifically.
        // This is intentionally NOT redundant with the engine's filtering:
        // it only rescues items the filter can never legitimately reconsider
        // on a later day, since "too easy" doesn't decay for content that's
        // never been attempted.
        if session.count < sessionSize {
            let sessionIDs = Set(session.map(\.id))
            let seenItemIDs = Set(allStates.map(\.itemID))
            let backfill = allItems
                .filter { !seenItemIDs.contains($0.id) && !sessionIDs.contains($0.id) }
                .prefix(sessionSize - session.count)
            session.append(contentsOf: backfill)
        }

        return session
    }

    /// Rolling accuracy over the last 20 reviews; cold-start (per
    /// ComprehensibleInputCalculator's own handling) if there's no history
    /// yet. `averageReactionTimeMs` stays 0 in this slice since the UI
    /// doesn't measure real reaction time yet — a known v1 limitation, not
    /// a bug: it only means a user with a genuine 0% accuracy is treated
    /// as cold-start rather than "too hard," which is a benign default.
    func computeSnapshot() throws -> UserLevelSnapshot {
        let userIDValue = userID
        var descriptor = FetchDescriptor<ReviewLog>(
            predicate: #Predicate { $0.userID == userIDValue },
            sortBy: [SortDescriptor(\.reviewedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 20
        let recentLogs = try context.fetch(descriptor)

        guard !recentLogs.isEmpty else {
            return UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0, averageReactionTimeMs: 0)
        }

        let goodOrEasyCount = recentLogs.filter { $0.rating == .good || $0.rating == .easy }.count
        let accuracy = Double(goodOrEasyCount) / Double(recentLogs.count)
        let avgReactionTime = recentLogs.reduce(0.0) { $0 + Double($1.reactionTimeMs) } / Double(recentLogs.count)

        return UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: accuracy, averageReactionTimeMs: avgReactionTime)
    }
}
