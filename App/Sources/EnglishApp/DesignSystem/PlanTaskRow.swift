import SwiftUI
import LearningEngine

enum PlanTaskText {
    static func minutes(_ value: Double) -> Int { Int(value.rounded(.up)) }

    private static func minutesText(_ value: Double) -> String {
        String(localized: "\(minutes(value)) min")
    }

    static func title(_ task: PlanTask) -> String {
        switch task {
        case .review: return String(localized: "Word review")
        case .lesson(_, let title, _, _, _),
             .practiceReview(_, _, let title, _, _, _),
             .locked(_, let title): return title
        }
    }

    static func subtitle(_ task: PlanTask) -> String {
        switch task {
        case .review(let count, let minutes, let isDone):
            let cards = String(localized: "\(count) cards")
            return isDone ? String(localized: "\(cards) · done") : String(localized: "\(cards) · \(minutesText(minutes))")
        case .lesson(_, _, let skill, let minutes, let isDone):
            return isDone ? String(localized: "\(skill.displayName) · done") : String(localized: "New lesson · \(skill.displayName) · \(minutesText(minutes))")
        case .practiceReview(_, _, _, let skill, let minutes, let isDone):
            let skillReview = String(localized: "\(skill.displayName) review")
            return isDone ? String(localized: "\(skillReview) · done") : String(localized: "Topic review · \(skill.displayName) · \(minutesText(minutes))")
        case .locked:
            return String(localized: "Unlock package")
        }
    }
}

struct PlanTaskRow: View {
    let task: PlanTask
    let isHighlighted: Bool
    var isCoachAdded: Bool = false
    let onStart: () -> Void

    private var isDone: Bool {
        switch task {
        case .review(_, _, let done),
             .lesson(_, _, _, _, let done),
             .practiceReview(_, _, _, _, _, let done): return done
        case .locked: return false
        }
    }

    private var isLocked: Bool {
        if case .locked = task { return true } else { return false }
    }

    private var iconName: String {
        if isDone { return "checkmark" }
        switch task {
        case .review: return "arrow.triangle.2.circlepath"
        case .lesson: return "text.book.closed"
        case .practiceReview: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .locked: return "lock.fill"
        }
    }

    private var tint: Color {
        switch task {
        case .review: return Theme.primary
        case .lesson(_, _, let skill, _, _), .practiceReview(_, _, _, let skill, _, _): return skill.color
        case .locked: return Theme.secondaryInk
        }
    }

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? .white : tint)
                    .frame(width: 34, height: 34)
                    .background(isDone ? Theme.primary : tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(PlanTaskText.title(task))
                        .font(.subheadline.weight(.semibold))
                        .strikethrough(isDone)
                        .foregroundStyle(isDone || isLocked ? Theme.secondaryInk : Theme.ink)
                    Text(PlanTaskText.subtitle(task))
                        .font(.caption)
                        .foregroundStyle(isLocked ? Theme.accent : Theme.secondaryInk)
                    if isCoachAdded {
                        Text("Coach added")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 8)
                if isHighlighted && !isDone && !isLocked {
                    Text("Start")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.primary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .background(isLocked ? Theme.paper : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isHighlighted && !isDone ? Theme.primary : Theme.border,
                            style: StrokeStyle(lineWidth: isHighlighted && !isDone ? 1.5 : 1, dash: isLocked ? [5] : []))
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("plan-task")
        .disabled(isDone)
    }
}

#Preview("Plan rows") {
    VStack(spacing: 8) {
        PlanTaskRow(task: .review(cardCount: 14, minutes: 5.6, isDone: true), isHighlighted: false) {}
        PlanTaskRow(task: .lesson(id: "a", title: "Science & Research Methods · 2", skill: .vocabulary, minutes: 8, isDone: false), isHighlighted: true) {}
        PlanTaskRow(task: .practiceReview(itemID: "i", lessonID: "l", title: "Zamanlar (Tenses)", skill: .grammar, minutes: 3, isDone: false), isHighlighted: false) {}
        PlanTaskRow(task: .locked(id: "b", title: "Law, Policy & Society · 1"), isHighlighted: false) {}
    }
    .padding()
    .background(Theme.paper)
}
