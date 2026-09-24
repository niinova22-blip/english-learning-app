import Foundation
import SwiftData

/// Coarse CEFR estimate. Because the level test only draws on one curated
/// academic word list, this is an approximation of "how much of this word
/// list you know" rather than a general-language placement result — see the
/// design spec's caveat, surfaced to the learner in Profil.
public enum CEFRLevel: String, Codable, CaseIterable, Sendable {
    case a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1"
}

/// At most one row per user — retaking the level test overwrites it. Purely
/// informational: never read by FSRS scheduling or DailyPlanBuilder.
@Model
public final class LevelTestResult {
    @Attribute(.unique) public var userID: String
    public var cefrLevel: CEFRLevel
    public var vocabularyScore: Double
    public var completedAt: Date

    public init(userID: String, cefrLevel: CEFRLevel, vocabularyScore: Double, completedAt: Date) {
        self.userID = userID
        self.cefrLevel = cefrLevel
        self.vocabularyScore = vocabularyScore
        self.completedAt = completedAt
    }
}
