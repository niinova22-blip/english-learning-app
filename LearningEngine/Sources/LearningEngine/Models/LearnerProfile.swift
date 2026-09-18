import Foundation
import SwiftData

/// Per-user learning settings. Exactly one per user; `activePackageID` is the
/// single active goal that drives the daily plan.
@Model
public final class LearnerProfile {
    public static let defaultDailyMinutes = 20

    @Attribute(.unique) public var userID: String
    public var activePackageID: String
    public var dailyMinutes: Int
    public var examDate: Date?
    public var createdAt: Date
    /// Nil until the first-run onboarding flow finishes; `RootTabView` gates
    /// on this.
    public var onboardingCompletedAt: Date?
    /// Tracked separately from `onboardingCompletedAt` so Profil can offer a
    /// "take it now" entry point without conflating a skip with an
    /// incomplete onboarding.
    public var hasSkippedLevelTest: Bool

    public init(
        userID: String, activePackageID: String,
        dailyMinutes: Int = LearnerProfile.defaultDailyMinutes,
        examDate: Date? = nil, createdAt: Date,
        onboardingCompletedAt: Date? = nil, hasSkippedLevelTest: Bool = false
    ) {
        self.userID = userID
        self.activePackageID = activePackageID
        self.dailyMinutes = dailyMinutes
        self.examDate = examDate
        self.createdAt = createdAt
        self.onboardingCompletedAt = onboardingCompletedAt
        self.hasSkippedLevelTest = hasSkippedLevelTest
    }
}
