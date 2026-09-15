import SwiftUI
import LearningEngine

extension Skill {
    var displayName: String {
        switch self {
        case .vocabulary: return "Kelime"
        case .grammar: return "Gramer"
        case .reading: return "Okuma"
        case .listening: return "Dinleme"
        case .writing: return "Yazma"
        case .speaking: return "Konuşma"
        case .pronunciation: return "Telaffuz"
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
        case .again: return "Bilemedim"
        case .hard: return "Zorlandım"
        case .good: return "Bildim"
        case .easy: return "Çok kolay"
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
