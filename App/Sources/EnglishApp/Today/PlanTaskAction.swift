import Foundation
import LearningEngine

/// What tapping a plan row does. Vocabulary lessons open the flashcard
/// session; grammar and reading lessons open the practice session (Slice 7a
/// ships content for both). `.comingSoon` now means only "this skill has no
/// content yet" — listening, writing, speaking, pronunciation.
enum PlanTaskAction: Equatable {
    case startReview(cardCount: Int)
    case startLesson(id: String)
    case startPractice(lessonID: String)
    case startPracticeReview(itemID: String, lessonID: String)
    case comingSoon(title: String)
    case locked(title: String)
    case none

    /// Skills that have shipped practice content. Everything else still shows
    /// "This lesson type is coming soon".
    static let skillsWithPracticeContent: Set<Skill> = [.grammar, .reading]

    static func action(for task: PlanTask) -> PlanTaskAction {
        switch task {
        case .review(let count, _, let isDone):
            return isDone ? .none : .startReview(cardCount: count)
        case .lesson(let id, let title, let skill, _, let isDone):
            if isDone { return .none }
            if skill == .vocabulary { return .startLesson(id: id) }
            if skillsWithPracticeContent.contains(skill) { return .startPractice(lessonID: id) }
            return .comingSoon(title: title)
        case .practiceReview(let itemID, let lessonID, _, _, _, let isDone):
            return isDone ? .none : .startPracticeReview(itemID: itemID, lessonID: lessonID)
        case .locked(_, let title):
            return .locked(title: title)
        }
    }
}
