// App/Sources/EnglishApp/Practice/PracticeSessionViewModel.swift
import Foundation
import Observation
import SwiftData
import LearningEngine

/// Drives every practice lesson type from one place. The screen only ever
/// reads `step`, `current`, `selectedIndex` and `summary()`; all SwiftData
/// access lives here (spec "Screens and flow").
@MainActor
@Observable
final class PracticeSessionViewModel {
    enum Mode: Equatable {
        /// Opened from Bugün or Ders Yolu.
        case lesson(id: String)
        /// Opened from a due practice card: same lesson, fresh selection.
        case review(lessonID: String, itemID: String)

        var lessonID: String {
            switch self {
            case .lesson(let id): return id
            case .review(let lessonID, _): return lessonID
            }
        }
    }

    enum Step: Equatable {
        case loading
        case explanation(String)
        case question
        case summary
        /// The lesson is gone, or has no questions to serve.
        case unavailable
    }

    struct QuestionVM: Equatable, Identifiable {
        let id: String
        let prompt: String
        let options: [String]
        let correctIndex: Int
        let explanationTR: String
    }

    struct PassageVM: Equatable {
        let title: String
        let body: String
    }

    struct Summary: Equatable {
        let correctCount: Int
        let total: Int
        let percent: Int
        let missedPrompts: [String]
        /// "3 gün" — nil only if the FSRS update has not run yet.
        let nextReviewText: String?
    }

    let mode: Mode
    private(set) var step: Step = .loading
    private(set) var questions: [QuestionVM] = []
    private(set) var currentIndex = 0
    private(set) var selectedIndex: Int?
    private(set) var saveError: String?
    private(set) var lessonTitle = ""
    private(set) var skill: Skill = .grammar
    private(set) var passage: PassageVM?

    /// Test seam: makes the next `context.save()` throw, so the save-failure
    /// path can be exercised without a broken store.
    var failNextSaveForTesting = false

    private let context: ModelContext
    private let userID: String
    private let scheduler: FSRSScheduler
    private let clock: () -> Date
    private let seed: UInt64
    private var cardItemID: String?
    private var answers: [(questionID: String, wasCorrect: Bool)] = []
    private var nextDueDate: Date?
    /// Set when `finish()` fails, so `retrySave()` knows what to redo.
    private var finishPending = false
    /// The answer whose attempt save failed; `retrySave()` re-commits it.
    private var pendingAnswer: Int?

    init(
        mode: Mode, context: ModelContext, userID: String,
        scheduler: FSRSScheduler = FSRSScheduler(),
        clock: @escaping () -> Date = Date.init,
        seed: UInt64? = nil
    ) {
        self.mode = mode
        self.context = context
        self.userID = userID
        self.scheduler = scheduler
        self.clock = clock
        self.seed = seed ?? UInt64(bitPattern: Int64(clock().timeIntervalSince1970.rounded()))
    }

    var current: QuestionVM? { currentIndex < questions.count ? questions[currentIndex] : nil }

    var isAnswered: Bool { selectedIndex != nil }

    var progress: Double { questions.isEmpty ? 0 : Double(currentIndex) / Double(questions.count) }

    var progressText: String { "\(min(currentIndex + 1, questions.count))/\(questions.count)" }

    var contextLine: String {
        let title = lessonTitle.uppercased(with: Locale(identifier: "tr_TR"))
        switch mode {
        case .lesson: return "YENİ DERS · \(title)"
        case .review: return "KONU TEKRARI · \(title)"
        }
    }

    func start() throws {
        let lessonID = mode.lessonID
        guard let lesson = try context.fetch(FetchDescriptor<Lesson>(predicate: #Predicate { $0.id == lessonID })).first else {
            step = .unavailable
            return
        }
        lessonTitle = lesson.title
        skill = lesson.skill
        if let storedPassage = lesson.passage {
            passage = PassageVM(title: storedPassage.title, body: storedPassage.body)
        }

        let card = lesson.items.first { !$0.type.isVocabularyCard }
        cardItemID = card?.id

        let pool = lesson.questions
        guard !pool.isEmpty, cardItemID != nil else {
            step = .unavailable
            return
        }

        let lastAttempt = try lastAttempts(for: Set(pool.map(\.id)))
        let candidates = pool.map { question in
            QuestionCandidate(
                id: question.id, order: question.order,
                lastAttemptedAt: lastAttempt[question.id]?.answeredAt,
                lastWasCorrect: lastAttempt[question.id]?.wasCorrect
            )
        }
        var generator = SeededGenerator(seed: seed)
        let size = PracticeScoring.selectionSize(poolCount: pool.count, skill: lesson.skill)
        let chosenIDs = PracticeQuestionSelector.select(from: candidates, size: size, using: &generator)
        let byID = Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        questions = chosenIDs.compactMap { id in
            guard let question = byID[id] else { return nil }
            return QuestionVM(
                id: question.id, prompt: question.prompt, options: question.options,
                correctIndex: question.correctIndex, explanationTR: question.explanationTR
            )
        }
        guard !questions.isEmpty else {
            step = .unavailable
            return
        }

        let progressID = LessonProgress.makeID(userID: userID, lessonID: lessonID)
        if try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).isEmpty {
            context.insert(LessonProgress(userID: userID, lessonID: lessonID, startedAt: clock()))
            try context.save()
        }

        currentIndex = 0
        selectedIndex = nil
        let explanation = card?.content?.explanationTR?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        step = explanation.isEmpty ? .question : .explanation(explanation)
    }

    /// "Sorulara geç" on the explanation card.
    func beginQuestions() {
        guard case .explanation = step else { return }
        step = .question
    }

    /// Commits an answer. Every answer is persisted immediately, so quitting
    /// mid-way still informs the next selection (spec "Recording rules").
    func select(_ index: Int) {
        guard selectedIndex == nil, let question = current else { return }
        saveError = nil
        let attempt = QuestionAttempt(
            userID: userID, questionID: question.id,
            wasCorrect: index == question.correctIndex,
            answeredAt: clock(), selectedIndex: index
        )
        context.insert(attempt)
        do {
            try save()
        } catch {
            context.rollback()
            pendingAnswer = index
            saveError = error.localizedDescription
            return
        }
        pendingAnswer = nil
        answers.append((question.id, index == question.correctIndex))
        selectedIndex = index
    }

    /// "Sonraki" on the feedback card.
    func next() {
        guard step == .question, isAnswered else { return }
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            selectedIndex = nil
            return
        }
        finish()
    }

    func retrySave() {
        saveError = nil
        if finishPending {
            finish()
        } else if let index = pendingAnswer {
            select(index)
        }
    }

    func clearSaveError() { saveError = nil }

    func summary() -> Summary {
        let correct = answers.filter(\.wasCorrect).count
        let total = answers.count
        let missedIDs = Set(answers.filter { !$0.wasCorrect }.map(\.questionID))
        return Summary(
            correctCount: correct,
            total: total,
            percent: total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()),
            missedPrompts: questions.filter { missedIDs.contains($0.id) }.map(\.prompt),
            nextReviewText: nextDueDate.map { RatingIntervalFormatter.text(from: clock(), to: $0) }
        )
    }

    /// Applies the FSRS rating and marks the lesson complete — only ever at
    /// the end of a session, and only as a unit: if either write fails the
    /// screen stays on the question with a retryable error, never in a
    /// half-complete "lesson done" state.
    private func finish() {
        guard let itemID = cardItemID else { return }
        finishPending = true
        let now = clock()
        let rating = PracticeScoring.rating(correct: answers.filter(\.wasCorrect).count, total: answers.count)
        do {
            // Stage the review and the completion, then commit them with ONE
            // save. On failure roll back, so neither is left half-applied in
            // memory or in the store, and a retry starts from a clean slate.
            let state = try FSRSStateStore().stageReview(
                userID: userID, itemID: itemID, rating: rating, now: now,
                in: context, scheduler: scheduler
            )
            let lessonID = mode.lessonID
            let progressID = LessonProgress.makeID(userID: userID, lessonID: lessonID)
            if let progress = try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first,
               progress.completedAt == nil {
                progress.completedAt = now
            }
            try save()
            nextDueDate = state.dueDate
        } catch {
            context.rollback()
            saveError = error.localizedDescription
            return
        }
        finishPending = false
        step = .summary
    }

    private func save() throws {
        if failNextSaveForTesting {
            failNextSaveForTesting = false
            throw PracticeSaveError()
        }
        try context.save()
    }

    /// Most recent attempt per question id, for this user.
    private func lastAttempts(for questionIDs: Set<String>) throws -> [String: QuestionAttempt] {
        let userIDValue = userID
        let rows = try context.fetch(FetchDescriptor<QuestionAttempt>(
            predicate: #Predicate { $0.userID == userIDValue },
            sortBy: [SortDescriptor(\.answeredAt)]
        ))
        var latest: [String: QuestionAttempt] = [:]
        for row in rows where questionIDs.contains(row.questionID) {
            // Explicit comparison, not reliance on sort stability: the newest
            // answeredAt wins; on an exact tie the later-fetched row wins.
            if let existing = latest[row.questionID], existing.answeredAt > row.answeredAt { continue }
            latest[row.questionID] = row
        }
        return latest
    }
}

/// Stand-in failure used by the test seam; never thrown in production.
struct PracticeSaveError: LocalizedError {
    var errorDescription: String? { "Kaydedilemedi. Tekrar dene." }
}
