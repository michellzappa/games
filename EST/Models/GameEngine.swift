import Foundation
import Observation

/// Core table state shared by solo and party modes: deck, table, done pile,
/// selection, and the deal rules (12 on table, +3 while no set is present).
@Observable
final class GameEngine {
    enum SelectionOutcome {
        case pending
        case matched([Card])
        case mismatched([Card])
    }

    /// Full: all 81 cards, 12 on the table. Quick: 27 cards that hold one
    /// trait constant (fill by default, the player can pick another), so it
    /// drops out of the set logic; 9 on the table. Same rules otherwise.
    enum Variant: Int, Equatable {
        case full, quick
    }

    private(set) var variant: Variant = .full
    /// The trait a Quick round holds constant. Ignored by a full round.
    private(set) var quickTrait: Card.Trait = .fill

    var totalCards: Int { variant == .quick ? 27 : 81 }
    var setsTotal: Int { totalCards / 3 }
    private var tableBaseline: Int { variant == .quick ? 9 : 12 }

    private(set) var deck: [Card] = []
    private(set) var table: [Card] = []
    private(set) var done: [Card] = []
    private(set) var selection: Set<Card> = []
    private(set) var isFinished = false

    /// Minimum physically possible leaderboard times for the current table
    /// rules. The final celebration is not charged because the clock ends
    /// when the last match begins.
    static func minimumLeaderboardTime(for variant: Variant) -> TimeInterval {
        switch variant {
        case .full:
            // A full-deck cap has at most 20 cards. The leftover count is a
            // multiple of three, so at least 21 matches are needed and 20
            // celebrations must finish before the final match.
            return 20 * celebrationDuration
        case .quick:
            // A 3-dimensional 27-card deck has at most a 9-card cap. At
            // least six matches are needed and five celebrations precede
            // the final match.
            return 5 * celebrationDuration
        }
    }

    static func minimumLeaderboardCentiseconds(for variant: Variant) -> Int {
        Int((minimumLeaderboardTime(for: variant) * 100).rounded(.up))
    }

    static func isLeaderboardTimeEligible(_ seconds: TimeInterval, for variant: Variant) -> Bool {
        seconds.isFinite && seconds >= minimumLeaderboardTime(for: variant)
    }

    /// `Date` follows the user-adjustable wall clock and is not suitable for
    /// competitive timing. ContinuousClock is monotonic and keeps advancing
    /// while the device sleeps; pause intervals are explicitly subtracted.
    private var startInstant: ContinuousClock.Instant?
    private var endInstant: ContinuousClock.Instant?
    private var pauseStartInstant: ContinuousClock.Instant?
    private var pausedTotal: Duration = .zero

    var isPaused: Bool { pauseStartInstant != nil }
    /// Once a run has been paused or interrupted, it can still set a local
    /// personal best but must not enter the competitive leaderboard.
    private(set) var wasPaused = false

    /// Bumped on every mismatch so views can drive a shake animation.
    private(set) var mismatchToken = 0
    private(set) var lastMismatch: Set<Int> = []
    /// One line per trait the last mismatch broke ("color: red, red vs blue").
    private(set) var mismatchReasons: [String] = []

    /// A matched trio celebrates on the table for a beat before it is
    /// replaced. While non-empty, input is ignored.
    private(set) var celebrationIDs: Set<Int> = []
    /// Bumped on every match at celebration start. Views use it for
    /// haptic and audio feedback.
    private(set) var matchToken = 0
    /// Bumped whenever the engine deals one extra group of cards.
    private(set) var dealToken = 0
    /// Called after the engine advances on its own (celebration ends and
    /// replacements are dealt). The network host rebroadcasts here.
    var onAutoAdvance: (() -> Void)?

    static let celebrationDuration: TimeInterval = 0.9
    private var celebrationTask: Task<Void, Never>?
    private var lastMatchInstant: ContinuousClock.Instant?

    var setsFound: Int { done.count / 3 }

    func start(variant: Variant = .full, quickTrait: Card.Trait = .fill) {
        var generator = SystemRandomNumberGenerator()
        start(variant: variant, quickTrait: quickTrait, using: &generator)
    }

    /// The same generator state deals the same deck, so a test (or a future
    /// daily deal) can reproduce a run exactly.
    func start<G: RandomNumberGenerator>(
        variant: Variant = .full,
        quickTrait: Card.Trait = .fill,
        using generator: inout G
    ) {
        self.variant = variant
        self.quickTrait = quickTrait
        celebrationTask?.cancel()
        celebrationIDs = []
        lastMatchInstant = nil
        dealToken = 0
        startInstant = nil
        endInstant = nil
        pauseStartInstant = nil
        pausedTotal = .zero
        wasPaused = false
        let source = variant == .quick
            ? Card.quickDeck(holding: quickTrait)
            : Card.fullDeck
        deck = source.shuffled(using: &generator)
        table = []
        done = []
        selection = []
        isFinished = false
        table = Array(deck.prefix(tableBaseline))
        deck.removeFirst(min(tableBaseline, deck.count))
        dealUntilSetAvailable()
        startInstant = .now
    }

    /// Everything needed to rebuild an interrupted run. Cards travel as ids
    /// (0...80), the same encoding the network snapshots use.
    struct SavedRun: Codable, Equatable {
        var variant: Int
        var deck: [Int]
        var table: [Int]
        var done: [Int]
        var elapsed: TimeInterval
        var hintUsed: Bool
        var savedAt: Date
        /// Added after 1.2.0; nil in an older save means fill.
        var quickTrait: Int?
    }

    /// A run worth restoring. A finished run and a run that never started
    /// return nil, so the caller never offers to resume nothing.
    func savedRun(hintUsed: Bool) -> SavedRun? {
        guard startInstant != nil, !isFinished else { return nil }
        return SavedRun(
            variant: variant.rawValue,
            deck: deck.map(\.id),
            table: table.map(\.id),
            done: done.map(\.id),
            elapsed: elapsed(),
            hintUsed: hintUsed,
            savedAt: .now,
            quickTrait: quickTrait.rawValue
        )
    }

    /// Rebuilds a run saved earlier. The restored run counts as paused: the
    /// clock stopped outside the app, so the time keeps a personal best but
    /// never reaches the competitive leaderboard.
    func restore(_ run: SavedRun) {
        celebrationTask?.cancel()
        celebrationIDs = []
        lastMatchInstant = nil
        dealToken = 0
        mismatchToken = 0
        lastMismatch = []
        mismatchReasons = []
        variant = Variant(rawValue: run.variant) ?? .full
        quickTrait = run.quickTrait.flatMap(Card.Trait.init(rawValue:)) ?? .fill
        deck = run.deck.map(Card.init(id:))
        table = run.table.map(Card.init(id:))
        done = run.done.map(Card.init(id:))
        selection = []
        endInstant = nil
        pauseStartInstant = nil
        pausedTotal = .zero
        wasPaused = true
        isFinished = deck.isEmpty && Card.findSet(in: table) == nil
        startInstant = ContinuousClock.now - .seconds(max(0, run.elapsed))
    }

    /// Rebuilds the authoritative table on a device that has just become the
    /// host of a network match. The tokens carry over so a client never sees a
    /// counter run backwards.
    ///
    /// `celebrating` is a trio the departed host matched but never resolved.
    /// Its cards already count for their collector, so this finishes the
    /// celebration the way the old host would have: cards out of play,
    /// replacements dealt.
    func adoptAsHost(
        table newTable: [Card],
        done newDone: [Card],
        deck newDeck: [Card],
        celebrating: Set<Int>,
        matchToken newMatchToken: Int,
        mismatchToken newMismatchToken: Int,
        dealToken newDealToken: Int
    ) {
        celebrationTask?.cancel()
        celebrationIDs = []
        lastMatchInstant = nil
        variant = .full
        deck = newDeck
        table = newTable
        done = newDone
        selection = []
        lastMismatch = []
        mismatchReasons = []
        matchToken = newMatchToken
        mismatchToken = newMismatchToken
        dealToken = newDealToken
        isFinished = false
        startInstant = .now
        endInstant = nil
        pauseStartInstant = nil
        pausedTotal = .zero
        wasPaused = false
        let celebratingCards = table.filter { celebrating.contains($0.id) }
        if celebratingCards.isEmpty {
            if deck.isEmpty, Card.findSet(in: table) == nil {
                isFinished = true
                endInstant = .now
            }
        } else {
            resolveMatched(celebratingCards)
        }
    }

    func elapsed() -> TimeInterval {
        guard let startInstant else { return 0 }
        let effectiveEnd = endInstant ?? pauseStartInstant ?? .now
        let elapsed = timeInterval(startInstant.duration(to: effectiveEnd))
        return max(0, elapsed - timeInterval(pausedTotal))
    }

    func pause() {
        guard startInstant != nil, !isFinished, pauseStartInstant == nil else { return }
        wasPaused = true
        pauseStartInstant = .now
    }

    func resume() {
        guard let pauseStartInstant else { return }
        // A final match can resolve while a pause overlay is still visible.
        // Never subtract time that occurred after the engine already ended.
        if let endInstant {
            if pauseStartInstant < endInstant {
                pausedTotal += pauseStartInstant.duration(to: endInstant)
            }
        } else {
            pausedTotal += pauseStartInstant.duration(to: .now)
        }
        self.pauseStartInstant = nil
    }

    /// Toggle a card in the selection. Evaluates when the third card lands.
    @discardableResult
    func select(_ card: Card) -> SelectionOutcome {
        guard !isFinished, celebrationIDs.isEmpty, table.contains(card) else { return .pending }
        if selection.contains(card) {
            selection.remove(card)
            return .pending
        }
        selection.insert(card)
        guard selection.count == 3 else { return .pending }

        let picked = Array(selection)
        selection = []
        if Card.isValidSet(picked[0], picked[1], picked[2]) {
            beginCelebration(picked)
            return .matched(picked)
        } else {
            lastMismatch = Set(picked.map(\.id))
            mismatchReasons = Card.violationDescriptions(picked[0], picked[1], picked[2])
            mismatchToken += 1
            return .mismatched(picked)
        }
    }

    func clearSelection() {
        selection = []
    }

    /// Matched cards stay on the table and glow for a beat; the actual
    /// replacement deal happens in `finalizeMatch`.
    private func beginCelebration(_ cards: [Card]) {
        celebrationIDs = Set(cards.map(\.id))
        matchToken += 1
        lastMatchInstant = .now
        celebrationTask?.cancel()
        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.celebrationDuration))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.finalizeMatch(cards) }
        }
    }

    private func finalizeMatch(_ cards: [Card]) {
        guard !celebrationIDs.isEmpty else { return }
        celebrationIDs = []
        resolveMatched(cards)
        onAutoAdvance?()
    }

    private func resolveMatched(_ cards: [Card]) {
        done.append(contentsOf: cards)
        let indices = cards.compactMap { table.firstIndex(of: $0) }.sorted()
        if table.count <= tableBaseline, deck.count >= 3 {
            // Replace in place so the grid stays stable.
            for i in indices {
                table[i] = deck.removeFirst()
            }
        } else {
            for i in indices.reversed() {
                table.remove(at: i)
            }
        }
        dealUntilSetAvailable()
        if deck.isEmpty, Card.findSet(in: table) == nil {
            isFinished = true
            // Clock the finish at the moment of the final match, not after
            // its celebration animation.
            endInstant = lastMatchInstant ?? .now
        }
    }

    private func timeInterval(_ duration: Duration) -> TimeInterval {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    /// The physical game's rule: if the table has no valid set, deal three more
    /// (12 -> 15 -> ...), until one exists or the deck runs out.
    private func dealUntilSetAvailable() {
        while Card.findSet(in: table) == nil, !deck.isEmpty {
            let draw = min(3, deck.count)
            table.append(contentsOf: deck.prefix(draw))
            deck.removeFirst(draw)
            dealToken += 1
        }
    }
}
