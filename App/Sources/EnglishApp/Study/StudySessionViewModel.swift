import Foundation
import Observation
import SwiftData
import LearningEngine

@MainActor
@Observable
final class StudySessionViewModel {
    enum Mode: Equatable {
        case review(cardCount: Int)
        case lesson(id: String)
    }

    struct Card: Equatable, Identifiable {
        let id: String
        let headword: String
        let definition: String
        let exampleSentence: String?
        let translationTR: String
        let collocations: [String]
        let skill: Skill
    }

    struct Summary: Equatable {
        let title: String
        let subtitle: String?
        let cardCount: Int
        let knownShare: Double
        let needsReview: [String]
    }

    let mode: Mode
    private(set) var cards: [Card] = []
    private(set) var currentIndex = 0
    private(set) var isRevealed = false
    private(set) var isFinished = false
    private(set) var saveError: String?
    private(set) var lessonTitle: String?

    private let context: ModelContext
    private let userID: String
    private let scheduler: FSRSScheduler
    private let clock: () -> Date
    private var ratings: [(cardID: String, rating: FSRSRating)] = []
    private var lessonItemIDs: [String] = []
    private var cardShownAt = Date()

    init(mode: Mode, context: ModelContext, userID: String, scheduler: FSRSScheduler = FSRSScheduler(), clock: @escaping () -> Date = Date.init) {
        self.mode = mode
        self.context = context
        self.userID = userID
        self.scheduler = scheduler
        self.clock = clock
    }

    var current: Card? { currentIndex < cards.count ? cards[currentIndex] : nil }

    var progress: Double { cards.isEmpty ? 0 : Double(currentIndex) / Double(cards.count) }

    var progressText: String { "\(min(currentIndex + 1, cards.count))/\(cards.count)" }

    var contextLine: String {
        switch mode {
        case .review: return String(localized: "REVIEW")
        case .lesson: return String(localized: "NEW LESSON · \((lessonTitle ?? "").uppercased(with: AppLanguage.current.locale))")
        }
    }

    func start() throws {
        switch mode {
        case .review(let cardCount):
            let items = try TodaySessionCoordinator(context: context, userID: userID, sessionSize: cardCount, now: clock()).buildTodaySession()
            cards = items.compactMap(Self.card)

        case .lesson(let lessonID):
            guard let lesson = try context.fetch(FetchDescriptor<Lesson>(predicate: #Predicate { $0.id == lessonID })).first else {
                isFinished = true
                return
            }
            lessonTitle = lesson.displayTitle
            let ordered = lesson.items.sorted { ($0.frequencyRank, $0.id) < ($1.frequencyRank, $1.id) }
            lessonItemIDs = ordered.map(\.id)
            let seen = try seenItemIDs()
            cards = ordered.filter { !seen.contains($0.id) }.compactMap(Self.card)

            let progressID = LessonProgress.makeID(userID: userID, lessonID: lessonID)
            if try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).isEmpty {
                context.insert(LessonProgress(userID: userID, lessonID: lessonID, startedAt: clock()))
                try context.save()
            }
        }
        currentIndex = 0
        isRevealed = false
        cardShownAt = clock()
        if cards.isEmpty { try finish() }
    }

    func reveal() { isRevealed = true }

    func clearSaveError() { saveError = nil }

    func intervalTexts() -> [FSRSRating: String] {
        guard let card = current else { return [:] }
        let now = clock()
        let prior = try? storedCard(for: card.id)
        var texts: [FSRSRating: String] = [:]
        for rating in FSRSRating.allCases {
            let result = scheduler.review(card: prior ?? nil, rating: rating, now: now)
            texts[rating] = RatingIntervalFormatter.text(from: now, to: result.dueDate)
        }
        return texts
    }

    func rate(_ rating: FSRSRating) {
        guard let card = current else { return }
        let now = clock()
        do {
            try FSRSStateStore().recordReview(
                userID: userID, itemID: card.id, rating: rating, now: now, in: context,
                scheduler: scheduler, reactionTimeMs: Int(now.timeIntervalSince(cardShownAt) * 1000)
            )
        } catch {
            saveError = error.localizedDescription
            return
        }
        ratings.append((card.id, rating))
        currentIndex += 1
        isRevealed = false
        cardShownAt = now
        if currentIndex >= cards.count {
            do { try finish() } catch { saveError = error.localizedDescription }
        }
    }

    func summary() -> Summary {
        let known = ratings.filter { $0.rating == .good || $0.rating == .easy }.count
        let againIDs = Set(ratings.filter { $0.rating == .again }.map(\.cardID))
        let isLesson: Bool
        if case .lesson = mode { isLesson = true } else { isLesson = false }
        return Summary(
            title: isLesson ? String(localized: "Lesson complete") : String(localized: "Review complete"),
            subtitle: isLesson ? lessonTitle : nil,
            cardCount: ratings.count,
            knownShare: ratings.isEmpty ? 0 : Double(known) / Double(ratings.count),
            needsReview: cards.filter { againIDs.contains($0.id) }.map(\.headword)
        )
    }

    private func finish() throws {
        isFinished = true
        guard case .lesson(let lessonID) = mode else { return }
        let seen = try seenItemIDs()
        guard lessonItemIDs.allSatisfy(seen.contains) else { return }
        let progressID = LessonProgress.makeID(userID: userID, lessonID: lessonID)
        if let progress = try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first,
           progress.completedAt == nil {
            progress.completedAt = clock()
            try context.save()
        }
    }

    private func seenItemIDs() throws -> Set<String> {
        let userIDValue = userID
        return Set(try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.userID == userIDValue })).map(\.itemID))
    }

    private func storedCard(for itemID: String) throws -> FSRSCard? {
        let stateID = "\(userID)_\(itemID)"
        guard let state = try context.fetch(FetchDescriptor<UserItemState>(predicate: #Predicate { $0.id == stateID })).first else { return nil }
        return FSRSCard(stability: state.stability, difficulty: state.difficulty, reps: state.reps, lapses: state.lapses, lastReviewedAt: state.lastReviewedAt)
    }

    private static func card(from item: LearningItem) -> Card? {
        guard let content = item.content else { return nil }
        return Card(
            id: item.id, headword: content.headword, definition: content.definition,
            exampleSentence: content.exampleSentences.first, translationTR: content.translationTR,
            collocations: content.collocations, skill: Skill.forItem(type: item.type, lessonSkill: item.lesson?.skill)
        )
    }
}
