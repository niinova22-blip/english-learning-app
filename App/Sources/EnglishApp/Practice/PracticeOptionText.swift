// App/Sources/EnglishApp/Practice/PracticeOptionText.swift
import Foundation

/// How one answer option renders after an answer is committed. Every state
/// carries an icon and words as well as a colour — never colour alone
/// (spec "Screens and flow", rule 4).
enum PracticeOptionState: Equatable {
    /// Nothing answered yet.
    case idle
    /// The keyed option, once the answer is in.
    case correct
    /// The learner's pick, when it was wrong.
    case wrongPick
    /// Any other option, once the answer is in.
    case dimmed
}

enum PracticeOptionText {
    private static let letters = ["A", "B", "C", "D", "E"]

    static func letter(_ index: Int) -> String {
        guard index >= 0, index < letters.count else { return "\(index + 1)" }
        return letters[index]
    }

    static func state(index: Int, selectedIndex: Int?, correctIndex: Int) -> PracticeOptionState {
        guard let selectedIndex else { return .idle }
        if index == correctIndex { return .correct }
        if index == selectedIndex { return .wrongPick }
        return .dimmed
    }

    /// VoiceOver label, e.g. "Option A: had already restructured, correct answer".
    static func accessibilityLabel(index: Int, text: String, state: PracticeOptionState) -> String {
        let letter = letter(index)
        switch state {
        case .idle, .dimmed:
            return String(localized: "Option \(letter): \(text)")
        case .correct:
            return String(localized: "Option \(letter): \(text), correct answer")
        case .wrongPick:
            return String(localized: "Option \(letter): \(text), your answer, incorrect")
        }
    }

    static func iconName(for state: PracticeOptionState) -> String? {
        switch state {
        case .idle, .dimmed: return nil
        case .correct: return "checkmark.circle.fill"
        case .wrongPick: return "xmark.circle.fill"
        }
    }
}
