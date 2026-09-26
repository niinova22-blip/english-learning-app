// App/Sources/EnglishApp/Practice/LessonCardsView.swift
import SwiftUI
import LearningEngine

/// Step 1 of a grammar lesson with cards: one idea per page (what it is for,
/// the pattern, examples, a common mistake), an optional exam tip, then a
/// warm-up question and "Go to questions". Turkish UI opens in Turkish with a
/// "Show English" switch; English UI shows English only.
struct LessonCardsView: View {
    let title: String
    let skill: Skill
    let cards: LessonCards
    var language: AppLanguage = .current
    let onContinue: () -> Void

    enum Page: Hashable {
        case purpose(Int), examples(Int), mistake(Int), examTip, check
    }

    @State private var page: Page = .purpose(0)
    @State private var showsEnglish = false
    @State private var checkAnswer: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var code: String { language == .turkish && !showsEnglish ? "tr" : "en" }
    private var showsTurkishLines: Bool { language == .turkish }

    private var pages: [Page] {
        var result: [Page] = []
        for index in cards.topics.indices {
            result += [.purpose(index), .examples(index), .mistake(index)]
        }
        if cards.examTip != nil { result.append(.examTip) }
        result.append(.check)
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SkillBadge(skill: skill)
                Spacer()
                if language == .turkish {
                    LanguageToggleButton(showsEnglish: showsEnglish) { showsEnglish.toggle() }
                }
            }
            Text(title)
                .font(.appTitle(.title2))
                .foregroundStyle(Theme.ink)
            TabView(selection: $page) {
                ForEach(pages, id: \.self) { page in
                    ScrollView {
                        pageContent(page)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 32)
                    }
                    .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(reduceMotion ? nil : .default, value: page)
            bottomButton
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        if page == .check {
            Button("Go to questions", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(checkAnswer == nil)
        } else {
            Button("Next") {
                if let index = pages.firstIndex(of: page), index + 1 < pages.count {
                    page = pages[index + 1]
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    @ViewBuilder
    private func pageContent(_ page: Page) -> some View {
        switch page {
        case .purpose(let index): purposePage(cards.topics[index])
        case .examples(let index): examplesPage(cards.topics[index])
        case .mistake(let index): mistakePage(cards.topics[index])
        case .examTip: examTipPage
        case .check: checkPage
        }
    }

    private func heading(_ topic: LessonCards.Topic) -> some View {
        Text(topic.title.text(for: code))
            .font(.headline)
            .foregroundStyle(Theme.ink)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold)).tracking(1.2)
            .foregroundStyle(Theme.secondaryInk)
    }

    private func purposePage(_ topic: LessonCards.Topic) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                heading(topic)
                Text(topic.purpose.text(for: code))
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                sectionLabel(String(localized: "PATTERN"))
                WrapLayout(spacing: 6) {
                    ForEach(Array(topic.pattern.enumerated()), id: \.offset) { _, part in
                        PatternChip(part: part)
                    }
                }
                if let note = topic.patternNote {
                    Text(note.text(for: code))
                        .font(.callout)
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
        }
    }

    private func examplesPage(_ topic: LessonCards.Topic) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                heading(topic)
                sectionLabel(String(localized: "EXAMPLES"))
                ForEach(Array(topic.examples.enumerated()), id: \.offset) { _, example in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Self.highlighted(example.en, example.highlight))
                            .font(.body)
                            .foregroundStyle(Theme.ink)
                        if showsTurkishLines {
                            Text(example.tr)
                                .font(.callout)
                                .foregroundStyle(Theme.secondaryInk)
                        }
                    }
                    .padding(.leading, 10)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.accent).frame(width: 2) }
                }
            }
        }
    }

    private func mistakePage(_ topic: LessonCards.Topic) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                heading(topic)
                sectionLabel(String(localized: "COMMON MISTAKE"))
                Label {
                    Text(topic.mistake.wrong).strikethrough().foregroundStyle(Theme.ink)
                } icon: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.danger)
                }
                .accessibilityLabel(String(localized: "Wrong: \(topic.mistake.wrong)"))
                Label {
                    Text(topic.mistake.right).fontWeight(.semibold).foregroundStyle(Theme.ink)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.primary)
                }
                .accessibilityLabel(String(localized: "Right: \(topic.mistake.right)"))
                Text(topic.mistake.note.text(for: code))
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
    }

    @ViewBuilder
    private var examTipPage: some View {
        if let tip = cards.examTip {
            PaperCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Exam tip", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    Text(tip.text(for: code))
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private var checkPage: some View {
        let check = cards.check
        return PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel(String(localized: "QUICK CHECK"))
                Text(check.prompt)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                ForEach(Array(check.options.enumerated()), id: \.offset) { index, option in
                    checkOption(index: index, option: option, correctIndex: check.correctIndex)
                }
                if let checkAnswer {
                    let right = checkAnswer == check.correctIndex
                    Label(right ? "Correct" : "Incorrect", systemImage: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(right ? Theme.primary : Theme.danger)
                    Text(check.explanation.text(for: code))
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .sensoryFeedback(trigger: checkAnswer) { _, picked in
            guard let picked else { return nil }
            return picked == check.correctIndex ? .success : .error
        }
    }

    private func checkOption(index: Int, option: String, correctIndex: Int) -> some View {
        let state = PracticeOptionText.state(index: index, selectedIndex: checkAnswer, correctIndex: correctIndex)
        let tint: Color = switch state {
        case .idle: skill.color
        case .correct: Theme.primary
        case .wrongPick: Theme.danger
        case .dimmed: Theme.secondaryInk
        }
        return Button {
            if checkAnswer == nil { checkAnswer = index }
        } label: {
            HStack(spacing: 10) {
                Text(option)
                    .font(.subheadline)
                    .foregroundStyle(state == .dimmed ? Theme.secondaryInk : Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let icon = PracticeOptionText.iconName(for: state) {
                    Image(systemName: icon).foregroundStyle(tint)
                }
            }
            .padding(12)
            .background(state == .idle ? Theme.surface : tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(state == .idle ? Theme.border : tint, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .allowsHitTesting(checkAnswer == nil)
        .accessibilityLabel(PracticeOptionText.accessibilityLabel(index: index, text: option, state: state))
    }

    /// The example sentence with the highlighted words bold and in the brand color.
    static func highlighted(_ sentence: String, _ highlight: String) -> AttributedString {
        var text = AttributedString(sentence)
        if !highlight.isEmpty, let range = text.range(of: highlight) {
            text[range].font = .body.bold()
            text[range].foregroundColor = Theme.primary
        }
        return text
    }
}

/// One colored piece of the English pattern ("he / she / it", "verb + s").
private struct PatternChip: View {
    let part: LessonCards.PatternPart

    private var color: Color {
        switch part.role {
        case "subject": return Theme.reading
        case "verb": return Theme.primary
        case "aux": return Theme.listening
        case "object": return Theme.accent
        default: return Theme.secondaryInk
        }
    }

    var body: some View {
        Text(part.text)
            .font(.callout.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(color, lineWidth: 1.5))
    }
}

/// Left-aligned rows that wrap, for the pattern chips.
private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

#Preview("Lesson cards") {
    LessonCardsView(
        title: "Present simple",
        skill: .grammar,
        cards: LessonCards(
            topics: [.init(
                title: .init(en: "Present simple for habits", tr: "Alışkanlıklar için geniş zaman"),
                purpose: .init(en: "Use it for routines.", tr: "Düzenli yaptığın şeyler için."),
                pattern: [.init(text: "he / she / it", role: "subject"), .init(text: "verb + s", role: "verb")],
                patternNote: .init(en: "Add -s after he, she, it.", tr: "-s sadece he, she, it ile."),
                examples: [
                    .init(en: "I drink coffee.", tr: "Kahve içerim.", highlight: "drink"),
                    .init(en: "She works here.", tr: "Burada çalışır.", highlight: "works"),
                    .init(en: "We walk to school.", tr: "Okula yürürüz.", highlight: "walk"),
                ],
                mistake: .init(wrong: "He work.", right: "He works.", note: .init(en: "Add -s.", tr: "-s ekle."))
            )],
            check: .init(prompt: "She ---- tea.", options: ["drink", "drinks", "drinking"], correctIndex: 1,
                         explanation: .init(en: "She takes -s.", tr: "She ile -s gelir.")),
            examTip: nil
        ),
        language: .turkish,
        onContinue: {}
    )
    .padding()
    .background(Theme.paper)
}
