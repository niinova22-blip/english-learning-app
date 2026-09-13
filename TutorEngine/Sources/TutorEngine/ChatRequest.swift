import Foundation

/// One turn in a multi-turn tutor conversation.
public struct ChatTurn: Sendable, Equatable {
    public enum Role: Sendable, Equatable {
        case user
        case assistant
    }

    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// A general-purpose, multi-turn tutor conversation. `history`'s last
/// element is the learner's newest message; every earlier element is a
/// prior turn in the same conversation. Capping how much history is
/// included is the caller's responsibility (see `ChatViewModel` in the
/// App target) — this type makes no assumption about length.
public struct ChatRequest: Sendable, Equatable {
    public let history: [ChatTurn]

    public init(history: [ChatTurn]) {
        self.history = history
    }
}

/// Turns a `ChatRequest` into a single text prompt. Pure and
/// deterministic, like `PromptBuilder`. `MLXTutorEngine` uses this to
/// build its generation prompt via the same proven single-string-prompt
/// path already used for card-scoped asks.
public enum ChatPromptBuilder {
    public static func build(for request: ChatRequest) -> String {
        var prompt = "You are a concise, encouraging English tutor helping a Turkish-speaking learner. Continue the conversation naturally, staying focused on English language learning.\n\n"

        for turn in request.history {
            switch turn.role {
            case .user:
                prompt += "Learner: \(turn.text)\n"
            case .assistant:
                prompt += "Tutor: \(turn.text)\n"
            }
        }

        prompt += "Tutor:"
        return prompt
    }
}
