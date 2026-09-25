import Foundation
import LearningEngine
import TutorEngine

/// Deterministic coach texts in the UI language. Always available; a model
/// note only ever replaces `message(for:)` after validation.
///
/// Every function takes a `language` so tests can render either language;
/// the app uses the default (`AppLanguage.current`). `isExam` switches
/// between exam wording (YDS, TOEFL) and target-date wording (other goals).
enum CoachMessageTemplates {
    static func message(for briefing: CoachBriefing, coachAddedLessons: Bool = false, language: AppLanguage = .current) -> String {
        let b = language.bundle
        let plan = briefing.plan
        let exam = briefing.isExamGoal
        let days = CountText.days(plan.daysToExam ?? 0, bundle: b)
        let pace = CountText.minutes(plan.requiredMinutesPerDay, bundle: b)
        var text: String
        switch plan.status {
        case .scopeComplete:
            text = String(localized: "You've finished every unlocked lesson. Now it's time to strengthen what you know with reviews.", bundle: b)
        case .examPassed:
            text = exam
                ? String(localized: "Your exam date seems to have passed. Add a new date and I'll build your plan around it; until then, we'll keep going at your own pace.", bundle: b)
                : String(localized: "Your target date seems to have passed. Add a new date and I'll build your plan around it; until then, we'll keep going at your own pace.", bundle: b)
        case .finalWeek:
            text = exam
                ? String(localized: "\(days) left until your exam. No new lessons this week: focus on reviews and the topics you found hard.", bundle: b)
                : String(localized: "\(days) left until your target date. No new lessons this week: focus on reviews and the topics you found hard.", bundle: b)
        case .unreachable(let shortfall):
            let extra = CountText.minutes(shortfall, bundle: b)
            text = exam
                ? String(localized: "\(days) left until your exam, and the remaining lessons need \(pace) a day, which is \(extra) more than your daily time. You can increase your daily time or rethink your exam date.", bundle: b)
                : String(localized: "\(days) left until your target date, and the remaining lessons need \(pace) a day, which is \(extra) more than your daily time. You can increase your daily time or rethink your target date.", bundle: b)
        case .noData:
            if plan.mode == .examDate {
                text = exam
                    ? String(localized: "Your exam is \(days) away. About \(pace) a day covers the remaining \(plan.remainingMinutes) minutes of lessons. Let's start with your first lesson.", bundle: b)
                    : String(localized: "Your target date is \(days) away. About \(pace) a day covers the remaining \(plan.remainingMinutes) minutes of lessons. Let's start with your first lesson.", bundle: b)
            } else {
                text = String(localized: "We'll move at your own pace, with about \(pace) of new lessons a day. Let's start with your first lesson.", bundle: b)
            }
        case .behind(let n):
            let gap = CountText.days(n, bundle: b)
            text = coachAddedLessons
                ? String(localized: "You're \(gap) behind plan. I've added a few extra lessons to today's plan; keep this up for a few days and you'll catch up.", bundle: b)
                : String(localized: "You're \(gap) behind plan. Finish today's plan and you'll start closing the gap.", bundle: b)
        case .ahead(let n):
            let lead = CountText.days(n, bundle: b)
            text = String(localized: "You're \(lead) ahead of plan. Great work! Keep this pace and you'll reach your goal early.", bundle: b)
        case .onTrack:
            if plan.mode == .examDate {
                text = exam
                    ? String(localized: "Your exam is \(days) away and you're on track. Keep going with about \(pace) of new lessons a day.", bundle: b)
                    : String(localized: "Your target date is \(days) away and you're on track. Keep going with about \(pace) of new lessons a day.", bundle: b)
            } else {
                text = String(localized: "You're making steady progress at your own pace. Keep going with about \(pace) of new lessons a day.", bundle: b)
            }
        }
        if plan.daysToExam == nil && plan.status != .scopeComplete {
            text += " " + (exam
                ? String(localized: "Add your exam date and I'll build your plan around it.", bundle: b)
                : String(localized: "Add a target date and I'll build your plan around it.", bundle: b))
        }
        return text
    }

    static func badge(for status: CoachStatus, language: AppLanguage = .current) -> String {
        let b = language.bundle
        switch status {
        case .scopeComplete: return String(localized: "All done", bundle: b)
        case .examPassed: return String(localized: "Date passed", bundle: b)
        case .finalWeek: return String(localized: "Final week: review", bundle: b)
        case .unreachable: return String(localized: "Pace too low", bundle: b)
        case .noData: return String(localized: "Getting started", bundle: b)
        case .behind(let n):
            let gap = CountText.days(n, bundle: b)
            return String(localized: "\(gap) behind", bundle: b)
        case .ahead(let n):
            let lead = CountText.days(n, bundle: b)
            return String(localized: "\(lead) ahead", bundle: b)
        case .onTrack: return String(localized: "On track", bundle: b)
        }
    }

    static func progressLine(for plan: CoachPlan, isExam: Bool = true, language: AppLanguage = .current) -> String {
        let b = language.bundle
        let percent = PercentText.format(share: plan.completedShare, bundle: b)
        let pace = plan.requiredMinutesPerDay
        switch plan.status {
        case .scopeComplete:
            return String(localized: "Progress \(percent) · unlocked lessons done", bundle: b)
        case .finalWeek:
            let days = CountText.days(plan.daysToExam ?? 0, bundle: b)
            return isExam
                ? String(localized: "Exam in \(days) · progress \(percent) · reviews only", bundle: b)
                : String(localized: "Target in \(days) · progress \(percent) · reviews only", bundle: b)
        default:
            if plan.mode == .examDate, let daysToExam = plan.daysToExam {
                let days = CountText.days(daysToExam, bundle: b)
                return isExam
                    ? String(localized: "Exam in \(days) · progress \(percent) · ~\(pace) min of new lessons a day", bundle: b)
                    : String(localized: "Target in \(days) · progress \(percent) · ~\(pace) min of new lessons a day", bundle: b)
            }
            return String(localized: "Progress \(percent) · ~\(pace) min of new lessons a day", bundle: b)
        }
    }

    static func lockedLine(for plan: CoachPlan, language: AppLanguage = .current) -> String? {
        guard plan.lockedLessonCount > 0 else { return nil }
        return String(localized: "\(plan.lockedLessonCount) lessons in this package are locked; your plan updates when you unlock them.", bundle: language.bundle)
    }

    /// True when the card should invite the learner to add or change a date.
    static func needsExamDateInvite(_ plan: CoachPlan) -> Bool {
        guard plan.status != .scopeComplete else { return false }
        return plan.daysToExam == nil || plan.status == .examPassed
    }

    static func facts(for briefing: CoachBriefing, language: AppLanguage = .current) -> [String] {
        let b = language.bundle
        let plan = briefing.plan
        let status = badge(for: plan.status, language: language)
        let progress = PercentText.format(share: plan.completedShare, bundle: b)
        let remaining = CountText.minutes(plan.remainingMinutes, bundle: b)
        var facts = [
            String(localized: "Status: \(status)", bundle: b),
            String(localized: "Progress: \(progress)", bundle: b),
            String(localized: "Remaining lesson time: \(remaining)", bundle: b)
        ]
        if let days = plan.daysToExam, days > 0 {
            facts.append(briefing.isExamGoal
                ? String(localized: "Days until the exam: \(days)", bundle: b)
                : String(localized: "Days until the target date: \(days)", bundle: b))
        }
        if plan.requiredMinutesPerDay > 0 {
            let pace = CountText.minutes(plan.requiredMinutesPerDay, bundle: b)
            facts.append(String(localized: "New lesson time needed per day: \(pace)", bundle: b))
        }
        facts.append(String(localized: "Days studied in the last 7 days: \(briefing.weekDaysStudied)", bundle: b))
        facts.append(String(localized: "Lessons finished in the last 7 days: \(briefing.weekLessonsCompleted)", bundle: b))
        let streak = CountText.days(briefing.streak, bundle: b)
        facts.append(String(localized: "Streak: \(streak)", bundle: b))
        if let skill = plan.weakestSkill {
            let name = skill.displayName
            facts.append(String(localized: "Skill most needed this week: \(name)", bundle: b))
        }
        return facts
    }

    static func request(for briefing: CoachBriefing, coachAddedLessons: Bool = false, language: AppLanguage = .current) -> CoachRequest {
        CoachRequest(
            facts: facts(for: briefing, language: language),
            draft: message(for: briefing, coachAddedLessons: coachAddedLessons, language: language),
            learnerLanguage: language.learnerLanguage
        )
    }
}
