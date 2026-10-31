import XCTest
@testable import EST

/// The table rules: deal, replace in place, compact, finish, save and
/// restore, host handover, and the leaderboard floor. Each deck is seeded,
/// so a failure reproduces exactly.
@MainActor
final class GameEngineTests: XCTestCase {
    /// SplitMix64, local to the tests so they need nothing beyond EST.
    private struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private func makeEngine(seed: UInt64, variant: GameEngine.Variant = .full) -> GameEngine {
        let engine = GameEngine()
        var generator = Generator(state: seed)
        engine.start(variant: variant, using: &generator)
        return engine
    }

    /// Long enough for a match to finish celebrating and resolve.
    private func waitForCelebration() async throws {
        try await Task.sleep(for: .seconds(GameEngine.celebrationDuration + 0.4))
    }

    private func nonSet(in cards: [Card]) -> [Card]? {
        for i in cards.indices {
            for j in cards.indices where j > i {
                for k in cards.indices
                    where k > j && !Card.isValidSet(cards[i], cards[j], cards[k]) {
                    return [cards[i], cards[j], cards[k]]
                }
            }
        }
        return nil
    }

    private func savedRun(table: [Card], deck: [Card], done: [Card] = []) -> GameEngine.SavedRun {
        GameEngine.SavedRun(
            variant: GameEngine.Variant.full.rawValue,
            deck: deck.map(\.id),
            table: table.map(\.id),
            done: done.map(\.id),
            elapsed: 0,
            hintUsed: false,
            savedAt: .now
        )
    }

    // MARK: Dealing

    func testSameSeedDealsTheSameRun() {
        let first = makeEngine(seed: 42)
        let second = makeEngine(seed: 42)
        let other = makeEngine(seed: 43)

        XCTAssertEqual(first.table, second.table)
        XCTAssertEqual(first.deck, second.deck)
        XCTAssertNotEqual(first.deck, other.deck)
    }

    func testStartDealsTwelveWithASetAndKeepsEveryCard() {
        for seed in UInt64(0)..<50 {
            let engine = makeEngine(seed: seed)
            XCTAssertGreaterThanOrEqual(engine.table.count, 12)
            XCTAssertEqual(engine.table.count % 3, 0)
            XCTAssertNotNil(Card.findSet(in: engine.table), "seed \(seed)")
            XCTAssertEqual(Set((engine.table + engine.deck).map(\.id)), Set(0..<81))
            XCTAssertTrue(engine.done.isEmpty)
        }
    }

    func testTwelveWithoutASetDealsThreeMore() {
        // About one opening in thirty has no set among the first twelve.
        var found = false
        for seed in UInt64(0)..<5_000 {
            let engine = makeEngine(seed: seed)
            guard engine.table.count > 12 else { continue }
            found = true
            XCTAssertNil(Card.findSet(in: Array(engine.table.prefix(12))), "seed \(seed)")
            XCTAssertNotNil(Card.findSet(in: engine.table), "seed \(seed)")
            XCTAssertGreaterThan(engine.dealToken, 0)
            break
        }
        XCTAssertTrue(found, "No seed in range opened on a twelve-card cap")
    }

    func testQuickUsesTheTwentySevenSolidCardsAndNine() {
        let engine = makeEngine(seed: 7, variant: .quick)
        let cards = engine.table + engine.deck

        XCTAssertEqual(cards.count, 27)
        XCTAssertTrue(cards.allSatisfy { $0.fill == .solid })
        XCTAssertGreaterThanOrEqual(engine.table.count, 9)
        XCTAssertNotNil(Card.findSet(in: engine.table))
    }

    func testEveryQuickTraitDealsTwentySevenCardsHoldingIt() {
        for trait in Card.Trait.allCases {
            let engine = GameEngine()
            var generator = Generator(state: 9)
            engine.start(variant: .quick, quickTrait: trait, using: &generator)
            let cards = engine.table + engine.deck

            XCTAssertEqual(cards.count, 27, "\(trait)")
            XCTAssertEqual(Set(cards.map { $0.trits[trait.rawValue] }), [0], "\(trait)")
            XCTAssertNotNil(Card.findSet(in: engine.table), "\(trait)")
            XCTAssertEqual(engine.savedRun(hintUsed: false)?.quickTrait, trait.rawValue)
        }
    }

    // MARK: Selecting

    func testSelectingACardTwiceDeselectsIt() {
        let engine = makeEngine(seed: 1)
        let card = engine.table[0]

        engine.select(card)
        XCTAssertEqual(engine.selection, [card])
        engine.select(card)
        XCTAssertTrue(engine.selection.isEmpty)
    }

    func testMismatchExplainsItselfAndLeavesTheTable() throws {
        let engine = makeEngine(seed: 2)
        let table = engine.table
        let trio = try XCTUnwrap(nonSet(in: table))

        var outcome: GameEngine.SelectionOutcome = .pending
        for card in trio { outcome = engine.select(card) }

        guard case .mismatched = outcome else { return XCTFail("expected a mismatch") }
        XCTAssertEqual(engine.mismatchToken, 1)
        XCTAssertEqual(engine.lastMismatch, Set(trio.map(\.id)))
        XCTAssertFalse(engine.mismatchReasons.isEmpty)
        XCTAssertTrue(engine.selection.isEmpty)
        XCTAssertEqual(engine.table, table)
    }

    func testMatchAtTwelveReplacesInPlace() async throws {
        // A seed whose opening is exactly twelve cards.
        var seed: UInt64 = 0
        var engine = makeEngine(seed: seed)
        while engine.table.count != 12 {
            seed += 1
            engine = self.makeEngine(seed: seed)
        }
        let before = engine.table
        let set = try XCTUnwrap(Card.findSet(in: before))
        let setIndices = Set(set.compactMap { before.firstIndex(of: $0) })

        for card in set { engine.select(card) }
        XCTAssertEqual(engine.celebrationIDs, Set(set.map(\.id)))
        XCTAssertEqual(engine.matchToken, 1)
        try await waitForCelebration()

        XCTAssertTrue(engine.celebrationIDs.isEmpty)
        XCTAssertEqual(Set(engine.done), Set(set))
        for index in before.indices where !setIndices.contains(index) {
            XCTAssertEqual(engine.table[index], before[index], "card at \(index) moved")
        }
        for index in setIndices {
            XCTAssertFalse(set.contains(engine.table[index]))
        }
        XCTAssertEqual(engine.table.count + engine.deck.count + engine.done.count, 81)
    }

    func testMatchAboveTwelveCompactsAndKeepsOrder() async throws {
        // Fifteen cards: twelve with no set, then a set of three on the end.
        let opening = try XCTUnwrap((UInt64(0)..<5_000).lazy
            .map { self.makeEngine(seed: $0) }
            .first { $0.table.count == 15 })
        let before = opening.table
        let set = try XCTUnwrap(Card.findSet(in: before))
        let remaining = before.filter { !set.contains($0) }

        for card in set { opening.select(card) }
        try await waitForCelebration()

        XCTAssertEqual(Array(opening.table.prefix(remaining.count)), remaining)
        XCTAssertGreaterThanOrEqual(opening.table.count, 12)
    }

    func testInputIsIgnoredWhileATrioCelebrates() throws {
        let engine = makeEngine(seed: 3)
        let set = try XCTUnwrap(Card.findSet(in: engine.table))
        for card in set { engine.select(card) }
        let other = try XCTUnwrap(engine.table.first { !set.contains($0) })

        engine.select(other)

        XCTAssertTrue(engine.selection.isEmpty)
    }

    // MARK: Finishing

    func testLastMatchFinishesAndStopsTheClockAtTheMatch() async throws {
        let set = [Card(id: 0), Card(id: 1), Card(id: 2)]
        XCTAssertTrue(Card.isValidSet(set[0], set[1], set[2]))
        let engine = GameEngine()
        engine.restore(savedRun(table: set, deck: []))

        for card in set { engine.select(card) }
        let atMatch = engine.elapsed()
        try await waitForCelebration()

        XCTAssertTrue(engine.isFinished)
        XCTAssertEqual(engine.setsFound, 1)
        // The celebration is not charged to the player.
        XCTAssertLessThan(engine.elapsed() - atMatch, GameEngine.celebrationDuration / 2)
    }

    // MARK: Clock

    func testPauseFreezesTheClockAndMarksTheRun() async throws {
        let engine = makeEngine(seed: 4)
        XCTAssertFalse(engine.wasPaused)

        engine.pause()
        let paused = engine.elapsed()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(engine.elapsed(), paused, accuracy: 0.001)
        XCTAssertTrue(engine.isPaused)
        XCTAssertTrue(engine.wasPaused)

        engine.resume()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(engine.elapsed(), paused)
        XCTAssertFalse(engine.isPaused)
    }

    // MARK: Save and restore

    func testSavedRunRestoresTheSameTableAsPaused() throws {
        let engine = makeEngine(seed: 5)
        let saved = try XCTUnwrap(engine.savedRun(hintUsed: true))

        let restored = GameEngine()
        restored.restore(saved)

        XCTAssertEqual(restored.table, engine.table)
        XCTAssertEqual(restored.deck, engine.deck)
        XCTAssertEqual(restored.done, engine.done)
        XCTAssertTrue(restored.wasPaused)
        XCTAssertFalse(restored.isFinished)
    }

    func testAFreshEngineHasNothingToSave() {
        XCTAssertNil(GameEngine().savedRun(hintUsed: false))
    }

    // MARK: Host handover

    func testNewHostResolvesATrioThatWasStillCelebrating() throws {
        let source = makeEngine(seed: 6)
        let set = try XCTUnwrap(Card.findSet(in: source.table))

        let host = GameEngine()
        host.adoptAsHost(
            table: source.table,
            done: [],
            deck: source.deck,
            celebrating: Set(set.map(\.id)),
            matchToken: 4,
            mismatchToken: 2,
            dealToken: 1
        )

        XCTAssertEqual(Set(host.done), Set(set))
        XCTAssertTrue(set.allSatisfy { !host.table.contains($0) })
        XCTAssertTrue(host.celebrationIDs.isEmpty)
        XCTAssertEqual(host.matchToken, 4)
        XCTAssertEqual(host.table.count + host.deck.count + host.done.count, 81)
    }

    // MARK: Leaderboard

    func testLeaderboardRejectsPausedAndImpossibleRuns() throws {
        let floor = GameEngine.minimumLeaderboardTime(for: .full)

        XCTAssertNil(ESTLeaderboard.score(for: 300, variant: .full, wasPaused: true))
        XCTAssertNil(ESTLeaderboard.score(for: floor - 1, variant: .full, wasPaused: false))

        let score = try XCTUnwrap(ESTLeaderboard.score(for: 300.456, variant: .full, wasPaused: false))
        XCTAssertEqual(score.value, 30_045)
        XCTAssertEqual(score.leaderboardID, ESTLeaderboard.soloCompletionTimeID)

        let quick = try XCTUnwrap(ESTLeaderboard.score(for: 60, variant: .quick, wasPaused: false))
        XCTAssertEqual(quick.leaderboardID, ESTLeaderboard.quickCompletionTimeID)
    }

    // MARK: Run insight

    func testRunInsightNamesTheSlowestKindAndTheMostMissedTrait() {
        var insight = RunInsight()
        // 0,1,2 differ only in fill; 0,4,8 differ in shape and fill.
        insight.recordMatch([Card(id: 0), Card(id: 1), Card(id: 2)], seconds: 2)
        insight.recordMatch([Card(id: 0), Card(id: 4), Card(id: 8)], seconds: 9)
        // Only fill breaks: the fills are 0, 0, 1.
        insight.recordMismatch([Card(id: 0), Card(id: 3), Card(id: 7)])

        XCTAssertEqual(insight.fastest, 2)
        XCTAssertEqual(insight.slowest, 9)
        XCTAssertEqual(insight.slowestKind?.differences, 2)
        XCTAssertEqual(insight.mostMissedTrait?.name, "fill")
    }
}
