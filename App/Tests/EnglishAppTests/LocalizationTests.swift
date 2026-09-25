import XCTest
@testable import EnglishApp

/// The simulator runs in English, so these tests load the compiled Turkish
/// table directly to prove Turkish devices still get Turkish text.
final class LocalizationTests: XCTestCase {
    private func turkishBundle() throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "tr", ofType: "lproj"),
                                 "tr.lproj missing from the app bundle")
        return try XCTUnwrap(Bundle(path: path))
    }

    func test_turkishTableResolvesPlainKeys() throws {
        let tr = try turkishBundle()
        XCTAssertEqual(tr.localizedString(forKey: "Today", value: nil, table: nil), "Bugün")
        XCTAssertEqual(tr.localizedString(forKey: "Course", value: nil, table: nil), "Ders Yolu")
    }

    func test_englishIsTheDevelopmentLanguage() {
        XCTAssertEqual(Bundle.main.developmentLocalization, "en")
        XCTAssertEqual(Bundle.main.localizedString(forKey: "Today", value: nil, table: nil), "Today")
    }

    func test_turkishTableResolvesPluralKey() throws {
        let tr = try turkishBundle()
        let format = tr.localizedString(forKey: "%lld days", value: nil, table: nil)
        XCTAssertEqual(String(format: format, 3), "3 gün")
    }

    func test_englishPluralRules_selectOneAndOther() {
        let format = Bundle.main.localizedString(forKey: "%lld days", value: nil, table: nil)
        XCTAssertEqual(String.localizedStringWithFormat(format, 1), "1 day")
        XCTAssertEqual(String.localizedStringWithFormat(format, 5), "5 days")
    }

    func test_appLanguageResolution() {
        XCTAssertEqual(AppLanguage.resolve(preferredLocalization: "tr"), .turkish)
        XCTAssertEqual(AppLanguage.resolve(preferredLocalization: "tr-TR"), .turkish)
        XCTAssertEqual(AppLanguage.resolve(preferredLocalization: "en"), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLocalization: "de"), .english)
        XCTAssertEqual(AppLanguage.resolve(preferredLocalization: nil), .english)
        XCTAssertEqual(AppLanguage.turkish.locale.identifier, "tr_TR")
    }
}
