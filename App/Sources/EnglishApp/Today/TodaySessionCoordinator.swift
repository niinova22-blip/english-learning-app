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

    /// The review queue: due items the learner has already seen. Never-seen
    /// items are introduced only through lessons (StudySessionViewModel).
    func buildTodaySession() throws -> [LearningItem] {
        let userIDValue = userID
        let allStates = try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue }))
        let seenIDs = Set(allStates.map(\.itemID))
        let seenItems = try context.fetch(FetchDescriptor<LearningItem>()).filter { seenIDs.contains($0.id) && $0.content != nil && $0.type.isVocabularyCard }
        let dueStates = allStates.filter { $0.dueDate <= now }

        return DailySessionBuilder().buildSession(
            candidateItems: seenItems,
            dueStates: dueStates,
            phase: .fullInterleaving,
            topicAccuracy: [:],
            snapshot: try computeSnapshot(),
            sessionSize: sessionSize,
            now: now
        )
        .filter { item in dueStates.contains { $0.itemID == item.id } }
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
