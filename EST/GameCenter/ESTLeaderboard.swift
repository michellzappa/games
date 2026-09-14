import GameShell
import Foundation

/// EST's leaderboard contract. These identifiers, time units, and anti-cheat
/// checks remain product rules rather than becoming requirements of the shared
/// Game Center service.
enum ESTLeaderboard {
    static let soloCompletionTimeID = "est.solo.completion.time"
    static let quickCompletionTimeID = "est.quick.completion.time"

    static func leaderboardID(for variant: GameEngine.Variant) -> String {
        switch variant {
        case .full: soloCompletionTimeID
        case .quick: quickCompletionTimeID
        }
    }

    /// EST ranks completion times in whole centiseconds, ascending. A paused
    /// or physically impossible run remains a local personal best only.
    static func score(
        for seconds: TimeInterval,
        variant: GameEngine.Variant,
        wasPaused: Bool
    ) -> GameCenterScore? {
        guard !wasPaused,
              GameEngine.isLeaderboardTimeEligible(seconds, for: variant),
              seconds <= TimeInterval(Int.max) / 100
        else { return nil }

        let centiseconds = Int((seconds * 100).rounded(.down))
        guard centiseconds >= GameEngine.minimumLeaderboardCentiseconds(for: variant) else {
            return nil
        }
        return GameCenterScore(
            leaderboardID: leaderboardID(for: variant),
            value: centiseconds
        )
    }
}
