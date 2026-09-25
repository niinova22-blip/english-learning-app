// App/Tests/EnglishAppTests/PracticeOptionTextTests.swift
import XCTest
@testable import EnglishApp

final class PracticeOptionTextTests: XCTestCase {
    func test_letters_areAThroughE() {
        XCTAssertEqual((0..<5).map(PracticeOptionText.letter), ["A", "B", "C", "D", "E"])
    }

    func test_outOfRangeIndex_fallsBackToTheNumber() {
        XCTAssertEqual(PracticeOptionText.letter(5), "6")
        XCTAssertEqual(PracticeOptionText.letter(-1), "0")
    }

    func test_unansweredOption_readsAsPlainOption() {
        XCTAssertEqual(
            PracticeOptionText.accessibilityLabel(index: 0, text: "had already restructured", state: .idle),
            "Option A: had already restructured"
        )
    }

    func test_correctAndWrongOptions_announceTheirStateInWords_notJustColour() {
        XCTAssertEqual(
            PracticeOptionText.accessibilityLabel(index: 1, text: "because", state: .correct),
            "Option B: because, correct answer"
        )
        XCTAssertEqual(
            PracticeOptionText.accessibilityLabel(index: 2, text: "unless", state: .wrongPick),
            "Option C: unless, your answer, incorrect"
        )
        XCTAssertEqual(
            PracticeOptionText.accessibilityLabel(index: 3, text: "therefore", state: .dimmed),
            "Option D: therefore"
        )
    }

    func test_stateForOption_derivesFromTheSelectionAndTheKey() {
        // Nothing answered yet.
        XCTAssertEqual(PracticeOptionText.state(index: 2, selectedIndex: nil, correctIndex: 1), .idle)
        // Answered wrongly: the key turns correct, the pick turns wrongPick,
        // everything else dims.
        XCTAssertEqual(PracticeOptionText.state(index: 1, selectedIndex: 2, correctIndex: 1), .correct)
        XCTAssertEqual(PracticeOptionText.state(index: 2, selectedIndex: 2, correctIndex: 1), .wrongPick)
        XCTAssertEqual(PracticeOptionText.state(index: 3, selectedIndex: 2, correctIndex: 1), .dimmed)
        // Answered correctly: only the key is highlighted.
        XCTAssertEqual(PracticeOptionText.state(index: 1, selectedIndex: 1, correctIndex: 1), .correct)
        XCTAssertEqual(PracticeOptionText.state(index: 0, selectedIndex: 1, correctIndex: 1), .dimmed)
    }
}
