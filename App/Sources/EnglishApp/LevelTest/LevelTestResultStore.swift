import Foundation
import SwiftData
import LearningEngine

/// Persists a level-test outcome as the user's single `LevelTestResult`
/// (insert when absent, overwrite when present) and clears the "skipped"
/// flag on their profile, if one exists.
enum LevelTestResultStore {
    static func save(_ outcome: LevelTestOutcome, in context: ModelContext, userID: String, now: Date = Date()) throws {
        if let existing = try context.fetch(FetchDescriptor<LevelTestResult>(predicate: #Predicate { $0.userID == userID })).first {
            existing.cefrLevel = outcome.cefrLevel
            existing.vocabularyScore = outcome.vocabularyScore
            existing.completedAt = now
        } else {
            context.insert(LevelTestResult(userID: userID, cefrLevel: outcome.cefrLevel, vocabularyScore: outcome.vocabularyScore, completedAt: now))
        }
        if let profile = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userID })).first {
            profile.hasSkippedLevelTest = false
        }
        try context.save()
    }
}
