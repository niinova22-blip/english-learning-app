import Foundation

public enum CoachMode: Sendable, Equatable {
    /// A future exam date sets the deadline.
    case examDate
    /// No usable exam date: the pace is the day's normal new-lesson capacity.
    case freePace
}

public enum CoachStatus: Sendable, Equatable {
    case scopeComplete
    case examPassed
    case finalWeek
    case unreachable(shortfallMinutesPerDay: Int)
    case noData
    case behind(days: Int)
    case ahead(days: Int)
    case onTrack
}

/// What the coach asks of today's plan. `DailyPlanBuilder` treats a nil
/// directive exactly like before the coach existed.
public struct CoachDirective: Sendable, Equatable {
    public let extraLessonMinutes: Int
    public let reviewOnly: Bool

    public init(extraLessonMinutes: Int, reviewOnly: Bool) {
        self.extraLessonMinutes = extraLessonMinutes
        self.reviewOnly = reviewOnly
    }
}

public struct CoachInput: Sendable, Equatable {
    public let startOfToday: Date
    public let examDate: Date?
    public let dailyMinutes: Int
    public let profileCreatedAt: Date
    public let lessonsInPathOrder: [PlanLesson]
    public let weights: SkillWeights
    public let pastWeekSkillMinutes: [Skill: Double]

    public init(
        startOfToday: Date, examDate: Date?, dailyMinutes: Int, profileCreatedAt: Date,
        lessonsInPathOrder: [PlanLesson], weights: SkillWeights, pastWeekSkillMinutes: [Skill: Double]
    ) {
        self.startOfToday = startOfToday
        self.examDate = examDate
        self.dailyMinutes = dailyMinutes
        self.profileCreatedAt = profileCreatedAt
        self.lessonsInPathOrder = lessonsInPathOrder
        self.weights = weights
        self.pastWeekSkillMinutes = pastWeekSkillMinutes
    }
}

public struct CoachPlan: Sendable, Equatable {
    public let status: CoachStatus
    public let mode: CoachMode
    /// Whole days from today to the exam day; nil without an exam date.
    public let daysToExam: Int?
    /// Day by which the accessible new lessons should be finished; nil when
    /// nothing remains on free pace.
    public let targetFinishDay: Date?
    public let daysToTargetFinish: Int?
    public let remainingMinutes: Int
    public let completedShare: Double
    public let lockedLessonCount: Int
    public let requiredMinutesPerDay: Int
    public let weakestSkill: Skill?
    public let directive: CoachDirective

    public init(
        status: CoachStatus, mode: CoachMode, daysToExam: Int?, targetFinishDay: Date?,
        daysToTargetFinish: Int?, remainingMinutes: Int, completedShare: Double,
        lockedLessonCount: Int, requiredMinutesPerDay: Int, weakestSkill: Skill?,
        directive: CoachDirective
    ) {
        self.status = status
        self.mode = mode
        self.daysToExam = daysToExam
        self.targetFinishDay = targetFinishDay
        self.daysToTargetFinish = daysToTargetFinish
        self.remainingMinutes = remainingMinutes
        self.completedShare = completedShare
        self.lockedLessonCount = lockedLessonCount
        self.requiredMinutesPerDay = requiredMinutesPerDay
        self.weakestSkill = weakestSkill
        self.directive = directive
    }
}

/// Everything the coach note is written from: the plan plus the last 7 days
/// (the 7 whole days before today).
public struct CoachBriefing: Sendable, Equatable {
    public let plan: CoachPlan
    public let weekDaysStudied: Int
    public let weekMinutes: Int
    public let weekLessonsCompleted: Int
    public let streak: Int
    /// Exam goals (YDS, TOEFL) talk about an exam date; others a target date.
    public let isExamGoal: Bool

    public init(plan: CoachPlan, weekDaysStudied: Int, weekMinutes: Int, weekLessonsCompleted: Int, streak: Int, isExamGoal: Bool = true) {
        self.plan = plan
        self.weekDaysStudied = weekDaysStudied
        self.weekMinutes = weekMinutes
        self.weekLessonsCompleted = weekLessonsCompleted
        self.streak = streak
        self.isExamGoal = isExamGoal
    }
}
