import Foundation

/// FSRS-6 scheduler, ported from open-spaced-repetition/py-fsrs
/// (fsrs/scheduler.py), verified against that source on 2026-09-12.
public struct FSRSScheduler: Sendable {
    private static let stabilityMin = 0.001
    private static let difficultyMin = 1.0
    private static let difficultyMax = 10.0

    public let weights: FSRSWeights
    public let requestedRetention: Double
    public let maximumIntervalDays: Double

    private var decay: Double { -weights.values[20] }
    private var factor: Double { pow(0.9, 1 / decay) - 1 }

    public init(weights: FSRSWeights = .default, requestedRetention: Double = 0.9, maximumIntervalDays: Double = 36500) {
        precondition(requestedRetention > 0 && requestedRetention < 1, "requestedRetention must be in (0, 1)")
        self.weights = weights
        self.requestedRetention = requestedRetention
        self.maximumIntervalDays = maximumIntervalDays
    }

    public func retrievability(of card: FSRSCard, at date: Date) -> Double {
        guard let last = card.lastReviewedAt else { return 0 }
        let elapsedDays = Double(max(0, Calendar.current.dateComponents([.day], from: last, to: date).day ?? 0))
        return pow(1 + factor * elapsedDays / card.stability, decay)
    }

    public func review(card: FSRSCard?, rating: FSRSRating, now: Date) -> FSRSReviewResult {
        let w = weights.values
        let newCard: FSRSCard
        if let card, card.reps > 0 {
            // IMPORTANT: both stability formulas below must use card.difficulty
            // (the OLD, pre-review difficulty), never the new one computed after
            // this block. The real py-fsrs reference computes stability first
            // from the old difficulty, then updates difficulty afterward —
            // verified directly against open-spaced-repetition/py-fsrs
            // scheduler.py's `review_card` (State.Review branch).
            let r = retrievability(of: card, at: now)
            let newStability: Double
            if rating == .again {
                // _next_forget_stability: the real reference also caps this
                // long-term formula with a short-term cap (w[17], w[18]) via
                // min().
                let longTerm = w[11] * pow(card.difficulty, -w[12]) * (pow(card.stability + 1, w[13]) - 1) * exp((1 - r) * w[14])
                let shortTerm = card.stability / exp(w[17] * w[18])
                newStability = min(longTerm, shortTerm)
            } else {
                let hardPenalty = rating == .hard ? w[15] : 1
                let easyBonus = rating == .easy ? w[16] : 1
                newStability = card.stability * (1 + exp(w[8]) * (11 - card.difficulty) * pow(card.stability, -w[9]) * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus)
            }
            let newDifficulty = nextDifficulty(previous: card.difficulty, rating: rating, w: w)
            newCard = FSRSCard(
                stability: clampStability(newStability),
                difficulty: newDifficulty,
                reps: card.reps + 1,
                lapses: card.lapses + (rating == .again ? 1 : 0),
                lastReviewedAt: now
            )
        } else {
            let initialStability = clampStability(w[rating.rawValue - 1])
            let initialDifficulty = clampDifficulty(w[4] - exp(w[5] * Double(rating.rawValue - 1)) + 1)
            newCard = FSRSCard(
                stability: initialStability,
                difficulty: initialDifficulty,
                reps: 1,
                lapses: rating == .again ? 1 : 0,
                lastReviewedAt: now
            )
        }
        let intervalDays = nextIntervalDays(stability: newCard.stability)
        let dueDate = Calendar.current.date(byAdding: .day, value: Int(intervalDays.rounded()), to: now) ?? now
        return FSRSReviewResult(card: newCard, dueDate: dueDate)
    }

    private func nextDifficulty(previous: Double, rating: FSRSRating, w: [Double]) -> Double {
        let easyReference = w[4] - exp(w[5] * Double(FSRSRating.easy.rawValue - 1)) + 1
        let deltaDifficulty = -(w[6] * (Double(rating.rawValue) - 3))
        let damped = previous + (10.0 - previous) * deltaDifficulty / 9.0
        let reverted = w[7] * easyReference + (1 - w[7]) * damped
        return clampDifficulty(reverted)
    }

    private func nextIntervalDays(stability: Double) -> Double {
        let raw = (stability / factor) * (pow(requestedRetention, 1 / decay) - 1)
        return min(max(raw, 1), maximumIntervalDays)
    }

    private func clampStability(_ value: Double) -> Double { max(value, Self.stabilityMin) }
    private func clampDifficulty(_ value: Double) -> Double { min(max(value, Self.difficultyMin), Self.difficultyMax) }
}

public struct FSRSReviewResult: Sendable, Equatable {
    public let card: FSRSCard
    public let dueDate: Date
}
