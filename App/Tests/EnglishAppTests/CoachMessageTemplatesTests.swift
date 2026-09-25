import XCTest
import LearningEngine
@testable import EnglishApp

/// Existing expectations are the exact Turkish texts the app showed before
/// the English interface; they render through the Turkish table so any drift
/// in the Turkish catalog fails here. English variants are tested below.
final class CoachMessageTemplatesTests: XCTestCase {
    let tr = AppLanguage.turkish

    func plan(
        _ status: CoachStatus, mode: CoachMode = .examDate, daysToExam: Int? = 40,
        remaining: Int = 120, share: Double = 0.38, locked: Int = 0, pace: Int = 4,
        weakest: Skill? = nil
    ) -> CoachPlan {
        CoachPlan(
            status: status, mode: mode, daysToExam: daysToExam, targetFinishDay: nil,
            daysToTargetFinish: 33, remainingMinutes: remaining, completedShare: share,
            lockedLessonCount: locked, requiredMinutesPerDay: pace, weakestSkill: weakest,
            directive: CoachDirective(extraLessonMinutes: 0, reviewOnly: false)
        )
    }

    func briefing(_ plan: CoachPlan) -> CoachBriefing {
        CoachBriefing(plan: plan, weekDaysStudied: 4, weekMinutes: 55, weekLessonsCompleted: 3, streak: 2)
    }

    func test_onTrack_examMode() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.onTrack)), language: tr),
            "Sınavına 40 gün var ve planındasın. Günde yaklaşık 4 dakika yeni dersle devam."
        )
    }

    func test_onTrack_freePace_invitesAnExamDate() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.onTrack, mode: .freePace, daysToExam: nil, pace: 10)), language: tr),
            "Kendi temponda düzenli ilerliyorsun. Günde yaklaşık 10 dakika yeni dersle devam. Sınav tarihini eklersen programını ona göre kurarım."
        )
    }

    func test_behind_ahead_finalWeek_unreachable() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.behind(days: 3))), language: tr),
            "Plana göre 3 gün gerisindesin. Bugünkü planını bitirirsen açığı kapatmaya başlarsın."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.ahead(days: 2))), language: tr),
            "Planın 2 gün önündesin, harika gidiyorsun! Bu tempoyu korursan hedefine erken ulaşırsın."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.finalWeek, daysToExam: 5, pace: 0)), language: tr),
            "Sınavına 5 gün kaldı. Bu hafta yeni ders yok: tekrarlara ve zorlandığın konulara odaklan."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.unreachable(shortfallMinutesPerDay: 20), daysToExam: 12, pace: 40)), language: tr),
            "Sınavına 12 gün kaldı ve kalan dersler için günde 40 dakika gerekiyor; bu, günlük sürenden 20 dakika fazla. Günlük süreni artırabilir ya da sınav tarihini gözden geçirebilirsin."
        )
    }

    func test_behind_coachAddedLessons_variesTheText() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.behind(days: 3))), coachAddedLessons: false, language: tr),
            "Plana göre 3 gün gerisindesin. Bugünkü planını bitirirsen açığı kapatmaya başlarsın."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.behind(days: 3))), coachAddedLessons: true, language: tr),
            "Plana göre 3 gün gerisindesin. Bugünkü plana birkaç ek ders koydum; birkaç gün böyle devam edersen yetişirsin."
        )
        XCTAssertEqual(
            CoachMessageTemplates.request(for: briefing(plan(.behind(days: 3))), coachAddedLessons: true, language: tr).draft,
            "Plana göre 3 gün gerisindesin. Bugünkü plana birkaç ek ders koydum; birkaç gün böyle devam edersen yetişirsin."
        )
    }

    func test_noData_scopeComplete_examPassed() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.noData)), language: tr),
            "Sınavına 40 gün var. Kalan 120 dakikalık ders için günde yaklaşık 4 dakika yeterli. İlk dersinle başlayalım."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.scopeComplete, mode: .freePace, daysToExam: nil, remaining: 0, pace: 0)), language: tr),
            "Açık olan bütün dersleri bitirdin. Şimdi tekrarlarla bildiklerini sağlamlaştırma zamanı."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.examPassed, mode: .freePace, daysToExam: 0, pace: 10)), language: tr),
            "Sınav tarihin geçmiş görünüyor. Yeni bir tarih eklersen programını ona göre kurarım; o zamana kadar kendi temponla devam ediyoruz."
        )
    }

    func test_badges() {
        XCTAssertEqual(CoachMessageTemplates.badge(for: .onTrack, language: tr), "Yoldasın")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .behind(days: 3), language: tr), "3 gün geridesin")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .ahead(days: 2), language: tr), "2 gün öndesin")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .finalWeek, language: tr), "Son hafta: tekrar")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .scopeComplete, language: tr), "Kapsam tamam")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .unreachable(shortfallMinutesPerDay: 5), language: tr), "Tempo yetmiyor")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .examPassed, language: tr), "Tarih geçti")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .noData, language: tr), "Başlangıç")
    }

    func test_progressAndLockedLines() {
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.onTrack), language: tr), "Sınava 40 gün · ilerleme %38 · günde ~4 dk yeni ders")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.onTrack, mode: .freePace, daysToExam: nil, pace: 10), language: tr), "İlerleme %38 · günde ~10 dk yeni ders")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.finalWeek, daysToExam: 5, pace: 0), language: tr), "Sınava 5 gün · ilerleme %38 · sadece tekrar")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.scopeComplete, share: 1), language: tr), "İlerleme %100 · açık dersler bitti")
        XCTAssertEqual(CoachMessageTemplates.lockedLine(for: plan(.onTrack, locked: 99), language: tr), "Paketin 99 dersi kilitli; açtığında programın güncellenir.")
        XCTAssertNil(CoachMessageTemplates.lockedLine(for: plan(.onTrack)))
    }

    func test_facts_andRequest() {
        let b = briefing(plan(.onTrack))
        XCTAssertEqual(CoachMessageTemplates.facts(for: b, language: tr), [
            "Durum: Yoldasın",
            "İlerleme: %38",
            "Kalan ders süresi: 120 dakika",
            "Sınava kalan gün: 40",
            "Günlük gereken yeni ders süresi: 4 dakika",
            "Son 7 günde çalışılan gün: 4",
            "Son 7 günde biten ders: 3",
            "Seri: 2 gün"
        ])
        let request = CoachMessageTemplates.request(for: b, language: tr)
        XCTAssertEqual(request.draft, CoachMessageTemplates.message(for: b, language: tr))
        XCTAssertEqual(request.facts, CoachMessageTemplates.facts(for: b, language: tr))
        XCTAssertEqual(request.learnerLanguage, .turkish)
        let withSkill = CoachMessageTemplates.facts(for: briefing(plan(.onTrack, weakest: .grammar)), language: tr)
        XCTAssertEqual(withSkill.count, 9)
        XCTAssertTrue(withSkill.last!.hasPrefix("Bu hafta en çok ihtiyaç duyulan beceri: "))
    }

    // MARK: English

    let en = AppLanguage.english

    func test_english_messagesUsePluralsAndEnglishOrder() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.onTrack)), language: en),
            "Your exam is 40 days away and you're on track. Keep going with about 4 minutes of new lessons a day."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.finalWeek, daysToExam: 1, pace: 0)), language: en),
            "1 day left until your exam. No new lessons this week: focus on reviews and the topics you found hard."
        )
        XCTAssertEqual(CoachMessageTemplates.badge(for: .behind(days: 1), language: en), "1 day behind")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .ahead(days: 3), language: en), "3 days ahead")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.onTrack), language: en), "Exam in 40 days · progress 38% · ~4 min of new lessons a day")
        XCTAssertEqual(CoachMessageTemplates.lockedLine(for: plan(.onTrack, locked: 1), language: en), "1 lesson in this package is locked; your plan updates when you unlock it.")
        XCTAssertEqual(CoachMessageTemplates.request(for: briefing(plan(.onTrack)), language: en).learnerLanguage, .english)
    }

    // MARK: Target-date goals (Business, Everyday)

    func targetBriefing(_ plan: CoachPlan) -> CoachBriefing {
        CoachBriefing(plan: plan, weekDaysStudied: 4, weekMinutes: 55, weekLessonsCompleted: 3, streak: 2, isExamGoal: false)
    }

    func test_targetGoals_neverMentionAnExam() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: targetBriefing(plan(.onTrack)), language: tr),
            "Hedef tarihine 40 gün var ve planındasın. Günde yaklaşık 4 dakika yeni dersle devam."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: targetBriefing(plan(.onTrack, mode: .freePace, daysToExam: nil, pace: 10)), language: en),
            "You're making steady progress at your own pace. Keep going with about 10 minutes of new lessons a day. Add a target date and I'll build your plan around it."
        )
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.onTrack), isExam: false, language: en), "Target in 40 days · progress 38% · ~4 min of new lessons a day")
        for language in [tr, en] {
            for status: CoachStatus in [.onTrack, .noData, .finalWeek, .examPassed, .unreachable(shortfallMinutesPerDay: 5), .behind(days: 2)] {
                let text = CoachMessageTemplates.message(for: targetBriefing(plan(status)), language: language)
                    + CoachMessageTemplates.facts(for: targetBriefing(plan(status)), language: language).joined()
                XCTAssertFalse(text.lowercased().contains("exam"), text)
                XCTAssertFalse(text.lowercased().contains("sınav"), text)
            }
        }
    }

    func test_examDateInvite() {
        XCTAssertTrue(CoachMessageTemplates.needsExamDateInvite(plan(.onTrack, mode: .freePace, daysToExam: nil)))
        XCTAssertTrue(CoachMessageTemplates.needsExamDateInvite(plan(.examPassed, mode: .freePace, daysToExam: -2)))
        XCTAssertFalse(CoachMessageTemplates.needsExamDateInvite(plan(.onTrack)))
        XCTAssertFalse(CoachMessageTemplates.needsExamDateInvite(plan(.scopeComplete, mode: .freePace, daysToExam: nil)))
    }
}
