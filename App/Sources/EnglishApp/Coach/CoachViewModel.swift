import Foundation
import LearningEngine
import TutorEngine

/// Model-written coach notes for the running app session, keyed by day and
/// template text, so a note is reused the same day but never for a changed status.
@MainActor
final class CoachNoteCache {
    private var notes: [String: String] = [:]

    func note(forKey key: String) -> String? { notes[key] }
    func store(_ note: String, forKey key: String) { notes[key] = note }

    static func key(day: Date, draft: String) -> String {
        "\(Int(day.timeIntervalSince1970))|\(draft)"
    }
}

@MainActor
@Observable
final class CoachViewModel {
    enum Source: Equatable { case template, model }

    private(set) var text = ""
    private(set) var source: Source = .template
    private(set) var isGenerating = false

    @ObservationIgnored private var request: CoachRequest?
    @ObservationIgnored private var cacheKey: String?
    @ObservationIgnored private let cache: CoachNoteCache
    @ObservationIgnored private let timeoutNanoseconds: UInt64
    @ObservationIgnored private let engineProvider: @MainActor () async -> (any TutorEngine)?

    init(cache: CoachNoteCache, timeoutSeconds: UInt64 = 30, engineProvider: @escaping @MainActor () async -> (any TutorEngine)?) {
        self.cache = cache
        self.timeoutNanoseconds = timeoutSeconds * 1_000_000_000
        self.engineProvider = engineProvider
    }

    /// Shows today's cached model note for this exact template, else the template.
    func show(_ briefing: CoachBriefing, day: Date) {
        let request = CoachMessageTemplates.request(for: briefing)
        let key = CoachNoteCache.key(day: day, draft: request.draft)
        self.request = request
        cacheKey = key
        if let cached = cache.note(forKey: key) {
            text = cached
            source = .model
        } else {
            text = request.draft
            source = .template
        }
    }

    /// Asks the on-device model for a personal note. Any failure — no engine,
    /// error, timeout, or a reply the validator rejects — keeps the template.
    func requestPersonalNote() async {
        guard let request, let key = cacheKey, source == .template, !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        guard let engine = await engineProvider() else { return }
        let reply = try? await withTutorTimeout(nanoseconds: timeoutNanoseconds) {
            try await engine.respond(to: request)
        }
        guard let reply, let note = CoachNoteValidator.validate(reply, for: request) else { return }
        cache.store(note, forKey: key)
        // The learner may have finished a lesson meanwhile; only show a note
        // written for the template that is still on screen.
        guard key == cacheKey else { return }
        text = note
        source = .model
    }
}
