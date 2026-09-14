import GameShell
import XCTest
@testable import EST

final class FeedbackTests: XCTestCase {
    func testPayloadUsesTheFeedbackWireContract() throws {
        let payload = ESTFeedbackPayload(
            message: "The tutorial is clear.",
            app: .init(
                version: "1.0.0",
                build: "103",
                iOSMajor: 26,
                deviceFamily: "iphone"
            )
        )

        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(object["schema"] as? Int, 1)
        XCTAssertEqual(object["product"] as? String, "est")
        XCTAssertEqual(object["message"] as? String, "The tutorial is clear.")
        let app = try XCTUnwrap(object["app"] as? [String: Any])
        XCTAssertEqual(app["ios_major"] as? Int, 26)
        XCTAssertEqual(app["device_family"] as? String, "iphone")
    }

    func testMessageNormalizationTrimsAndCaps() {
        let normalized = ESTFeedbackService.normalizedMessage("\r\n  Hello\rWorld  \n")
        XCTAssertEqual(normalized, "Hello\nWorld")

        let capped = ESTFeedbackService.normalizedMessage(
            String(repeating: "x", count: ESTFeedbackService.maxMessageLength + 20)
        )
        XCTAssertEqual(capped.count, ESTFeedbackService.maxMessageLength)
    }
}
