import Foundation
import LearningEngine

/// What tapping a plan row does. Only vocabulary lessons have a lesson
/// screen in 6a; other lesson skills arrive with their content (Slice 7).
enum PlanTaskAction: Equatable {
    case startReview(cardCount: Int)
    case startLesson(id: String)
    case comingSoon(title: String)
    case locked(title: String)
    case none

    static func action(for task: PlanTask) -> PlanTaskAction {
        switch task {
        case .review(let count, _, let isDone):
            return isDone ? .none : .startReview(cardCount: count)
        case .lesson(let id, let title, let skill, _, let isDone):
            if isDone { return .none }
            return skill == .vocabulary ? .startLesson(id: id) : .comingSoon(title: title)
        case .locked(_, let title):
            return .locked(title: title)
        }
    }
}
