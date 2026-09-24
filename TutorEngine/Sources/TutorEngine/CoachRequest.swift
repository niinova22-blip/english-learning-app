import Foundation

/// Everything the model may use to write a coach note: fact lines computed by
/// the app, and the template text it should rewrite. The model never computes
/// numbers; `CoachNoteValidator` rejects any number that is not in here.
public struct CoachRequest: Sendable, Equatable {
    public let facts: [String]
    public let draft: String
    public let learnerLanguage: LearnerLanguage

    public init(facts: [String], draft: String, learnerLanguage: LearnerLanguage = .turkish) {
        self.facts = facts
        self.draft = draft
        self.learnerLanguage = learnerLanguage
    }
}

/// Builds the coach prompt as native chat messages. Pure and deterministic.
public enum CoachPromptBuilder {
    public static let systemInstructions =
        "Sen, YDS'ye hazırlanan bir öğrencinin sıcak ve kısa konuşan çalışma koçusun. Her zaman Türkçe yaz ve öğrenciye \"sen\" diye hitap et. Yalnızca sana verilen bilgileri kullan; yeni sayı, tarih ya da yüzde uydurma. 2-4 kısa cümle yaz; liste ya da başlık kullanma."

    public static func systemInstructions(for language: LearnerLanguage) -> String {
        switch language {
        case .turkish:
            return systemInstructions
        case .english:
            return "You are a warm, brief study coach for an English learner. Always write in English and address the learner as \"you\". Use only the information you are given; never invent numbers, dates or percentages. Write 2-4 short sentences; no lists or headings."
        }
    }

    public static func build(for request: CoachRequest) -> [ChatPromptMessage] {
        let facts = request.facts.map { "- \($0)" }.joined(separator: "\n")
        let user: String
        switch request.learnerLanguage {
        case .turkish:
            user = """
            Öğrencinin durumu:
            \(facts)

            Taslak not:
            \(request.draft)

            Bu taslağı aynı bilgileri koruyarak, daha kişisel ve cesaret verici bir dille yeniden yaz.
            """
        case .english:
            user = """
            The learner's situation:
            \(facts)

            Draft note:
            \(request.draft)

            Rewrite this draft in a more personal and encouraging way, keeping the same information.
            """
        }
        return [
            ChatPromptMessage(role: .system, text: systemInstructions(for: request.learnerLanguage)),
            ChatPromptMessage(role: .user, text: user)
        ]
    }
}

/// Decides whether a model-written coach note may be shown.
public enum CoachNoteValidator {
    public static let maxCharacters = 400

    /// The trimmed note, or nil when it is empty, too long, or contains a
    /// number (a run of ASCII digits) that appears in neither the facts nor
    /// the draft.
    public static func validate(_ text: String, for request: CoachRequest) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxCharacters else { return nil }
        let allowed = numbers(in: request.draft + " " + request.facts.joined(separator: " "))
        guard numbers(in: trimmed).isSubset(of: allowed) else { return nil }
        return trimmed
    }

    static func numbers(in text: String) -> Set<String> {
        var result = Set<String>()
        var current = ""
        for character in text {
            if character.isASCII && character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                result.insert(current)
                current = ""
            }
        }
        if !current.isEmpty { result.insert(current) }
        return result
    }
}
