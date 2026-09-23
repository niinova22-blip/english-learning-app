import Foundation
import SwiftData
import LearningEngine

struct LearnerStats: Equatable {
    let streak: Int
    let wordsSeen: Int
    let completedLessons: Int
    let totalLessons: Int
    let packageName: String?
    let accessLevel: PackageAccessLevel?
    let dailyMinutes: Int
}

/// Snapshots SwiftData into the pure planning types.
struct TodayPlanCoordinator {
    let context: ModelContext
    let userID: String
    let accessProvider: any PackageAccessProvider
    let now: Date
    let calendar: Calendar
    let isPremium: Bool

    init(context: ModelContext, userID: String, accessProvider: any PackageAccessProvider, now: Date = Date(), calendar: Calendar = .current, isPremium: Bool = false) {
        self.context = context
        self.userID = userID
        self.accessProvider = accessProvider
        self.now = now
        self.calendar = calendar
        self.isPremium = isPremium
    }

    /// Returns the user's profile, creating or repairing it so it always points
    /// at an installed package. Nil only when no package is installed.
    @discardableResult
    func ensureProfile() throws -> LearnerProfile? {
        let packages = try context.fetch(FetchDescriptor<ContentPackage>(sortBy: [SortDescriptor(\.id)]))
        guard let firstPackage = packages.first else { return nil }
        let userIDValue = userID
        let existing = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first
        if let existing {
            if !packages.contains(where: { $0.id == existing.activePackageID }) {
                existing.activePackageID = firstPackage.id
                try context.save()
            }
            return existing
        }
        let profile = LearnerProfile(userID: userID, activePackageID: firstPackage.id, createdAt: now)
        context.insert(profile)
        try context.save()
        return profile
    }

    func activePackage() throws -> ContentPackage? {
        guard let profile = try ensureProfile() else { return nil }
        let packageID = profile.activePackageID
        return try context.fetch(FetchDescriptor<ContentPackage>(predicate: #Predicate { $0.id == packageID })).first
    }

    private struct PathSnapshot {
        let profile: LearnerProfile
        let package: ContentPackage
        let lessons: [Lesson]
        let planLessons: [PlanLesson]
        let startOfToday: Date
        let pastWeekSkillMinutes: [Skill: Double]
    }

    private func pathSnapshot() throws -> PathSnapshot? {
        guard let profile = try ensureProfile(), let package = try activePackage() else { return nil }
        let units = package.units.sorted { $0.order < $1.order }
        let lessons = units.flatMap { $0.lessons.sorted { $0.order < $1.order } }
        let outline = PackageOutline(units: units.map { unit in
            UnitOutline(id: unit.id, order: unit.order, lessonIDs: unit.lessons.map(\.id))
        })
        let accessible = LessonAccessPolicy().accessibleLessonIDs(in: outline, level: accessProvider.accessLevel(forPackageID: package.id))
        let completion = try completionDates()
        let planLessons = lessons.map { lesson in
            PlanLesson(
                id: lesson.id, title: lesson.title, skill: lesson.skill,
                estimatedMinutes: lesson.estimatedDurationMinutes,
                isAccessible: accessible.contains(lesson.id),
                completedAt: completion[lesson.id]
            )
        }
        let startOfToday = calendar.startOfDay(for: now)
        return PathSnapshot(
            profile: profile, package: package, lessons: lessons, planLessons: planLessons,
            startOfToday: startOfToday,
            pastWeekSkillMinutes: try pastWeekSkillMinutes(startOfToday: startOfToday, lessons: lessons)
        )
    }

    private func coachPlan(_ snapshot: PathSnapshot) -> CoachPlan {
        CoachPlanner(calendar: calendar).plan(CoachInput(
            startOfToday: snapshot.startOfToday,
            examDate: snapshot.profile.examDate,
            dailyMinutes: snapshot.profile.dailyMinutes,
            profileCreatedAt: snapshot.profile.createdAt,
            lessonsInPathOrder: snapshot.planLessons,
            weights: snapshot.package.skillWeights,
            pastWeekSkillMinutes: snapshot.pastWeekSkillMinutes
        ))
    }

    func buildPlanInput() throws -> DailyPlanInput? {
        guard let snapshot = try pathSnapshot() else { return nil }
        let startOfToday = snapshot.startOfToday
        let userIDValue = userID
        let nowValue = now
        let existingItemIDs = try existingItemIDs()
        let practiceIndex = try practiceItemIndex()
        let dueNowRows = try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue && $0.dueDate <= nowValue }))
        let todaysLogs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.userID == userIDValue && $0.reviewedAt >= startOfToday }))
        let reviewedTodayIDs = Set(todaysLogs.filter { existingItemIDs.contains($0.itemID) }.map(\.itemID))

        // Practice cards live in UserItemState exactly like vocabulary items,
        // so the vocabulary review task must exclude them explicitly or it
        // would count grammar topics as due words.
        let dueVocabularyRows = dueNowRows.filter { existingItemIDs.contains($0.itemID) && practiceIndex[$0.itemID] == nil }
        let dueNowCount = dueVocabularyRows.count
        let reviewedTodayCount = reviewedTodayIDs.subtracting(practiceIndex.keys).count

        let duePracticeCards: [DuePracticeCard] = dueNowRows.compactMap { state in
            guard let entry = practiceIndex[state.itemID] else { return nil }
            return DuePracticeCard(
                itemID: state.itemID, lessonID: entry.lessonID, title: entry.title,
                skill: entry.skill, dueDate: state.dueDate,
                isDone: reviewedTodayIDs.contains(state.itemID)
            )
        }

        return DailyPlanInput(
            weights: snapshot.package.skillWeights,
            dailyMinutes: snapshot.profile.dailyMinutes,
            lessonsInPathOrder: snapshot.planLessons,
            dueNowCount: dueNowCount,
            reviewedTodayCount: reviewedTodayCount,
            pastWeekSkillMinutes: snapshot.pastWeekSkillMinutes,
            startOfToday: startOfToday,
            duePracticeCards: duePracticeCards,
            coach: isPremium ? coachPlan(snapshot).directive : nil
        )
    }

    func buildPlan() throws -> DailyPlan? {
        try buildPlanInput().map { DailyPlanBuilder().build($0) }
    }

    /// The coach's view of today. Independent of premium: the view decides
    /// whether to show it or a locked teaser.
    func buildCoachBriefing() throws -> CoachBriefing? {
        guard let snapshot = try pathSnapshot() else { return nil }
        let plan = coachPlan(snapshot)
        guard let weekStart = calendar.date(byAdding: .day, value: -7, to: snapshot.startOfToday) else { return nil }
        let userIDValue = userID
        let today = snapshot.startOfToday
        let weekLogs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate {
            $0.userID == userIDValue && $0.reviewedAt >= weekStart && $0.reviewedAt < today
        }))
        let weekCompletions = try completionDates().values.filter { $0 >= weekStart && $0 < today }
        let studiedDays = Set((weekLogs.map(\.reviewedAt) + weekCompletions).map { calendar.startOfDay(for: $0) })
        return CoachBriefing(
            plan: plan,
            weekDaysStudied: studiedDays.count,
            weekMinutes: Int(snapshot.pastWeekSkillMinutes.values.reduce(0, +).rounded()),
            weekLessonsCompleted: weekCompletions.count,
            streak: try streak()
        )
    }

    func streak() throws -> Int {
        let userIDValue = userID
        let logs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.userID == userIDValue }))
        let completions = try completionDates().values
        return StreakCalculator.streak(activityDates: logs.map(\.reviewedAt) + completions, now: now, calendar: calendar)
    }

    func stats() throws -> LearnerStats {
        let profile = try ensureProfile()
        let package = try activePackage()
        let userIDValue = userID
        let existingItemIDs = try existingItemIDs()
        let practiceIndex = try practiceItemIndex()
        let itemStates = try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue }))
        let wordsSeen = itemStates.filter { existingItemIDs.contains($0.itemID) && practiceIndex[$0.itemID] == nil }.count
        let lessonIDs = Set(package?.units.flatMap { $0.lessons.map(\.id) } ?? [])
        let completed = try completionDates().keys.filter { lessonIDs.contains($0) }.count
        return LearnerStats(
            streak: try streak(),
            wordsSeen: wordsSeen,
            completedLessons: completed,
            totalLessons: lessonIDs.count,
            packageName: package?.name,
            accessLevel: package.map { accessProvider.accessLevel(forPackageID: $0.id) },
            dailyMinutes: profile?.dailyMinutes ?? LearnerProfile.defaultDailyMinutes
        )
    }

    /// The set of item IDs that currently exist in the installed content.
    /// Per the design spec's global rule, progress rows (UserItemState,
    /// ReviewLog) referencing an itemID outside this set are orphans left
    /// behind by a content version upgrade that renamed/removed items, and
    /// every reader (stats, buildPlanInput) must ignore them.
    private func existingItemIDs() throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<LearningItem>()).map(\.id))
    }

    /// itemID → (lesson id, lesson title, lesson skill) for every grammar
    /// topic / practice set in the installed content.
    private func practiceItemIndex() throws -> [String: (lessonID: String, title: String, skill: Skill)] {
        var index: [String: (lessonID: String, title: String, skill: Skill)] = [:]
        for item in try context.fetch(FetchDescriptor<LearningItem>()) where !item.type.isVocabularyCard {
            guard let lesson = item.lesson else { continue }
            index[item.id] = (lesson.id, lesson.title, Skill.forItem(type: item.type, lessonSkill: lesson.skill))
        }
        return index
    }

    /// lessonID → completion date, for this user's completed lessons.
    private func completionDates() throws -> [String: Date] {
        let userIDValue = userID
        let progress = try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.userID == userIDValue }))
        var result: [String: Date] = [:]
        for row in progress {
            if let completedAt = row.completedAt { result[row.lessonID] = completedAt }
        }
        return result
    }

    private func pastWeekSkillMinutes(startOfToday: Date, lessons: [Lesson]) throws -> [Skill: Double] {
        guard let windowStart = calendar.date(byAdding: .day, value: -7, to: startOfToday) else { return [:] }
        var minutes: [Skill: Double] = [:]

        let lessonsByID = Dictionary(lessons.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (lessonID, completedAt) in try completionDates() where completedAt >= windowStart && completedAt < startOfToday {
            guard let lesson = lessonsByID[lessonID] else { continue }
            minutes[lesson.skill, default: 0] += Double(lesson.estimatedDurationMinutes)
        }

        let userIDValue = userID
        let logs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate {
            $0.userID == userIDValue && $0.reviewedAt >= windowStart && $0.reviewedAt < startOfToday
        }))
        if !logs.isEmpty {
            let items = try context.fetch(FetchDescriptor<LearningItem>())
            let skillByID = Dictionary(
                items.map { ($0.id, Skill.forItem(type: $0.type, lessonSkill: $0.lesson?.skill)) },
                uniquingKeysWith: { first, _ in first }
            )
            for log in logs {
                guard let skill = skillByID[log.itemID] else { continue }
                minutes[skill, default: 0] += DailyPlanBuilder.minutesPerReviewCard
            }
        }
        return minutes
    }
}
