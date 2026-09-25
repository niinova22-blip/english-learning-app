import SwiftUI
import LearningEngine

struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.primary.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SkillBadge: View {
    let skill: Skill

    var body: some View {
        Text(skill.displayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(skill.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(skill.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border)
                Capsule().fill(Theme.primary)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityValue(PercentText.format(Int((min(max(progress, 0), 1) * 100).rounded())))
    }
}

struct RatingButton: View {
    let rating: FSRSRating
    let intervalText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(rating.label).font(.subheadline.weight(.semibold))
                Text(intervalText).font(.caption2)
                    .foregroundStyle(rating == .good ? Color.white.opacity(0.85) : Theme.secondaryInk)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(rating == .good ? Color.white : rating.tint)
            .background(rating == .good ? rating.tint : rating.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(rating.tint.opacity(rating == .good ? 0 : 0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(rating.label), next review \(intervalText)")
    }
}

struct StreakBadge: View {
    let days: Int

    var body: some View {
        Label("\(days) days", systemImage: "flame.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.accent)
            .accessibilityLabel("\(days)-day streak")
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var tint: Color = Theme.ink

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold)).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(Theme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

#Preview("Components · light") {
    ComponentsPreview().preferredColorScheme(.light)
}

#Preview("Components · dark") {
    ComponentsPreview().preferredColorScheme(.dark)
}

private struct ComponentsPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("hypothesis").font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)
                HStack { SkillBadge(skill: .vocabulary); SkillBadge(skill: .grammar); SkillBadge(skill: .reading) }
                ProgressBar(progress: 0.3)
                PaperCard { Text("Paper card").foregroundStyle(Theme.ink) }
                HStack(spacing: 6) {
                    RatingButton(rating: .again, intervalText: "1 gün") {}
                    RatingButton(rating: .hard, intervalText: "1 gün") {}
                    RatingButton(rating: .good, intervalText: "3 gün") {}
                    RatingButton(rating: .easy, intervalText: "9 gün") {}
                }
                HStack { StatTile(value: "10", label: "kelime"); StatTile(value: PercentText.format(80), label: "bildim", tint: Theme.primary); StatTile(value: "12", label: "gün seri", tint: Theme.accent) }
                StreakBadge(days: 12)
                Button("Start") {}.buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
        .background(Theme.paper)
    }
}
