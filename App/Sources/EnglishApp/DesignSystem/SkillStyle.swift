import SwiftUI
import LearningEngine

extension Skill {
    var displayName: String {
        switch self {
        case .vocabulary: return String(localized: "Vocabulary")
        case .grammar: return String(localized: "Grammar")
        case .reading: return String(localized: "Reading")
        case .listening: return String(localized: "Listening")
        case .writing: return String(localized: "Writing")
        case .speaking: return String(localized: "Speaking")
        case .pronunciation: return String(localized: "Pronunciation")
        }
    }

    var color: Color {
        switch self {
        case .vocabulary: return Theme.primary
        case .grammar: return Theme.accent
        case .reading: return Theme.reading
        case .listening: return Theme.listening
        case .writing: return Theme.writing
        case .speaking: return Theme.speaking
        case .pronunciation: return Theme.pronunciation
        }
    }
}

extension FSRSRating {
    var label: String {
        switch self {
        case .again: return String(localized: "Forgot")
        case .hard: return String(localized: "Hard")
        case .good: return String(localized: "Knew it")
        case .easy: return String(localized: "Easy")
        }
    }

    var tint: Color {
        switch self {
        case .again: return Theme.danger
        case .hard: return Theme.accent
        case .good: return Theme.primary
        case .easy: return Theme.reading
        }
    }
}
