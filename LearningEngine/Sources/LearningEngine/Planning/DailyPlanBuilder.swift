import Foundation

public struct PlanLesson: Sendable, Equatable {
    public let id: String
    public let title: String
    public let skill: Skill
    public let estimatedMinutes: Int
    public let isAccessible: Bool
    public let completedAt: Date?

    public init(id: String, title: String, skill: Skill, estimatedMinutes: Int, isAccessible: Bool, completedAt: Date?) {
        self.id = id
        self.title = title
        self.skill = skill
        self.estimatedMinutes = estimatedMinutes
        self.isAccessible = isAccessible
        self.completedAt = completedAt
    }
}

/// A practice card (grammar topic or practice set) that FSRS says is due.
/// `isDone` is true when this user already reviewed it today.
public struct DuePracticeCard: Sendable, Equatable {
    public let itemID: String
    public let lessonID: String
    public let title: String
    public let skill: Skill
    public let dueDate: Date
    public let isDone: Bool

    public init(itemID: String, lessonID: String, title: String, skill: Skill, dueDate: Date, isDone: Bool = false) {
        self.itemID = itemID
        self.lessonID = lessonID
        self.title = title
        self.skill = skill
        self.dueDate = dueDate
        self.isDone = isDone
    }
}

public struct DailyPlanInput: Sendable, Equatable {
    public let weights: SkillWeights
    public let dailyMinutes: Int
    public let lessonsInPathOrder: [PlanLesson]
    public let dueNowCount: Int
    public let reviewedTodayCount: Int
    public let pastWeekSkillMinutes: [Skill: Double]
    public let startOfToday: Date
    public let duePracticeCards: [DuePracticeCard]

    public init(
        weights: SkillWeights, dailyMinutes: Int, lessonsInPathOrder: [PlanLesson],
        dueNowCount: Int, reviewedTodayCount: Int,
        pastWeekSkillMinutes: [Skill: Double], startOfToday: Date,
        duePracticeCards: [DuePracticeCard] = []
    ) {
        self.weights = weights
        self.dailyMinutes = dailyMinutes
        self.lessonsInPathOrder = lessonsInPathOrder
        self.dueNowCount = dueNowCount
        self.reviewedTodayCount = reviewedTodayCount
        self.pastWeekSkillMinutes = pastWeekSkillMinutes
        self.startOfToday = startOfToday
        self.duePracticeCards = duePracticeCards
    }
}

public enum PlanTask: Sendable, Equatable {
    case review(cardCount: Int, minutes: Double, isDone: Bool)
    case lesson(id: String, title: String, skill: Skill, minutes: Double, isDone: Bool)
    /// A due grammar topic / practice set, re-served as a fresh selection of
    /// questions from its lesson's pool.
    case practiceReview(itemID: String, lessonID: String, title: String, skill: Skill, minutes: Double, isDone: Bool)
    case locked(id: String, title: String)
}

public struct SkillBalance: Sendable, Equatable {
    public let skill: Skill
    public let targetShare: Double
    public let actualShare: Double

    public init(skill: Skill, targetShare: Double, actualShare: Double) {
        self.skill = skill
        self.targetShare = targetShare
        self.actualShare = actualShare
    }
}

public struct DailyPlan: Sendable, Equatable {
    public let tasks: [PlanTask]
    public let totalMinutes: Double
    public let weeklyBalance: [SkillBalance]

    public init(tasks: [PlanTask], totalMinutes: Double, weeklyBalance: [SkillBalance]) {
        self.tasks = tasks
        self.totalMinutes = totalMinutes
        self.weeklyBalance = weeklyBalance
    }

    /// Every review/lesson task is done. Locked tasks are not actionable, so
    /// they never keep the plan open.
    public var isComplete: Bool {
        tasks.allSatisfy { task in
            switch task {
            case .review(_, _, let isDone),
                 .lesson(_, _, _, _, let isDone),
                 .practiceReview(_, _, _, _, _, let isDone):
                return isDone
            case .locked: return true
            }
        }
    }
}

/// Builds the day's plan from a pure snapshot. Contains no clock reads and no
/// SwiftData, so identical inputs always produce identical plans.
public struct DailyPlanBuilder: Sendable {
    public static let minutesPerReviewCard = 0.4
    public static let maxReviewShareOfBudget = 0.5
    public static let minutesPerPracticeReview = 3.0
    public static let maxPracticeReviewsPerDay = 2

    public init() {}

    public func build(_ input: DailyPlanInput) -> DailyPlan {
        var tasks: [PlanTask] = []
        let budget = Double(max(input.dailyMinutes, 0))
        let weights = input.weights
        let activeSkills = Set(weights.activeSkills)

        // 1. Review task.
        let reviewCap = Int((budget * Self.maxReviewShareOfBudget / Self.minutesPerReviewCard).rounded(.down))
        let reviewTarget = min(input.reviewedTodayCount + input.dueNowCount, reviewCap)
        var reviewMinutes = 0.0
        if reviewTarget > 0 {
            reviewMinutes = Double(reviewTarget) * Self.minutesPerReviewCard
            let isDone = input.reviewedTodayCount >= reviewTarget || input.dueNowCount == 0
            tasks.append(.review(cardCount: reviewTarget, minutes: reviewMinutes, isDone: isDone))
        }

        // 1b. Practice reviews: at most two a day, earliest due first, placed
        // right after the vocabulary review and inside the same budget.
        var practiceMinutes = 0.0
        let duePractice = input.duePracticeCards
            .sorted { ($0.dueDate, $0.itemID) < ($1.dueDate, $1.itemID) }
            .prefix(Self.maxPracticeReviewsPerDay)
        for practiceCard in duePractice where reviewMinutes + practiceMinutes < budget {
            tasks.append(.practiceReview(
                itemID: practiceCard.itemID, lessonID: practiceCard.lessonID,
                title: practiceCard.title, skill: practiceCard.skill,
                minutes: Self.minutesPerPracticeReview, isDone: practiceCard.isDone
            ))
            practiceMinutes += Self.minutesPerPracticeReview
        }

        // 2. Lesson selection by weekly deficit.
        var queues: [Skill: [PlanLesson]] = [:]
        for lesson in input.lessonsInPathOrder
        where lesson.isAccessible && activeSkills.contains(lesson.skill) && !completedBeforeToday(lesson, input) {
            queues[lesson.skill, default: []].append(lesson)
        }

        let pastTotal = input.pastWeekSkillMinutes.values.reduce(0, +)
        var plannedLessonMinutes = 0.0
        var plannedBySkill: [Skill: Double] = [:]
        var addedAny = false

        func nextLesson() -> PlanLesson? {
            let skills = Skill.allCases.filter { !(queues[$0]?.isEmpty ?? true) }
            let best = skills.max { lhs, rhs in
                let dl = deficit(lhs), dr = deficit(rhs)
                if dl != dr { return dl < dr }
                let wl = weights.weight(of: lhs), wr = weights.weight(of: rhs)
                if wl != wr { return wl < wr }
                // Earlier Skill.allCases position wins, so it must compare as "larger".
                return Skill.allCases.firstIndex(of: lhs)! > Skill.allCases.firstIndex(of: rhs)!
            }
            guard let skill = best else { return nil }
            return queues[skill]!.removeFirst()
        }

        func deficit(_ skill: Skill) -> Double {
            weights.share(of: skill) * (pastTotal + plannedLessonMinutes)
                - ((input.pastWeekSkillMinutes[skill] ?? 0) + (plannedBySkill[skill] ?? 0))
        }

        func add(_ lesson: PlanLesson) {
            let minutes = Double(lesson.estimatedMinutes)
            tasks.append(.lesson(id: lesson.id, title: lesson.title, skill: lesson.skill, minutes: minutes, isDone: lesson.completedAt != nil))
            plannedLessonMinutes += minutes
            plannedBySkill[lesson.skill, default: 0] += minutes
            addedAny = true
        }

        while reviewMinutes + practiceMinutes + plannedLessonMinutes < budget, let lesson = nextLesson() {
            add(lesson)
        }
        // 3. At least one lesson when any candidate exists.
        if !addedAny, let lesson = nextLesson() {
            add(lesson)
        }

        // 5. Locked card when the accessible part is exhausted.
        let activeLessons = input.lessonsInPathOrder.filter { activeSkills.contains($0.skill) }
        let hasOpenAccessible = activeLessons.contains { $0.isAccessible && $0.completedAt == nil }
        if !hasOpenAccessible, let locked = activeLessons.first(where: { !$0.isAccessible }) {
            tasks.append(.locked(id: locked.id, title: locked.title))
        }

        let balance = weights.activeSkills.map { skill in
            SkillBalance(
                skill: skill,
                targetShare: weights.share(of: skill),
                actualShare: pastTotal > 0 ? (input.pastWeekSkillMinutes[skill] ?? 0) / pastTotal : 0
            )
        }

        return DailyPlan(tasks: tasks, totalMinutes: reviewMinutes + practiceMinutes + plannedLessonMinutes, weeklyBalance: balance)
    }

    private func completedBeforeToday(_ lesson: PlanLesson, _ input: DailyPlanInput) -> Bool {
        guard let completedAt = lesson.completedAt else { return false }
        return completedAt < input.startOfToday
    }
}
