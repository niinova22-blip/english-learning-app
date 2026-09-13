import Foundation
import MLXLLM
import MLXLMCommon

/// Loads the bundled on-device model once and serves tutor requests
/// through it. An actor because MLX generation is not safe to call
/// concurrently against the same loaded model state — asks are
/// naturally serialized, one at a time.
public actor MLXTutorEngine: TutorEngine {
    private let modelContainer: ModelContainer
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
        let userInput = UserInput(prompt: prompt)
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
