import XCTest
@testable import EnglishApp
import LearningEngine

final class DesignSystemTests: XCTestCase {
    func test_rgb_parsesHex() {
        let c = Theme.rgb(0x0F766E)
        XCTAssertEqual(c.r, 15.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.g, 118.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.b, 110.0 / 255, accuracy: 1e-9)
    }

    func test_skillDisplayNames_areEnglish() {
        XCTAssertEqual(Skill.allCases.map(\.displayName),
                       ["Vocabulary", "Grammar", "Reading", "Listening", "Writing", "Speaking", "Pronunciation"])
    }

    func test_ratingLabels() {
        XCTAssertEqual([FSRSRating.again, .hard, .good, .easy].map(\.label),
                       ["Forgot", "Hard", "Knew it", "Easy"])
    }

    func test_planTaskText() {
        XCTAssertEqual(PlanTaskText.title(.review(cardCount: 14, minutes: 5.6, isDone: false)), "Word review")
        XCTAssertEqual(PlanTaskText.subtitle(.review(cardCount: 14, minutes: 5.6, isDone: false)), "14 cards · 6 min")
        XCTAssertEqual(PlanTaskText.subtitle(.review(cardCount: 14, minutes: 5.6, isDone: true)), "14 cards · done")
        XCTAssertEqual(PlanTaskText.title(.lesson(id: "l", title: "Science · 2", skill: .vocabulary, minutes: 8, isDone: false)), "Science · 2")
        XCTAssertEqual(PlanTaskText.subtitle(.lesson(id: "l", title: "Science · 2", skill: .vocabulary, minutes: 8, isDone: false)), "New lesson · Vocabulary · 8 min")
        XCTAssertEqual(PlanTaskText.subtitle(.lesson(id: "l", title: "x", skill: .grammar, minutes: 10, isDone: true)), "Grammar · done")
        XCTAssertEqual(PlanTaskText.title(.locked(id: "l", title: "Law · 1")), "Law · 1")
        XCTAssertEqual(PlanTaskText.subtitle(.locked(id: "l", title: "Law · 1")), "Unlock package")
    }

    func test_minutes_roundUp() {
        XCTAssertEqual(PlanTaskText.minutes(0.4), 1)
        XCTAssertEqual(PlanTaskText.minutes(8), 8)
        XCTAssertEqual(PlanTaskText.minutes(21.2), 22)
    }

    // MARK: Native look

    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            let c = Theme.rgb(hex)
            let lin = [c.r, c.g, c.b].map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    func test_brandColors_meetAATextContrastOnCards() {
        // Cards are white in light mode and #1C1C1E in dark mode.
        XCTAssertGreaterThanOrEqual(contrast(Theme.Palette.primaryLight, 0xFFFFFF), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(Theme.Palette.accentLight, 0xFFFFFF), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(Theme.Palette.primaryDark, 0x1C1C1E), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(Theme.Palette.accentDark, 0x1C1C1E), 4.5)
    }

    func test_textOnBrandFills_meetsAAContrast_inBothModes() {
        XCTAssertGreaterThanOrEqual(contrast(0xFFFFFF, Theme.Palette.primaryLight), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(Theme.Palette.onPrimaryDark, Theme.Palette.primaryDark), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(0xFFFFFF, Theme.Palette.accentLight), 4.5)
        XCTAssertGreaterThanOrEqual(contrast(Theme.Palette.onAccentDark, Theme.Palette.accentDark), 4.5)
    }

    func test_reduceMotion_disablesPressScaleAndSprings() {
        XCTAssertEqual(Motion.pressScale(isPressed: true, reduceMotion: false), 0.97)
        XCTAssertEqual(Motion.pressScale(isPressed: true, reduceMotion: true), 1)
        XCTAssertEqual(Motion.pressScale(isPressed: false, reduceMotion: false), 1)
        XCTAssertNil(Motion.spring(reduceMotion: true))
        XCTAssertNotNil(Motion.spring(reduceMotion: false))
    }
}
