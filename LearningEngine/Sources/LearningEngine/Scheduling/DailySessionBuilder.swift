import Foundation

public struct DailySessionBuilder: Sendable {
    private let scheduler: FSRSScheduler
    private let calculator: ComprehensibleInputCalculator
    private let maxShare: Double

    public init(
        scheduler: FSRSScheduler = FSRSScheduler(),
        calculator: ComprehensibleInputCalculator = ComprehensibleInputCalculator(),
        maxShare: Double = 0.6
    ) {
        self.scheduler = scheduler
        self.calculator = calculator
        self.maxShare = maxShare
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
        let itemsByID = Dictionary(candidateItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let dueItems = dueStates
            .sorted { lhs, rhs in
                retrievability(of: lhs, at: now) < retrievability(of: rhs, at: now)
            }
            .compactMap { itemsByID[$0.itemID] }

        let dueIDs = Set(dueItems.map(\.id))
        let newCandidates = candidateItems
            .filter { !dueIDs.contains($0.id) }
            .filter { calculator.fit(of: $0, for: snapshot) == .optimal }

        // Due items are FSRS-due reviews, already sorted most-at-risk-first.
        // They always take priority over new content and are never filtered
        // or reordered by topic-mix logic below — only which NEW items get
        // introduced is governed by the phase's topic mix. This guarantees a
        // due item is never silently dropped or pushed behind new content by
        // interleaving logic.
        let orderedNewCandidates = orderNewCandidatesByPhase(newCandidates, phase: phase, topicAccuracy: topicAccuracy)
        let pool = dueItems + orderedNewCandidates
        return Array(pool.prefix(sessionSize))
    }

    private func retrievability(of state: UserItemState, at date: Date) -> Double {
        let card = FSRSCard(stability: state.stability, difficulty: state.difficulty, reps: state.reps, lapses: state.lapses, lastReviewedAt: state.lastReviewedAt)
        return scheduler.retrievability(of: card, at: date)
    }

    /// Orders (and, for `.blocked`, filters) only the NEW candidate items per
    /// the current phase's topic mix. Due items never pass through here.
    private func orderNewCandidatesByPhase(_ items: [LearningItem], phase: LearningPhase, topicAccuracy: [LearningItemType: Double]) -> [LearningItem] {
        switch phase {
        case .blocked(let dominantTopic):
            return items.filter { $0.type == dominantTopic }

        case .hybrid(let primaryWeakTopic):
            let weak = items.filter { $0.type == primaryWeakTopic }
            let rest = items.filter { $0.type != primaryWeakTopic }
            return weightedRoundRobin(groups: [(weak, 0.4), (rest, 0.6)])

        case .fullInterleaving:
            let grouped = Dictionary(grouping: items, by: \.type)
            var weights = grouped.keys.reduce(into: [LearningItemType: Double]()) { result, type in
                // Lower accuracy -> higher weight, so the weakest topic gets a
                // bigger share. Topics with no recorded accuracy default to 0.7
                // (moderately known) so unmeasured topics don't dominate.
                result[type] = 1 - (topicAccuracy[type] ?? 0.7)
            }
            normalize(&weights)
            weights = capShares(weights, maxShare: maxShare)
            let groups = grouped.map { (type, groupItems) in (groupItems, weights[type] ?? 0) }
            return weightedRoundRobin(groups: groups)
        }
    }

    private func normalize(_ weights: inout [LearningItemType: Double]) {
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return }
        for key in weights.keys { weights[key]! /= total }
    }

    /// Caps each group's share at `maxShare` via iterative water-filling:
    /// any group whose (renormalized) share would exceed `maxShare` is
    /// frozen at the cap, and the remaining probability mass is
    /// redistributed proportionally (by original relative weight) across
    /// the still-uncapped groups. Repeats until no uncapped group exceeds
    /// the cap, or only one group remains uncapped, which trivially
    /// receives all remaining mass. Unlike "cap then renormalize", this
    /// does not let renormalization silently undo the cap.
    ///
    /// `weights` must already be normalized (sum to 1); the result also
    /// sums to 1 (modulo floating-point rounding).
    private func capShares(_ weights: [LearningItemType: Double], maxShare: Double) -> [LearningItemType: Double] {
        guard weights.count > 1 else { return weights }

        var finalShares: [LearningItemType: Double] = [:]
        var uncapped = Set(weights.keys)
        var remainingMass = 1.0

        while true {
            if uncapped.count <= 1 {
                if let only = uncapped.first {
                    finalShares[only] = remainingMass
                }
                break
            }

            let uncappedWeightSum = uncapped.reduce(0.0) { $0 + (weights[$1] ?? 0) }
            guard uncappedWeightSum > 0 else { break }

            let newlyCapped = uncapped.filter { type in
                let share = remainingMass * (weights[type]! / uncappedWeightSum)
                return share > maxShare
            }

            if newlyCapped.isEmpty {
                for type in uncapped {
                    finalShares[type] = remainingMass * (weights[type]! / uncappedWeightSum)
                }
                break
            }

            for type in newlyCapped {
                finalShares[type] = maxShare
                remainingMass -= maxShare
                uncapped.remove(type)
            }
        }

        return finalShares
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
