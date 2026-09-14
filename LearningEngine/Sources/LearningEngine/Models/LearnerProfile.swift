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

    public init(
        userID: String, activePackageID: String,
        dailyMinutes: Int = LearnerProfile.defaultDailyMinutes,
        examDate: Date? = nil, createdAt: Date
    ) {
        self.userID = userID
        self.activePackageID = activePackageID
        self.dailyMinutes = dailyMinutes
        self.examDate = examDate
        self.createdAt = createdAt
    }
}
