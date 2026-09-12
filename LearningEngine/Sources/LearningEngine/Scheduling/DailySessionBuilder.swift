import Foundation

public struct DailySessionBuilder: Sendable {
    private let scheduler: FSRSScheduler
    private let calculator: ComprehensibleInputCalculator

    public init(scheduler: FSRSScheduler = FSRSScheduler(), calculator: ComprehensibleInputCalculator = ComprehensibleInputCalculator()) {
        self.scheduler = scheduler
        self.calculator = calculator
    }

    public func buildSession(
        candidateItems: [LearningItem],
        dueStates: [UserItemState],
        phase: LearningPhase,
        topicAccuracy: [LearningItemType: Double],
        snapshot: UserLevelSnapshot,
        sessionSize: Int,
        now: Date = Date()
    ) -> [LearningItem] {
        let itemsByID = Dictionary(uniqueKeysWithValues: candidateItems.map { ($0.id, $0) })

        let dueItems = dueStates
            .sorted { lhs, rhs in
                retrievability(of: lhs, at: now) < retrievability(of: rhs, at: now)
            }
            .compactMap { itemsByID[$0.itemID] }

        let dueIDs = Set(dueItems.map(\.id))
        let newCandidates = candidateItems
            .filter { !dueIDs.contains($0.id) }
            .filter { calculator.fit(of: $0, for: snapshot) == .optimal }

        let pool = orderByPhase(dueItems + newCandidates, phase: phase, topicAccuracy: topicAccuracy)
        return Array(pool.prefix(sessionSize))
    }

    private func retrievability(of state: UserItemState, at date: Date) -> Double {
        let card = FSRSCard(stability: state.stability, difficulty: state.difficulty, reps: state.reps, lapses: state.lapses, lastReviewedAt: state.lastReviewedAt)
        return scheduler.retrievability(of: card, at: date)
    }

    private func orderByPhase(_ items: [LearningItem], phase: LearningPhase, topicAccuracy: [LearningItemType: Double]) -> [LearningItem] {
        switch phase {
        case .blocked(let dominantTopic):
            return items.filter { $0.type == dominantTopic }

        case .hybrid(let primaryWeakTopic):
            let weak = items.filter { $0.type == primaryWeakTopic }
            let rest = items.filter { $0.type != primaryWeakTopic }
            return weightedRoundRobin(groups: [(weak, 0.4), (rest, 0.6)])

        case .fullInterleaving:
            let grouped = Dictionary(grouping: items, by: \.type)
            let maxShare = 0.6
            var weights = grouped.keys.reduce(into: [LearningItemType: Double]()) { result, type in
                // Lower accuracy -> higher weight, so the weakest topic gets a
                // bigger share. Topics with no recorded accuracy default to 0.7
                // (moderately known) so unmeasured topics don't dominate.
                result[type] = 1 - (topicAccuracy[type] ?? 0.7)
            }
            normalize(&weights)
            for key in weights.keys { weights[key] = min(weights[key] ?? 0, maxShare) }
            normalize(&weights)
            let groups = grouped.map { (type, groupItems) in (groupItems, weights[type] ?? 0) }
            return weightedRoundRobin(groups: groups)
        }
    }

    private func normalize(_ weights: inout [LearningItemType: Double]) {
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return }
        for key in weights.keys { weights[key]! /= total }
    }

    /// Deficit-style weighted round robin: at each step, emits from whichever
    /// group is furthest behind the share of output its weight entitles it to,
    /// so groups interleave roughly proportionally instead of one group
    /// exhausting itself before the next starts.
    private func weightedRoundRobin(groups: [(items: [LearningItem], weight: Double)]) -> [LearningItem] {
        var remaining = groups.map { $0.items }
        let weights = groups.map { $0.weight }
        var taken = Array(repeating: 0, count: groups.count)
        var result: [LearningItem] = []
        let total = remaining.reduce(0) { $0 + $1.count }

        while result.count < total {
            var bestIndex: Int?
            var bestDeficit = -Double.infinity
            for i in remaining.indices where !remaining[i].isEmpty {
                let deserved = weights[i] * Double(result.count + 1)
                let deficit = deserved - Double(taken[i])
                if deficit > bestDeficit {
                    bestDeficit = deficit
                    bestIndex = i
                }
            }
            guard let index = bestIndex else { break }
            result.append(remaining[index].removeFirst())
            taken[index] += 1
        }
        return result
    }
}
