import Foundation
import SwiftData
import LearningEngine

/// What the tutor is told the learner is working towards. Nil keeps the
/// prompt's original YDS wording (see TutorEngine's `TutorOpening`).
enum TutorGoal {
    static func description(for goal: LearningGoal?) -> String? {
        switch goal {
        case .business: return "improving their business English"
        case .conversational: return "improving their everyday English"
        case .toefl: return "preparing for the TOEFL exam"
        case .yds, .custom, nil: return nil
        }
    }

    /// The description for the learner's active package.
    static func activeDescription(in context: ModelContext, userID: String = UserIdentity.current) -> String? {
        let userIDValue = userID
        guard let profile = try? context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first else { return nil }
        let packageID = profile.activePackageID
        let package = try? context.fetch(FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.id == packageID })).first
        return description(for: package?.goal)
    }
}
