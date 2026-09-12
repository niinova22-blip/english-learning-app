import XCTest
@testable import LearningEngine

final class DailySessionBuilderTests: XCTestCase {
    let builder = DailySessionBuilder()
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func item(_ id: String, _ type: LearningItemType) -> LearningItem {
        LearningItem(id: id, type: type, frequencyRank: 1000, baseDifficulty: 0.5)
    }

    func test_buildSession_prioritizesLowestRetrievabilityDueItems() {
        // Different topics on purpose: if topic-interleaving logic were
        // allowed to reorder due items, a same-topic pair wouldn't catch it
        // (weightedRoundRobin has no reason to reorder within one group),
        // but two different topics would expose that bug.
        let staleItem = item("stale", .vocabulary)
        let freshItem = item("fresh", .grammarPoint)
        let staleState = UserItemState(userID: "u1", itemID: "stale", stability: 2, difficulty: 5, dueDate: now, reps: 1, lapses: 0, lastReviewedAt: Calendar.current.date(byAdding: .day, value: -10, to: now))
        let freshState = UserItemState(userID: "u1", itemID: "fresh", stability: 2, difficulty: 5, dueDate: now, reps: 1, lapses: 0, lastReviewedAt: Calendar.current.date(byAdding: .day, value: -1, to: now))

        let session = builder.buildSession(
            candidateItems: [staleItem, freshItem],
            dueStates: [staleState, freshState],
            phase: .fullInterleaving,
            topicAccuracy: [:],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.7, averageReactionTimeMs: 1000),
            sessionSize: 2,
            now: now
        )

        XCTAssertEqual(session.first?.id, "stale", "the item closer to being forgotten should come first")
    }

    func test_buildSession_blockedPhase_onlyIncludesSingleDominantTopic() {
        let items = [item("verb-1", .grammarPoint), item("verb-2", .grammarPoint), item("noun-1", .vocabulary)]

        let session = builder.buildSession(
            candidateItems: items,
            dueStates: [],
            phase: .blocked(dominantTopic: .grammarPoint),
            topicAccuracy: [:],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0, averageReactionTimeMs: 0),
            sessionSize: 5,
            now: now
        )

        XCTAssertTrue(session.allSatisfy { $0.type == .grammarPoint })
    }

    func test_buildSession_blockedPhase_stillIncludesDueItemsOutsideDominantTopic() {
        // A due item from a non-dominant topic must never be silently
        // dropped by blocked-phase filtering -- only new candidates are
        // topic-filtered in `.blocked`.
        let dueVocabItem = item("noun-due", .vocabulary)
        let newGrammarItems = [item("verb-1", .grammarPoint), item("verb-2", .grammarPoint)]
        let dueState = UserItemState(userID: "u1", itemID: "noun-due", stability: 2, difficulty: 5, dueDate: now, reps: 1, lapses: 0, lastReviewedAt: Calendar.current.date(byAdding: .day, value: -10, to: now))

        let session = builder.buildSession(
            candidateItems: [dueVocabItem] + newGrammarItems,
            dueStates: [dueState],
            phase: .blocked(dominantTopic: .grammarPoint),
            topicAccuracy: [:],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0, averageReactionTimeMs: 0),
            sessionSize: 5,
            now: now
        )

        XCTAssertTrue(session.contains { $0.id == "noun-due" }, "due item outside the dominant topic must not be dropped")
        XCTAssertEqual(session.first?.id, "noun-due", "due item should be prioritized ahead of new candidates")
    }

    func test_buildSession_fullInterleaving_favorsWeakestTopic() {
        let phrasalItems = (0..<10).map { item("phrasal-\($0)", .phrase) }
        let vocabItems = (0..<10).map { item("vocab-\($0)", .vocabulary) }

        let session = builder.buildSession(
            candidateItems: phrasalItems + vocabItems,
            dueStates: [],
            phase: .fullInterleaving,
            topicAccuracy: [.phrase: 0.40, .vocabulary: 0.95],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.7, averageReactionTimeMs: 1000),
            sessionSize: 10,
            now: now
        )

        let phrasalCount = session.filter { $0.type == .phrase }.count
        XCTAssertGreaterThan(phrasalCount, session.count / 2, "weakest topic (phrasal verbs, 40% accuracy) should dominate the session")

        let maxShare = 0.6
        let cap = Int((maxShare * Double(session.count)).rounded(.up))
        XCTAssertLessThanOrEqual(phrasalCount, cap, "no single topic should exceed the configured max share, even when it would otherwise dominate")
    }

    func test_buildSession_respectsSessionSize() {
        let items = (0..<50).map { item("item-\($0)", .vocabulary) }
        let session = builder.buildSession(
            candidateItems: items,
            dueStates: [],
            phase: .fullInterleaving,
            topicAccuracy: [:],
            snapshot: UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.7, averageReactionTimeMs: 1000),
            sessionSize: 12,
            now: now
        )
        XCTAssertEqual(session.count, 12)
    }
}
