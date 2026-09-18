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

/// One role-tagged message of a native multi-turn chat prompt. A
/// package-local mirror of `MLXLMCommon`'s `Chat.Message`, so the prompt
/// structure can be built and tested without depending on MLX types;
/// `MLXTutorEngine` maps these to `Chat.Message` right before generation.
public struct ChatPromptMessage: Sendable, Equatable {
    public enum Role: Sendable, Equatable {
        case system
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

/// Turns a `ChatRequest` into a native multi-turn chat prompt: the tutor
/// instructions as a system message, followed by every history turn in
/// order with its own role (learner → user, tutor → assistant). Pure and
/// deterministic, like `PromptBuilder`. The model's chat template (Llama
/// 3.2 Instruct) then renders the real role headers.
public enum ChatPromptBuilder {
    public static let systemInstructions =
        "You are a concise, encouraging English tutor helping a Turkish-speaking learner. Continue the conversation naturally, staying focused on English language learning."

    public static func build(for request: ChatRequest) -> [ChatPromptMessage] {
        var messages = [ChatPromptMessage(role: .system, text: systemInstructions)]
        for turn in request.history {
            switch turn.role {
            case .user:
                messages.append(ChatPromptMessage(role: .user, text: turn.text))
            case .assistant:
                messages.append(ChatPromptMessage(role: .assistant, text: turn.text))
            }
        }
        return messages
    }
}
