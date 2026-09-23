import Foundation

/// Everything the model may use to write a coach note: fact lines computed by
/// the app, and the template text it should rewrite. The model never computes
/// numbers; `CoachNoteValidator` rejects any number that is not in here.
public struct CoachRequest: Sendable, Equatable {
    public let facts: [String]
    public let draft: String

    public init(facts: [String], draft: String) {
        self.facts = facts
        self.draft = draft
    }
}

/// Builds the coach prompt as native chat messages. Pure and deterministic.
public enum CoachPromptBuilder {
    public static let systemInstructions =
        "Sen, YDS'ye hazırlanan bir öğrencinin sıcak ve kısa konuşan çalışma koçusun. Her zaman Türkçe yaz ve öğrenciye \"sen\" diye hitap et. Yalnızca sana verilen bilgileri kullan; yeni sayı, tarih ya da yüzde uydurma. 2-4 kısa cümle yaz; liste ya da başlık kullanma."

    public static func build(for request: CoachRequest) -> [ChatPromptMessage] {
        let facts = request.facts.map { "- \($0)" }.joined(separator: "\n")
        let user = """
        Öğrencinin durumu:
        \(facts)

        Taslak not:
        \(request.draft)

        Bu taslağı aynı bilgileri koruyarak, daha kişisel ve cesaret verici bir dille yeniden yaz.
        """
        return [
            ChatPromptMessage(role: .system, text: systemInstructions),
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
