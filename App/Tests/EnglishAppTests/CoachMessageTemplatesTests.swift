import XCTest
import LearningEngine
@testable import EnglishApp

final class CoachMessageTemplatesTests: XCTestCase {
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
            CoachMessageTemplates.message(for: briefing(plan(.onTrack))),
            "Sınavına 40 gün var ve planındasın. Günde yaklaşık 4 dakika yeni dersle devam."
        )
    }

    func test_onTrack_freePace_invitesAnExamDate() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.onTrack, mode: .freePace, daysToExam: nil, pace: 10))),
            "Kendi temponda düzenli ilerliyorsun. Günde yaklaşık 10 dakika yeni dersle devam. Sınav tarihini eklersen programını ona göre kurarım."
        )
    }

    func test_behind_ahead_finalWeek_unreachable() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.behind(days: 3)))),
            "Plana göre 3 gün gerideyiz. Bugünkü plana birkaç ek ders koydum; birkaç gün böyle devam edersek yetişiriz."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.ahead(days: 2)))),
            "Planın 2 gün önündesin, harika gidiyorsun! Bu tempoyu korursan hedefine erken ulaşırsın."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.finalWeek, daysToExam: 5, pace: 0))),
            "Sınavına 5 gün kaldı. Bu hafta yeni ders yok: tekrarlara ve zorlandığın konulara odaklan."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.unreachable(shortfallMinutesPerDay: 20), daysToExam: 12, pace: 40))),
            "Sınavına 12 gün kaldı ve kalan dersler için günde 40 dakika gerekiyor; bu, günlük sürenden 20 dakika fazla. Günlük süreni artırabilir ya da sınav tarihini gözden geçirebilirsin."
        )
    }

    func test_noData_scopeComplete_examPassed() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.noData))),
            "Sınavına 40 gün var. Kalan 120 dakikalık ders için günde yaklaşık 4 dakika yeterli. İlk dersinle başlayalım."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.scopeComplete, mode: .freePace, daysToExam: nil, remaining: 0, pace: 0))),
            "Açık olan bütün dersleri bitirdin. Şimdi tekrarlarla bildiklerini sağlamlaştırma zamanı."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.examPassed, mode: .freePace, daysToExam: 0, pace: 10))),
            "Sınav tarihin geçmiş görünüyor. Yeni bir tarih eklersen programını ona göre kurarım; o zamana kadar kendi temponla devam ediyoruz."
        )
    }

    func test_badges() {
        XCTAssertEqual(CoachMessageTemplates.badge(for: .onTrack), "Yoldasın")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .behind(days: 3)), "3 gün geridesin")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .ahead(days: 2)), "2 gün öndesin")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .finalWeek), "Son hafta: tekrar")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .scopeComplete), "Kapsam tamam")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .unreachable(shortfallMinutesPerDay: 5)), "Tempo yetmiyor")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .examPassed), "Tarih geçti")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .noData), "Başlangıç")
    }

    func test_progressAndLockedLines() {
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.onTrack)), "Sınava 40 gün · ilerleme %38 · günde ~4 dk yeni ders")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.onTrack, mode: .freePace, daysToExam: nil, pace: 10)), "İlerleme %38 · günde ~10 dk yeni ders")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.finalWeek, daysToExam: 5, pace: 0)), "Sınava 5 gün · ilerleme %38 · sadece tekrar")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.scopeComplete, share: 1)), "İlerleme %100 · açık dersler bitti")
        XCTAssertEqual(CoachMessageTemplates.lockedLine(for: plan(.onTrack, locked: 99)), "Paketin 99 dersi kilitli; açtığında programın güncellenir.")
        XCTAssertNil(CoachMessageTemplates.lockedLine(for: plan(.onTrack)))
    }

    func test_facts_andRequest() {
        let b = briefing(plan(.onTrack, weakest: .grammar))
        XCTAssertEqual(CoachMessageTemplates.facts(for: b), [
            "Durum: Yoldasın",
            "İlerleme: %38",
            "Kalan ders süresi: 120 dakika",
            "Sınava kalan gün: 40",
            "Günlük gereken yeni ders süresi: 4 dakika",
            "Son 7 günde çalışılan gün: 4",
            "Son 7 günde biten ders: 3",
            "Seri: 2 gün",
            "Bu hafta en çok ihtiyaç duyulan beceri: Gramer"
        ])
        let request = CoachMessageTemplates.request(for: b)
        XCTAssertEqual(request.draft, CoachMessageTemplates.message(for: b))
        XCTAssertEqual(request.facts, CoachMessageTemplates.facts(for: b))
    }

    func test_examDateInvite() {
        XCTAssertTrue(CoachMessageTemplates.needsExamDateInvite(plan(.onTrack, mode: .freePace, daysToExam: nil)))
        XCTAssertTrue(CoachMessageTemplates.needsExamDateInvite(plan(.examPassed, mode: .freePace, daysToExam: -2)))
        XCTAssertFalse(CoachMessageTemplates.needsExamDateInvite(plan(.onTrack)))
    }
}
