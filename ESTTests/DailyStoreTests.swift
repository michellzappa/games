import XCTest
@testable import EST

final class DailyStoreTests: XCTestCase {
    private let keys = ["dailyBestDay", "dailyBestTime", "dailyLastDay", "dailyStreak"]
    private let day: TimeInterval = 86_400

    override func setUp() {
        super.setUp()
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        super.tearDown()
    }

    func testTheSameDayDealsTheSameDeck() {
        let morning = Date(timeIntervalSince1970: 20_000 * day + 3_600)
        let evening = morning.addingTimeInterval(20 * 3_600)
        let tomorrow = morning.addingTimeInterval(day)

        func deck(_ date: Date) -> [Card] {
            let engine = GameEngine()
            var generator = DailyStore.generator(for: date)
            engine.start(variant: .full, using: &generator)
            return engine.table + engine.deck
        }

        XCTAssertEqual(deck(morning), deck(evening))
        XCTAssertNotEqual(deck(morning), deck(tomorrow))
    }

    func testStreakCountsConsecutiveDaysAndResetsAfterAGap() {
        let first = Date(timeIntervalSince1970: 20_000 * day + 60)

        DailyStore.recordFinish(time: 300, dealtOn: first)
        XCTAssertEqual(DailyStore.streak(on: first), 1)
        XCTAssertEqual(DailyStore.best(on: first), 300)

        // A replay the same day improves the best but not the streak.
        DailyStore.recordFinish(time: 250, dealtOn: first)
        XCTAssertEqual(DailyStore.streak(on: first), 1)
        XCTAssertEqual(DailyStore.best(on: first), 250)

        let second = first.addingTimeInterval(day)
        XCTAssertEqual(DailyStore.streak(on: second), 1, "yesterday keeps the streak alive")
        XCTAssertNil(DailyStore.best(on: second))
        DailyStore.recordFinish(time: 400, dealtOn: second)
        XCTAssertEqual(DailyStore.streak(on: second), 2)

        let afterGap = second.addingTimeInterval(2 * day)
        XCTAssertEqual(DailyStore.streak(on: afterGap), 0)
        DailyStore.recordFinish(time: 400, dealtOn: afterGap)
        XCTAssertEqual(DailyStore.streak(on: afterGap), 1)
    }
}
