import XCTest

/// Walks the main screens in screenshot mode (fresh data, demo store with an
/// eligible trial) and saves a PNG of each to $SCREENSHOT_DIR. Run by the
/// "Screenshots" workflow; not part of the regular test run.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    func test_turkish() { capture(language: "tr", locale: "tr_TR", prefix: "tr") }
    func test_english() { capture(language: "en", locale: "en_US", prefix: "en") }
    func test_turkishDark() { capture(language: "tr", locale: "tr_TR", prefix: "tr-koyu", dark: true) }

    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? NSTemporaryDirectory()
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func shot(_ name: String, _ prefix: String) {
        sleep(1)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(prefix)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        try? screenshot.pngRepresentation.write(to: outputDirectory.appendingPathComponent("\(prefix)-\(name).png"))
    }

    @discardableResult
    private func tap(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    private func capture(language: String, locale: String, prefix: String, dark: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestScreenshots", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            + (dark ? ["-UITestDark"] : [])
        app.launch()

        // Onboarding
        let business = app.buttons["package-business-english-1"]
        XCTAssertTrue(business.waitForExistence(timeout: 30))
        shot("01-hedef-secimi", prefix)
        business.tap()
        tap(app.buttons["onboarding-continue"].firstMatch)
        shot("02-hedef-tarih", prefix)
        tap(app.buttons["onboarding-continue"].firstMatch)
        tap(app.buttons["onboarding-continue"].firstMatch)
        shot("03-hatirlatici", prefix)
        tap(app.buttons["onboarding-reminder-skip"])
        tap(app.buttons["onboarding-skip-test"])
        if app.buttons["trial-try"].waitForExistence(timeout: 10) {
            shot("04-deneme-teklifi", prefix)
            app.buttons["trial-try"].tap()
            if app.buttons["paywall-close"].waitForExistence(timeout: 10) {
                sleep(2)
                shot("05-ai-premium-ust", prefix)
                app.swipeUp()
                shot("06-ai-premium-ozellikler", prefix)
                app.swipeUp()
                app.swipeUp()
                shot("07-ai-premium-planlar", prefix)
                app.swipeUp()
                shot("08-ai-premium-alt", prefix)
                app.buttons["paywall-close"].tap()
            }
            tap(app.buttons["trial-not-now"])
        }

        // Today
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        shot("09-bugun", prefix)
        app.swipeUp()
        shot("10-bugun-devam", prefix)
        app.swipeDown()

        // Course
        app.tabBars.buttons.element(boundBy: 1).tap()
        shot("11-ders-yolu", prefix)
        app.swipeUp()
        shot("12-ders-yolu-devam", prefix)

        // Profile and goal switcher
        let tabs = app.tabBars.buttons
        tabs.element(boundBy: tabs.count - 1).tap()
        shot("13-profil", prefix)
        if tap(app.buttons["profile-change-goal"], timeout: 5) {
            shot("14-hedef-degistir", prefix)
            tap(app.buttons["goal-switcher-close"])
        }
        app.swipeUp()
        shot("15-profil-hatirlaticilar", prefix)

        // A study card, front and back
        tabs.element(boundBy: 0).tap()
        if tap(app.buttons["plan-task"].firstMatch) {
            if app.buttons["study-reveal"].waitForExistence(timeout: 10) {
                shot("16-kelime-karti-on", prefix)
                app.buttons["study-reveal"].tap()
                shot("17-kelime-karti-arka", prefix)
            } else {
                shot("16-ders", prefix)
            }
        }
    }
}
