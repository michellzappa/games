import XCTest
@testable import EST

final class CardTests: XCTestCase {
    func testFullDeckContainsEveryCardIDExactlyOnce() {
        let deck = Card.fullDeck

        XCTAssertEqual(deck.count, 81)
        XCTAssertEqual(Set(deck.map(\.id)), Set(0..<81))
    }

    func testCompletingEveryDistinctPairProducesAValidSet() {
        let deck = Card.fullDeck

        for index in deck.indices {
            for otherIndex in deck.indices where otherIndex != index {
                let first = deck[index]
                let second = deck[otherIndex]
                let third = Card.completing(first, second)

                XCTAssertTrue(
                    Card.isValidSet(first, second, third),
                    "Pair \(first.id), \(second.id) completed to invalid card \(third.id)"
                )
                XCTAssertNotEqual(third, first)
                XCTAssertNotEqual(third, second)
            }
        }
    }

    func testAuditIdentifiesEachBrokenTrait() {
        let first = Card(count: 1, tint: .red, symbol: .circle, fill: .solid)
        let second = Card(count: 1, tint: .blue, symbol: .circle, fill: .solid)
        let third = Card(count: 2, tint: .red, symbol: .circle, fill: .solid)

        let verdicts = Card.audit(first, second, third)

        XCTAssertEqual(verdicts.count, 4)
        XCTAssertEqual(verdicts.filter { !$0.isValid }.map(\.label), ["count", "color"])
        XCTAssertEqual(Card.violationDescriptions(first, second, third).count, 2)
    }

    func testAccessibilityDescriptionUsesAllFourTraits() {
        let card = Card(count: 3, tint: .blue, symbol: .triangle, fill: .solid)

        XCTAssertEqual(card.accessibilityDescription, "three blue solid triangles")
    }

    func testNearMissBreaksOnlyTheChosenTrait() {
        for trait in Card.Trait.allCases {
            for _ in 0..<50 {
                let trio = Card.nearMissTrio(breaking: trait)
                XCTAssertEqual(Set(trio).count, 3)
                let broken = Card.audit(trio[0], trio[1], trio[2])
                    .enumerated()
                    .filter { !$0.element.isValid }
                    .map { $0.offset }
                XCTAssertEqual(broken, [trait.rawValue])
            }
        }
    }

    func testTrainingNeverOffersAFalseNonSet() {
        for _ in 0..<200 {
            let question = Card.trainingTrio(missesByTrait: [0, 9, 0, 0])
            let cards = question.cards
            XCTAssertEqual(Card.isValidSet(cards[0], cards[1], cards[2]), question.isSet)
        }
    }
}
