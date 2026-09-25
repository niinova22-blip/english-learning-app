import Foundation

/// A title written in both interface languages, as it appears in package JSON
/// (`{"en": "...", "tr": "..."}`). Either side may be missing.
public struct LocalizedTextDocument: Decodable, Sendable, Equatable {
    public let en: String?
    public let tr: String?
}

/// Picks the interface-language version of a content title, falling back to
/// the base field for other languages or when the translation is missing.
public enum LocalizedTitles {
    public static func pick(base: String, en: String?, tr: String?, languageCode: String) -> String {
        let candidate: String?
        switch languageCode {
        case "tr": candidate = tr
        case "en": candidate = en
        default: candidate = nil
        }
        guard let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        return candidate
    }
}

extension ContentPackage {
    public func name(for languageCode: String) -> String {
        LocalizedTitles.pick(base: name, en: nameEN, tr: nameTR, languageCode: languageCode)
    }

    public func summary(for languageCode: String) -> String? {
        guard let summary else { return nil }
        return LocalizedTitles.pick(base: summary, en: summaryEN, tr: summaryTR, languageCode: languageCode)
    }
}

extension Unit {
    public func theme(for languageCode: String) -> String {
        LocalizedTitles.pick(base: theme, en: themeEN, tr: themeTR, languageCode: languageCode)
    }
}

extension Lesson {
    public func title(for languageCode: String) -> String {
        LocalizedTitles.pick(base: title, en: titleEN, tr: titleTR, languageCode: languageCode)
    }
}
