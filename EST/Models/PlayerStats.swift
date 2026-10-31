import Foundation
import Observation

/// Private, aggregate learning stats. Nothing in this model is sent to
/// telemetry: it stays in this app's UserDefaults and can be reset by the
/// player at any time.
@MainActor
@Observable
final class PlayerStats {
    struct Snapshot: Codable, Equatable {
        var completedSoloRounds = 0
        var quickSoloRounds = 0
        var fullSoloRounds = 0
        var attempts = 0
        var correctSets = 0
        /// Index 1...4 is the number of all-different traits in a set.
        var correctByDifference = [Int](repeating: 0, count: 5)
        var secondsByDifference = [TimeInterval](repeating: 0, count: 5)
        /// Order matches Card.audit: count, color, shape, fill.
        var mismatchesByTrait = [Int](repeating: 0, count: 4)
        /// Board opportunity buckets: 0, 1, 2, or 3+ valid sets available.
        var boardSetBuckets = [Int](repeating: 0, count: 4)
        var nearMisses = 0
        // Added after 1.2.0. Optional, so a snapshot saved by an older
        // build still decodes instead of resetting every stat.
        var fastestSet: TimeInterval?
        var longestStreak: Int?
        var currentStreak: Int?
    }

    /// Trait names in Card.audit order, as the stats screens say them.
    static let traitNames = ["number", "color", "shape", "fill"]

    /// How many traits are all different across a valid set, 1...4. Read
    /// from Card.audit so the set math stays in Card.
    static func differenceCount(_ cards: [Card]) -> Int {
        guard cards.count == 3 else { return 0 }
        return Card.audit(cards[0], cards[1], cards[2])
            .filter {
                if case .allDifferent = $0.outcome { return true }
                return false
            }
            .count
    }

    /// Indices (Card.audit order) of the traits a trio breaks.
    static func brokenTraits(_ cards: [Card]) -> [Int] {
        guard cards.count == 3 else { return [] }
        return Card.audit(cards[0], cards[1], cards[2])
            .enumerated()
            .filter { !$0.element.isValid }
            .map { $0.offset }
    }

    static let shared = PlayerStats()

    private static let storageKey = "estPlayerStats"
    private let defaults: UserDefaults
    private(set) var snapshot: Snapshot

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = Snapshot()
        }
    }

    var completedSoloRounds: Int { snapshot.completedSoloRounds }
    var quickSoloRounds: Int { snapshot.quickSoloRounds }
    var fullSoloRounds: Int { snapshot.fullSoloRounds }
    var attempts: Int { snapshot.attempts }
    var correctSets: Int { snapshot.correctSets }
    var mismatches: Int { max(0, snapshot.attempts - snapshot.correctSets) }
    var nearMisses: Int { snapshot.nearMisses }
    var correctByDifference: [Int] { snapshot.correctByDifference }
    var mismatchesByTrait: [Int] { snapshot.mismatchesByTrait }
    var boardSetBuckets: [Int] { snapshot.boardSetBuckets }
    var fastestSet: TimeInterval? { snapshot.fastestSet }

    /// The trait missed most in play, once there are enough misses to mean
    /// something. The training drill leans toward it.
    var trainingFocus: Card.Trait? {
        let misses = snapshot.mismatchesByTrait
        guard misses.reduce(0, +) >= 3,
              let index = misses.indices.max(by: { misses[$0] < misses[$1] })
        else { return nil }
        return Card.Trait(rawValue: index)
    }
    var longestStreak: Int { snapshot.longestStreak ?? 0 }

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correctSets) / Double(attempts)
    }

    func averageTime(for differenceCount: Int) -> TimeInterval? {
        guard (1...4).contains(differenceCount),
              snapshot.correctByDifference[differenceCount] > 0
        else { return nil }
        return snapshot.secondsByDifference[differenceCount]
            / Double(snapshot.correctByDifference[differenceCount])
    }

    /// Records a valid set after GameEngine has accepted it. The difficulty
    /// axis comes from Card.audit, so this model does not duplicate set math.
    /// `hinted` keeps a set the hint pointed at out of the fastest-set
    /// record; it still counts everywhere else.
    func recordMatch(
        _ cards: [Card],
        boardSetCount: Int,
        timeSincePreviousMatch: TimeInterval,
        hinted: Bool = false
    ) {
        guard cards.count == 3 else { return }
        snapshot.attempts += 1
        snapshot.correctSets += 1
        let seconds = max(0, timeSincePreviousMatch)
        let differenceCount = Self.differenceCount(cards)
        if (1...4).contains(differenceCount) {
            snapshot.correctByDifference[differenceCount] += 1
            snapshot.secondsByDifference[differenceCount] += seconds
        }
        let streak = (snapshot.currentStreak ?? 0) + 1
        snapshot.currentStreak = streak
        snapshot.longestStreak = max(snapshot.longestStreak ?? 0, streak)
        if !hinted, seconds > 0, seconds < (snapshot.fastestSet ?? .infinity) {
            snapshot.fastestSet = seconds
        }
        recordBoardOpportunity(boardSetCount)
        save()
    }

    /// Records an invalid three-card attempt and the traits that broke it.
    func recordMismatch(_ cards: [Card], boardSetCount: Int) {
        guard cards.count == 3 else { return }
        snapshot.attempts += 1
        let violations = Self.brokenTraits(cards)
        for index in violations where index < snapshot.mismatchesByTrait.count {
            snapshot.mismatchesByTrait[index] += 1
        }
        if violations.count == 1 {
            snapshot.nearMisses += 1
        }
        snapshot.currentStreak = 0
        recordBoardOpportunity(boardSetCount)
        save()
    }

    func recordCompletedRound(_ variant: GameEngine.Variant) {
        snapshot.completedSoloRounds += 1
        switch variant {
        case .full:
            snapshot.fullSoloRounds += 1
        case .quick:
            snapshot.quickSoloRounds += 1
        }
        save()
    }

    func reset() {
        snapshot = Snapshot()
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func recordBoardOpportunity(_ count: Int) {
        let bucket = min(max(count, 0), 3)
        snapshot.boardSetBuckets[bucket] += 1
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

/// One solo run's numbers, for the game-over card. Lives only as long as the
/// run; the lasting record is PlayerStats.
struct RunInsight: Equatable {
    private(set) var setsByDifference = [Int](repeating: 0, count: 5)
    private(set) var secondsByDifference = [TimeInterval](repeating: 0, count: 5)
    private(set) var mismatchesByTrait = [Int](repeating: 0, count: 4)
    private(set) var fastest: TimeInterval?
    private(set) var slowest: TimeInterval?

    mutating func recordMatch(_ cards: [Card], seconds: TimeInterval) {
        let seconds = max(0, seconds)
        let difference = PlayerStats.differenceCount(cards)
        if (1...4).contains(difference) {
            setsByDifference[difference] += 1
            secondsByDifference[difference] += seconds
        }
        fastest = min(fastest ?? seconds, seconds)
        slowest = max(slowest ?? seconds, seconds)
    }

    mutating func recordMismatch(_ cards: [Card]) {
        for index in PlayerStats.brokenTraits(cards) where index < mismatchesByTrait.count {
            mismatchesByTrait[index] += 1
        }
    }

    var mismatches: Int { mismatchesByTrait.reduce(0, +) }

    /// The kind of set (by differing traits) that took longest on average.
    /// Nil until at least two kinds have been found, since one kind has
    /// nothing to be slow against.
    var slowestKind: (differences: Int, average: TimeInterval)? {
        let averages = (1...4).compactMap { difference -> (Int, TimeInterval)? in
            let count = setsByDifference[difference]
            guard count > 0 else { return nil }
            return (difference, secondsByDifference[difference] / Double(count))
        }
        guard averages.count >= 2,
              let slowest = averages.max(by: { $0.1 < $1.1 })
        else { return nil }
        return slowest
    }

    /// The trait broken most often this run, with its count.
    var mostMissedTrait: (name: String, count: Int)? {
        guard let index = mismatchesByTrait.indices.max(by: {
            mismatchesByTrait[$0] < mismatchesByTrait[$1]
        }), mismatchesByTrait[index] > 0 else { return nil }
        return (PlayerStats.traitNames[index], mismatchesByTrait[index])
    }
}
