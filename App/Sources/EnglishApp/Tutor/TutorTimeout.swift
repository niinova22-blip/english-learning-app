import Foundation

/// Thrown when a tutor request takes longer than `TutorViewModel`'s
/// timeout to respond. The spec requires generation timeouts to
/// surface as an inline, retryable error rather than an infinite
/// spinner. Note this only reliably bounds latency if the underlying
/// `TutorEngine.respond(to:)` call cooperates with task cancellation:
/// `withThrowingTaskGroup` won't actually return until the losing
/// child task completes, so against a non-cancellation-checking engine
/// (e.g. `MLXTutorEngine` today) the spinner can in practice outlive
/// this bound. Known, deliberately deferred limitation — not fixed here.
struct TutorTimeoutError: LocalizedError {
    var errorDescription: String? { "Öğretmen yanıt vermekte çok gecikti. Lütfen tekrar dene." }
}

/// Runs `work`, throwing `TutorTimeoutError` if it has not finished after
/// `nanoseconds`. Shared by every tutor/coach request; see the caveat on
/// `TutorTimeoutError` about engines that ignore cancellation.
func withTutorTimeout(nanoseconds: UInt64, _ work: @escaping @Sendable () async throws -> String) async throws -> String {
    try await withThrowingTaskGroup(of: String.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw TutorTimeoutError()
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw TutorTimeoutError()
        }
        return result
    }
}
