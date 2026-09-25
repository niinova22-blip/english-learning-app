import Foundation

/// When to show Apple's rating prompt: on the day the streak reaches 7, 30
/// or 100 days, once per milestone (Apple itself caps it at 3 a year).
enum ReviewPromptPolicy {
    static let milestones = [7, 30, 100]
    static let promptedKey = "review.promptedMilestones"

    static func milestone(forStreak streak: Int, alreadyPrompted: Set<Int>) -> Int? {
        milestones.contains(streak) && !alreadyPrompted.contains(streak) ? streak : nil
    }

    /// Records and returns the milestone to prompt for, if any.
    static func consume(streak: Int, defaults: UserDefaults = .standard) -> Int? {
        let prompted = Set(defaults.array(forKey: promptedKey) as? [Int] ?? [])
        guard let milestone = milestone(forStreak: streak, alreadyPrompted: prompted) else { return nil }
        defaults.set(Array(prompted.union([milestone])).sorted(), forKey: promptedKey)
        return milestone
    }
}
