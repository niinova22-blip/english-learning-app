import Foundation

/// A deterministic `RandomNumberGenerator` (splitmix64) so question selection
/// can be varied between sessions without becoming untestable: the caller
/// seeds it, the test pins the seed.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        // A zero state would make splitmix64 start from a fixed, degenerate
        // point; substitute the golden-ratio constant it uses as its stride.
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// SwiftData-free snapshot of one question's attempt history, as far as
/// selection cares about it.
public struct QuestionCandidate: Sendable, Equatable {
    public let id: String
    /// The authored order within the lesson; the tie-break for never-attempted
    /// questions, so a first session always runs front to back.
    public let order: Int
    public let lastAttemptedAt: Date?
    /// Outcome of the most recent attempt; nil when never attempted.
    public let lastWasCorrect: Bool?

    public init(id: String, order: Int, lastAttemptedAt: Date?, lastWasCorrect: Bool?) {
        self.id = id
        self.order = order
        self.lastAttemptedAt = lastAttemptedAt
        self.lastWasCorrect = lastWasCorrect
    }
}

/// Picks which questions a practice session serves (spec "Spaced repetition").
/// Priority: never attempted, then last answered wrong, then answered
/// correctly; within every tier, least recently attempted first. Fully
/// deterministic for a given candidate list and RNG state.
public enum PracticeQuestionSelector {
    private static func tier(_ candidate: QuestionCandidate) -> Int {
        guard let wasCorrect = candidate.lastWasCorrect else { return 0 }
        return wasCorrect ? 2 : 1
    }

    public static func select(
        from candidates: [QuestionCandidate],
        size: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [String] {
        guard size > 0, !candidates.isEmpty else { return [] }

        // A per-call random key breaks ties that tier/recency/order cannot,
        // so two identical-history questions don't always appear in the same
        // relative position across sessions. Drawn once per candidate, before
        // sorting, so the comparator stays a pure function of the keys.
        var keyed: [(candidate: QuestionCandidate, key: UInt64)] = []
        keyed.reserveCapacity(candidates.count)
        for candidate in candidates {
            keyed.append((candidate, generator.next()))
        }

        let sorted = keyed.sorted { lhs, rhs in
            let lt = tier(lhs.candidate), rt = tier(rhs.candidate)
            if lt != rt { return lt < rt }
            // Never-attempted questions have no date; authored order decides.
            let ld = lhs.candidate.lastAttemptedAt, rd = rhs.candidate.lastAttemptedAt
            if let ld, let rd, ld != rd { return ld < rd }
            if lhs.candidate.order != rhs.candidate.order {
                return lhs.candidate.order < rhs.candidate.order
            }
            if lhs.key != rhs.key { return lhs.key < rhs.key }
            return lhs.candidate.id < rhs.candidate.id
        }

        return sorted.prefix(size).map(\.candidate.id)
    }
}
