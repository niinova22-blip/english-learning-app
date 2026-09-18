import Foundation
import Observation
import SwiftData
import LearningEngine

struct CoursePathSection: Equatable {
    let unitID: String
    let theme: String
    let tasks: [PlanTask]
}

/// Shows the whole course path (every unit/lesson of the active package),
/// as opposed to TodayPlanCoordinator's "what to do today". Reuses
/// PlanTask/PlanTaskAction/PlanTaskRow exactly as Bugün does — no new study
/// flow.
@MainActor
@Observable
final class CoursePathViewModel {
    private(set) var sections: [CoursePathSection] = []
    private(set) var loadError: String?

    private let context: ModelContext
    private let userID: String
    private let accessProvider: any PackageAccessProvider

    init(context: ModelContext, userID: String, accessProvider: any PackageAccessProvider) {
        self.context = context
        self.userID = userID
        self.accessProvider = accessProvider
    }

    func load() {
        do {
            let coordinator = TodayPlanCoordinator(context: context, userID: userID, accessProvider: accessProvider)
            guard let profile = try coordinator.ensureProfile() else {
                sections = []
                return
            }
            let packageID = profile.activePackageID
            guard let package = try context.fetch(FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.id == packageID })).first else {
                sections = []
                return
            }
            sections = try Self.buildSections(package: package, userID: userID, accessProvider: accessProvider, context: context)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private static func buildSections(package: ContentPackage, userID: String, accessProvider: any PackageAccessProvider, context: ModelContext) throws -> [CoursePathSection] {
        let units = package.units.sorted { $0.order < $1.order }
        let outline = PackageOutline(units: units.map { UnitOutline(id: $0.id, order: $0.order, lessonIDs: $0.lessons.map(\.id)) })
        let accessible = LessonAccessPolicy().accessibleLessonIDs(in: outline, level: accessProvider.accessLevel(forPackageID: package.id))

        let userIDValue = userID
        let progressRows = try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.userID == userIDValue }))
        let completion = Dictionary(uniqueKeysWithValues: progressRows.compactMap { row in row.completedAt.map { (row.lessonID, $0) } })

        return units.map { unit in
            let lessons = unit.lessons.sorted { $0.order < $1.order }
            let tasks: [PlanTask] = lessons.map { lesson in
                if accessible.contains(lesson.id) {
                    return .lesson(id: lesson.id, title: lesson.title, skill: lesson.skill, minutes: Double(lesson.estimatedDurationMinutes), isDone: completion[lesson.id] != nil)
                } else {
                    return .locked(id: lesson.id, title: lesson.title)
                }
            }
            return CoursePathSection(unitID: unit.id, theme: unit.theme, tasks: tasks)
        }
    }
}
