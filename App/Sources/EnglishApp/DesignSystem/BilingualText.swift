import SwiftUI

/// Chooses which language an explanation block shows. Turkish UI opens in
/// Turkish and can switch to English; English UI only ever shows English.
/// A missing side falls back to the base text, never to an empty block.
enum BilingualPick {
    static func text(en: String?, tr: String?, base: String, language: AppLanguage, showEnglish: Bool) -> String {
        let wanted = language == .turkish && !showEnglish ? tr : en
        return nonBlank(wanted) ?? base
    }

    /// The "Show English / Show Turkish" button: Turkish UI with two
    /// different, non-empty sides.
    static func offersToggle(en: String?, tr: String?, language: AppLanguage) -> Bool {
        guard language == .turkish, let en = nonBlank(en), let tr = nonBlank(tr) else { return false }
        return en != tr
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
}

/// Small text button under a bilingual block.
struct LanguageToggleButton: View {
    let showsEnglish: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(showsEnglish ? "Show Turkish" : "Show English", systemImage: "character.bubble")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }
}
