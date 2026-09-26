import XCTest
@testable import EnglishApp

final class BilingualTextTests: XCTestCase {
    func test_pick_turkishUI_prefersTurkish_untilEnglishIsRequested() {
        XCTAssertEqual(BilingualPick.text(en: "E", tr: "T", base: "B", language: .turkish, showEnglish: false), "T")
        XCTAssertEqual(BilingualPick.text(en: "E", tr: "T", base: "B", language: .turkish, showEnglish: true), "E")
        XCTAssertEqual(BilingualPick.text(en: "E", tr: nil, base: "B", language: .turkish, showEnglish: false), "B")
        XCTAssertEqual(BilingualPick.text(en: nil, tr: "T", base: "B", language: .turkish, showEnglish: true), "B")
        XCTAssertEqual(BilingualPick.text(en: "E", tr: " ", base: "B", language: .turkish, showEnglish: false), "B")
    }

    func test_pick_englishUI_neverShowsTurkish() {
        XCTAssertEqual(BilingualPick.text(en: "E", tr: "T", base: "B", language: .english, showEnglish: false), "E")
        XCTAssertEqual(BilingualPick.text(en: nil, tr: "T", base: "B", language: .english, showEnglish: false), "B")
    }

    func test_toggle_onlyOnTurkishUI_withTwoDifferentSides() {
        XCTAssertTrue(BilingualPick.offersToggle(en: "E", tr: "T", language: .turkish))
        XCTAssertFalse(BilingualPick.offersToggle(en: "E", tr: "T", language: .english))
        XCTAssertFalse(BilingualPick.offersToggle(en: "E", tr: nil, language: .turkish))
        XCTAssertFalse(BilingualPick.offersToggle(en: "", tr: "T", language: .turkish))
        XCTAssertFalse(BilingualPick.offersToggle(en: "Same", tr: "Same", language: .turkish))
    }
}
