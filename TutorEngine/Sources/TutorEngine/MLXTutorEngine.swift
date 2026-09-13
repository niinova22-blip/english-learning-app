import Foundation
import MLX
import MLXLinalg

/// EXPERIMENT (Task 4 follow-up, see task-4-report.md): temporarily
/// stripped of MLXLLM/MLXLMCommon (and therefore of the
/// mlx-swift-examples -> swift-transformers -> Hub dependency chain) to
/// test in isolation whether MLXLinalg's Xcode/XcodeGen linking failure
/// is independent of that chain. This is NOT the real implementation —
/// it is restored to the Task 2 version after the experiment concludes.
/// The `MLXLinalg.inv` call below exists purely to force Xcode to
/// actually link the MLXLinalg framework as part of this build.
public actor MLXTutorEngine: TutorEngine {
    public init(modelDirectory: URL) async throws {
        // Real model loading intentionally removed for this experiment.
    }

    public func respond(to request: TutorRequest) async throws -> String {
        let identity = MLXArray([Float(1), 0, 0, 1], [2, 2])
        let inverse = MLXLinalg.inv(identity)
        eval(inverse)
        return PromptBuilder.build(for: request)
    }
}
