import GameShell
import XCTest

/// Raw App Store screenshots from stable, local-only app surfaces.
///
/// The test launch skips the first-launch tutorial and Game Center login so the
/// capture is repeatable and never depends on an account or a network session.
/// `appstore/capture.sh` exports these attachments into the packaging pipeline.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureMarketingScreens() throws {
        let app = XCUIApplication()

        launch(app)
        capture(app, "title")

        tapFirst(app, labels: ["Rules"])
        XCTAssertTrue(app.staticTexts["How to play"].waitForExistence(timeout: 5))
        capture(app, "rules")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Solo 81"])
        waitForGame(app)
        capture(app, "solo-81")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Quick 27"])
        waitForGame(app)
        capture(app, "quick-27")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Duel, one phone"])
        waitForGame(app)
        capture(app, "duel")

        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Rules"])
        XCTAssertTrue(app.staticTexts["How to play"].waitForExistence(timeout: 5))
        tapFirst(app, labels: ["The mathematics"])
        XCTAssertTrue(app.staticTexts["The mathematics"].waitForExistence(timeout: 5))
        capture(app, "mathematics")

        // App Store Connect requires a review screenshot for every in-app
        // purchase, showing the purchase inside the app. This capture is not a
        // marketing panel: product-page.json does not reference it.
        app.terminate()
        launch(app)
        tapFirst(app, labels: ["Settings"])
        // Support sits near the bottom of the Settings form. The element
        // exists immediately but is not hittable until it scrolls into view,
        // and XCUITest never scrolls on its own.
        scrollToTap(app, label: "Support EST")
        XCTAssertTrue(app.staticTexts["One-time gift. No subscription."].waitForExistence(timeout: 5))
        capture(app, "support")
    }

    @MainActor
    private func launch(_ app: XCUIApplication) {
        app.launchArguments = ["-ESTScreenshotMode"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        Thread.sleep(forTimeInterval: 1.2)
    }

    @MainActor
    private func waitForGame(_ app: XCUIApplication) {
        // Wait on GameExitButton, the one control every game mode shows. The
        // deck pile is not universal: PilesView appears in solo and in the
        // iPhone duel, but the iPad duel table shows seats instead, so waiting
        // for "deck" failed every iPad capture at the duel step.
        XCTAssertTrue(app.buttons["End game"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.2)
    }

    @MainActor
    private func tapFirst(_ app: XCUIApplication, labels: [String]) {
        for label in labels {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 4), button.isHittable {
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
    private func scrollToTap(
        _ app: XCUIApplication,
        label: String,
        maxSwipes: Int = 8
    ) {
        // A SwiftUI Form is lazy: a row far below the fold is absent from the
        // accessibility tree entirely, not merely unhittable. So re-check
        // existence after every scroll rather than waiting for it up front.
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
