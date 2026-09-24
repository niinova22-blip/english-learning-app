import XCTest
@testable import TutorEngine

final class CoachNoteValidatorTests: XCTestCase {
    let request = CoachRequest(facts: ["Sınava kalan gün: 40", "Günlük gereken yeni ders süresi: 12 dakika"], draft: "Sınavına 40 gün var.")

    func test_acceptsTextUsingOnlyKnownNumbers_andTrimsIt() {
        XCTAssertEqual(
            CoachNoteValidator.validate("  Sınavına 40 gün kaldı, günde 12 dakika yeter!\n", for: request),
            "Sınavına 40 gün kaldı, günde 12 dakika yeter!"
        )
    }

    func test_acceptsTextWithoutNumbers() {
        XCTAssertEqual(CoachNoteValidator.validate("Harika gidiyorsun.", for: request), "Harika gidiyorsun.")
    }

    func test_rejectsEmptyOrWhitespace() {
        XCTAssertNil(CoachNoteValidator.validate("   \n", for: request))
    }

    func test_rejectsTextLongerThan400Characters() {
        XCTAssertNil(CoachNoteValidator.validate(String(repeating: "a", count: 401), for: request))
        XCTAssertNotNil(CoachNoteValidator.validate(String(repeating: "a", count: 400), for: request))
    }

    func test_rejectsANumberThatIsNotInTheBriefing() {
        XCTAssertNil(CoachNoteValidator.validate("Sınavına 45 gün var.", for: request))
        XCTAssertNil(CoachNoteValidator.validate("Başarı oranın %90.", for: request))
    }
}
