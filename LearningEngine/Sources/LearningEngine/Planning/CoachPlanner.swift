import Foundation

/// Turns the exam date, the path and recent study into a programme. Pure: no
/// clock reads and no SwiftData, so identical inputs give identical plans.
public struct CoachPlanner: Sendable {
    public static let finalWeekDays = 7
    public static let trackingWindowDays = 14
    public static let catchUpSpreadDays = 7

    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// New-lesson minutes of a normal day: what `DailyPlanBuilder` leaves after
    /// its maximum review share.
    public static func newLessonCapacity(dailyMinutes: Int) -> Int {
        let share = 1 - DailyPlanBuilder.maxReviewShareOfBudget
        return max(1, Int((Double(max(dailyMinutes, 0)) * share).rounded(.down)))
    }

    public func plan(_ input: CoachInput) -> CoachPlan {
        let today = calendar.startOfDay(for: input.startOfToday)
        let daily = max(input.dailyMinutes, 0)
        let capacity = Self.newLessonCapacity(dailyMinutes: daily)

        let accessible = input.lessonsInPathOrder.filter(\.isAccessible)
        let remaining = accessible.filter { $0.completedAt == nil }.reduce(0) { $0 + $1.estimatedMinutes }
        let accessibleTotal = accessible.reduce(0) { $0 + $1.estimatedMinutes }
        let completedShare = accessibleTotal > 0 ? Double(accessibleTotal - remaining) / Double(accessibleTotal) : 0
        let lockedCount = input.lessonsInPathOrder.filter { !$0.isAccessible }.count
        let daysToExam = input.examDate.map { days(from: today, to: calendar.startOfDay(for: $0)) }

        // Mode, pace and target finish day.
        let mode: CoachMode = (daysToExam ?? 0) > 0 ? .examDate : .freePace
        var pace = 0
        var daysToFinish: Int?
        if mode == .examDate, let d = daysToExam {
            let studyDays = d - Self.finalWeekDays
            if studyDays > 0 {
                pace = remaining == 0 ? 0 : ceilDiv(remaining, studyDays)
                daysToFinish = studyDays
            } else {
                daysToFinish = 0
            }
        } else if remaining > 0 {
            pace = capacity
            daysToFinish = ceilDiv(remaining, capacity)
        }
        let targetFinish = daysToFinish.flatMap { calendar.date(byAdding: .day, value: $0, to: today) }

        // Tracking window: last 14 days before today, never before the profile existed.
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -Self.trackingWindowDays, to: today)!
        let windowStart = max(calendar.startOfDay(for: input.profileCreatedAt), fourteenDaysAgo)
        let windowDays = max(0, days(from: windowStart, to: today))
        let doneInWindow = input.lessonsInPathOrder.reduce(0) { sum, lesson in
            guard let completedAt = lesson.completedAt, completedAt >= windowStart, completedAt < today else { return sum }
            return sum + lesson.estimatedMinutes
        }
        let balance = doneInWindow - pace * windowDays
        let hasAnyCompletion = input.lessonsInPathOrder.contains { $0.completedAt != nil }

        let status: CoachStatus
        if remaining == 0 {
            status = .scopeComplete
        } else if let d = daysToExam, d <= 0 {
            status = .examPassed
        } else if let d = daysToExam, d <= Self.finalWeekDays {
            status = .finalWeek
        } else if mode == .examDate && pace > daily {
            status = .unreachable(shortfallMinutesPerDay: pace - daily)
        } else if !hasAnyCompletion {
            status = .noData
        } else if pace > 0 && windowDays > 0 && balance <= -pace {
            status = .behind(days: ceilDiv(-balance, pace))
        } else if pace > 0 && windowDays > 0 && balance >= pace {
            status = .ahead(days: balance / pace)
        } else {
            status = .onTrack
        }

        let reviewOnly = status == .scopeComplete || status == .finalWeek
        var extra = 0
        if !reviewOnly {
            let paceExcess = mode == .examDate ? max(0, pace - capacity) : 0
            var catchUp = 0
            if case .behind = status { catchUp = ceilDiv(-balance, Self.catchUpSpreadDays) }
            extra = min(max(0, daily - capacity), paceExcess + catchUp)
        }

        return CoachPlan(
            status: status, mode: mode, daysToExam: daysToExam,
            targetFinishDay: targetFinish, daysToTargetFinish: daysToFinish,
            remainingMinutes: remaining, completedShare: completedShare,
            lockedLessonCount: lockedCount, requiredMinutesPerDay: pace,
            weakestSkill: weakestSkill(input),
            directive: CoachDirective(extraLessonMinutes: extra, reviewOnly: reviewOnly)
        )
    }

    private func days(from start: Date, to end: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private func ceilDiv(_ a: Int, _ b: Int) -> Int {
        precondition(b > 0)
        return (a + b - 1) / b
    }

    /// The active skill furthest behind its share of last week's minutes;
    /// earlier `Skill.allCases` position wins ties. Nil without last-week study
    /// or when no skill is behind.
    private func weakestSkill(_ input: CoachInput) -> Skill? {
        let total = input.pastWeekSkillMinutes.values.reduce(0, +)
        guard total > 0 else { return nil }
        var best: (skill: Skill, gap: Double)?
        for skill in input.weights.activeSkills {
            let gap = input.weights.share(of: skill) * total - (input.pastWeekSkillMinutes[skill] ?? 0)
            if best == nil || gap > best!.gap { best = (skill, gap) }
        }
        guard let best, best.gap > 0 else { return nil }
        return best.skill
    }
}
