import Foundation
import LearningEngine
import TutorEngine

/// Deterministic Turkish coach texts. Always available; a model note only
/// ever replaces `message(for:)` after validation.
enum CoachMessageTemplates {
    static func message(for briefing: CoachBriefing, coachAddedLessons: Bool = false) -> String {
        let plan = briefing.plan
        let days = plan.daysToExam ?? 0
        let pace = plan.requiredMinutesPerDay
        var text: String
        switch plan.status {
        case .scopeComplete:
            text = "Açık olan bütün dersleri bitirdin. Şimdi tekrarlarla bildiklerini sağlamlaştırma zamanı."
        case .examPassed:
            text = "Sınav tarihin geçmiş görünüyor. Yeni bir tarih eklersen programını ona göre kurarım; o zamana kadar kendi temponla devam ediyoruz."
        case .finalWeek:
            text = "Sınavına \(days) gün kaldı. Bu hafta yeni ders yok: tekrarlara ve zorlandığın konulara odaklan."
        case .unreachable(let shortfall):
            text = "Sınavına \(days) gün kaldı ve kalan dersler için günde \(pace) dakika gerekiyor; bu, günlük sürenden \(shortfall) dakika fazla. Günlük süreni artırabilir ya da sınav tarihini gözden geçirebilirsin."
        case .noData:
            text = plan.mode == .examDate
                ? "Sınavına \(days) gün var. Kalan \(plan.remainingMinutes) dakikalık ders için günde yaklaşık \(pace) dakika yeterli. İlk dersinle başlayalım."
                : "Kendi temponla, günde yaklaşık \(pace) dakika yeni dersle ilerleyeceğiz. İlk dersinle başlayalım."
        case .behind(let n):
            text = coachAddedLessons
                ? "Plana göre \(n) gün gerisindesin. Bugünkü plana birkaç ek ders koydum; birkaç gün böyle devam edersen yetişirsin."
                : "Plana göre \(n) gün gerisindesin. Bugünkü planını bitirirsen açığı kapatmaya başlarsın."
        case .ahead(let n):
            text = "Planın \(n) gün önündesin, harika gidiyorsun! Bu tempoyu korursan hedefine erken ulaşırsın."
        case .onTrack:
            text = plan.mode == .examDate
                ? "Sınavına \(days) gün var ve planındasın. Günde yaklaşık \(pace) dakika yeni dersle devam."
                : "Kendi temponda düzenli ilerliyorsun. Günde yaklaşık \(pace) dakika yeni dersle devam."
        }
        if plan.daysToExam == nil && plan.status != .scopeComplete {
            text += " Sınav tarihini eklersen programını ona göre kurarım."
        }
        return text
    }

    static func badge(for status: CoachStatus) -> String {
        switch status {
        case .scopeComplete: return "Kapsam tamam"
        case .examPassed: return "Tarih geçti"
        case .finalWeek: return "Son hafta: tekrar"
        case .unreachable: return "Tempo yetmiyor"
        case .noData: return "Başlangıç"
        case .behind(let n): return "\(n) gün geridesin"
        case .ahead(let n): return "\(n) gün öndesin"
        case .onTrack: return "Yoldasın"
        }
    }

    static func progressLine(for plan: CoachPlan) -> String {
        let percent = Int((plan.completedShare * 100).rounded())
        switch plan.status {
        case .scopeComplete:
            return "İlerleme %\(percent) · açık dersler bitti"
        case .finalWeek:
            return "Sınava \(plan.daysToExam ?? 0) gün · ilerleme %\(percent) · sadece tekrar"
        default:
            if plan.mode == .examDate, let days = plan.daysToExam {
                return "Sınava \(days) gün · ilerleme %\(percent) · günde ~\(plan.requiredMinutesPerDay) dk yeni ders"
            }
            return "İlerleme %\(percent) · günde ~\(plan.requiredMinutesPerDay) dk yeni ders"
        }
    }

    static func lockedLine(for plan: CoachPlan) -> String? {
        guard plan.lockedLessonCount > 0 else { return nil }
        return "Paketin \(plan.lockedLessonCount) dersi kilitli; açtığında programın güncellenir."
    }

    /// True when the card should invite the learner to add or change an exam date.
    static func needsExamDateInvite(_ plan: CoachPlan) -> Bool {
        guard plan.status != .scopeComplete else { return false }
        return plan.daysToExam == nil || plan.status == .examPassed
    }

    static func facts(for briefing: CoachBriefing) -> [String] {
        let plan = briefing.plan
        var facts = [
            "Durum: \(badge(for: plan.status))",
            "İlerleme: %\(Int((plan.completedShare * 100).rounded()))",
            "Kalan ders süresi: \(plan.remainingMinutes) dakika"
        ]
        if let days = plan.daysToExam, days > 0 { facts.append("Sınava kalan gün: \(days)") }
        if plan.requiredMinutesPerDay > 0 { facts.append("Günlük gereken yeni ders süresi: \(plan.requiredMinutesPerDay) dakika") }
        facts.append("Son 7 günde çalışılan gün: \(briefing.weekDaysStudied)")
        facts.append("Son 7 günde biten ders: \(briefing.weekLessonsCompleted)")
        facts.append("Seri: \(briefing.streak) gün")
        if let skill = plan.weakestSkill { facts.append("Bu hafta en çok ihtiyaç duyulan beceri: \(skill.displayName)") }
        return facts
    }

    static func request(for briefing: CoachBriefing, coachAddedLessons: Bool = false) -> CoachRequest {
        CoachRequest(facts: facts(for: briefing), draft: message(for: briefing, coachAddedLessons: coachAddedLessons))
    }
}
