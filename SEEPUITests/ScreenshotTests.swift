import XCTest

/// Raw App Store screenshots for SEEP from stable, local-only surfaces.
/// The launch argument skips the tutorial and Game Center so the capture
/// repeats. `appstore/capture.sh seep <device>` exports the attachments.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureMarketingScreens() throws {
        let app = XCUIApplication()

        launch(app)
        capture(app, "title")

        tapFirst(app, labels: ["All boards"])
        XCTAssertTrue(app.staticTexts["Boards"].waitForExistence(timeout: 5))
        capture(app, "levels")

        tapFirst(app, labels: ["Board 1"])
        waitForBoard(app)
        // Two moves in, so the region and the counter both read.
        tapFirst(app, labels: ["Flood blue", "Flood yellow", "Flood red"])
        tapFirst(app, labels: ["Flood yellow", "Flood red", "Flood blue"])
        capture(app, "board")

        // A won board: the greedy path always finishes inside the limit,
        // and the hint outlines exactly that color, so follow the hint.
        app.terminate()
        launch(app)
        tapFirst(app, labels: ["All boards"])
        tapFirst(app, labels: ["Board 1"])
        waitForBoard(app)
        for _ in 0..<40 {
            if app.staticTexts["Under par"].exists || app.staticTexts["Flooded"].exists { break }
            let hint = app.buttons["Hint"]
            guard hint.waitForExistence(timeout: 2), hint.isEnabled else { break }
            hint.tap()
            let hinted = app.buttons.matching(NSPredicate(format: "value == 'hinted'")).firstMatch
            guard hinted.waitForExistence(timeout: 2) else { break }
            hinted.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
        Thread.sleep(forTimeInterval: 1.2)
        capture(app, "won")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["How to play"])
        XCTAssertTrue(app.staticTexts["One color"].waitForExistence(timeout: 5))
        for _ in 0..<3 { tapFirst(app, labels: ["Next"]) }
        XCTAssertTrue(app.staticTexts["Why a move fails"].waitForExistence(timeout: 5))
        capture(app, "tutorial")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["The idea"])
        XCTAssertTrue(app.staticTexts["A move is a search"].waitForExistence(timeout: 5))
        for _ in 0..<3 { tapFirst(app, labels: ["Step"]) }
        capture(app, "idea")

        // The in-app purchase review screenshot; not a marketing panel.
        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Settings"])
        scrollToTap(app, label: "Support SEEP")
        XCTAssertTrue(app.staticTexts["One-time gift. No subscription."].waitForExistence(timeout: 5))
        capture(app, "support")
    }

    @MainActor
    private func launch(_ app: XCUIApplication) {
        app.launchArguments = ["-SEEPScreenshotMode"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        Thread.sleep(forTimeInterval: 1.2)
    }

    @MainActor
    private func waitForBoard(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Leave board"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.0)
    }

    @MainActor
    private func tapFirst(_ app: XCUIApplication, labels: [String]) {
        for label in labels {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 4), button.isHittable, button.isEnabled {
                button.tap()
                Thread.sleep(forTimeInterval: 0.8)
                return
            }
            let text = app.staticTexts[label]
            if text.waitForExistence(timeout: 2), text.isHittable {
                text.tap()
                Thread.sleep(forTimeInterval: 0.8)
                return
            }
        }
        XCTFail("Could not find any of: \(labels.joined(separator: ", "))")
    }

    @MainActor
    private func scrollToTap(_ app: XCUIApplication, label: String, maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes {
            let button = app.buttons[label]
            if button.exists, button.isHittable {
                button.tap()
                Thread.sleep(forTimeInterval: 0.8)
                return
            }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTFail("\(label) never appeared after \(maxSwipes) scrolls")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
