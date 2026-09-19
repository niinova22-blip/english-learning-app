import Foundation
import MLXLLM
import MLXLMCommon

/// Loads the bundled on-device model once and serves tutor requests
/// through it. An actor because MLX generation is not safe to call
/// concurrently against the same loaded model state — asks are
/// naturally serialized, one at a time.
public actor MLXTutorEngine: TutorEngine {
    private let modelContainer: ModelContainer
    // Untuned placeholder — revisit with real on-device latency measurements
    // (see the timeout caveat in TutorViewModel).
    private let generateParameters = GenerateParameters(maxTokens: 512)

    /// - Parameter modelDirectory: a local directory containing the
    ///   already-downloaded model weights + tokenizer files (see
    ///   `scripts/fetch-tutor-model.sh`). Never triggers a network
    ///   download itself: `ModelConfiguration(directory:)` marks the
    ///   model as already-local, so `LLMModelFactory` loads straight
    ///   from disk.
    public init(modelDirectory: URL) async throws {
        modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: ModelConfiguration(directory: modelDirectory)
        )
    }

    public func respond(to request: TutorRequest) async throws -> String {
        let prompt = PromptBuilder.build(for: request)
        return try await runGeneration(UserInput(prompt: prompt))
    }

    public func respond(to question: QuestionTutorRequest) async throws -> String {
        let prompt = QuestionPromptBuilder.build(for: question)
        return try await runGeneration(UserInput(prompt: prompt))
    }

    /// Uses `MLXLMCommon`'s native multi-turn input (`UserInput(chat:)`),
    /// so the tutor instructions go in the system role and earlier replies
    /// are real assistant turns rendered by the model's chat template.
    public func respond(to chat: ChatRequest) async throws -> String {
        let messages: [Chat.Message] = ChatPromptBuilder.build(for: chat).map { message in
            switch message.role {
            case .system:
                return .system(message.text)
            case .user:
                return .user(message.text)
            case .assistant:
                return .assistant(message.text)
            }
        }
        let output = try await runGeneration(UserInput(chat: messages))
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The one prepare-and-generate path shared by both kinds of request.
    private func runGeneration(_ userInput: UserInput) async throws -> String {
        let generateParameters = generateParameters

        return try await modelContainer.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            let result = try MLXLMCommon.generate(
                input: lmInput, parameters: generateParameters, context: context
            ) { (_: [Int]) in .more }
            return result.output
        }
    }
}
