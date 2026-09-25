import Foundation
import SwiftData
import StoreKit
import SwiftUI

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


/// What happens after any study or practice session screen has closed:
/// data listeners (Today, Course, reminders) refresh, and on a streak
/// milestone Apple's rating prompt appears over the now-visible screen.
@MainActor
enum SessionEnd {
    static func finish(appState: AppState, context: ModelContext, requestReview: RequestReviewAction) {
        appState.bumpDataGeneration()
        let coordinator = TodayPlanCoordinator(context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider)
        let streak = (try? coordinator.streak()) ?? 0
        if ReviewPromptPolicy.consume(streak: streak) != nil { requestReview() }
    }
}
