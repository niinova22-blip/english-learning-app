import Foundation

/// Maps a finished practice session onto the FSRS vocabulary the rest of the
/// engine already speaks. Topic-level review (spec "Spaced repetition"): the
/// whole lesson is one card, so the session's score — not any single answer —
/// decides the rating, and the rating is applied only on completion.
public enum PracticeScoring {
    /// Grammar topics serve up to 8 questions per session, every other
    /// practice type up to 5, always capped by what the pool actually holds.
    public static func selectionSize(poolCount: Int, skill: Skill) -> Int {
        let target = skill == .grammar ? 8 : 5
        return min(max(poolCount, 0), target)
    }

    /// `< 50%` Again, `50-74%` Hard, `75-99%` Good, `100%` Easy. Boundaries
    /// are inclusive downward: exactly 50% is Hard, exactly 75% is Good.
    /// A session with no questions rates Again — it proves nothing was learned
    /// and must never divide by zero.
    public static func rating(correct: Int, total: Int) -> FSRSRating {
        guard total > 0 else { return .again }
        if correct >= total { return .easy }
        let share = Double(correct) / Double(total)
        if share < 0.5 { return .again }
        if share < 0.75 { return .hard }
        return .good
    }
}
