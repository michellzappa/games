import XCTest

/// Raw App Store screenshots for DIG from stable, local-only surfaces.
/// The launch argument skips the tutorial and Game Center so the capture
/// repeats. `appstore/capture.sh dig <device>` exports the attachments.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureMarketingScreens() throws {
        let app = XCUIApplication()

        launch(app)
        capture(app, "title")

        tapFirst(app, labels: ["Patch, 9 by 9, 10 mines"])
        waitForBoard(app)
        // The start cell is open, so numbers already show. One hint outlines
        // a safe cell for the capture.
        let hint = app.buttons["Hint"]
        if hint.waitForExistence(timeout: 3), hint.isEnabled {
            hint.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        capture(app, "board")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["How to play"])
        XCTAssertTrue(app.staticTexts["Open every safe cell"].waitForExistence(timeout: 5))
        for _ in 0..<3 { tapFirst(app, labels: ["Next"]) }
        XCTAssertTrue(app.staticTexts["One deduction"].waitForExistence(timeout: 5))
        capture(app, "tutorial")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["The idea"])
        XCTAssertTrue(app.staticTexts["Every number is an equation"].waitForExistence(timeout: 5))
        capture(app, "idea")

        // The in-app purchase review screenshot; not a marketing panel.
        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Settings"])
        scrollToTap(app, label: "Support DIG")
        XCTAssertTrue(app.staticTexts["One-time gift. No subscription."].waitForExistence(timeout: 5))
        capture(app, "support")
    }

    @MainActor
    private func launch(_ app: XCUIApplication) {
        app.launchArguments = ["-DIGScreenshotMode"]
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
