import Foundation
import GameShell

/// One board per size, best time in centiseconds, ascending. A hinted
/// round, a board the solver could not verify, and an impossible time all
/// stay local.
enum DIGLeaderboard {
    static func id(for size: MineSize) -> String {
        "dig.\(size.rawValue).time"
    }

    /// The floor is the fastest a human could clear the size without
    /// automation: one second per size step.
    static func minimumCentiseconds(for size: MineSize) -> Int {
        switch size {
        case .patch: 100
        case .field: 1_000
        case .quarry: 3_000
        }
    }

    static func score(for game: MineGame) -> GameCenterScore? {
        guard game.status == .won, !game.hintUsed, let size = game.level.size,
              case .random = game.level.kind else { return nil }
        let seconds = game.elapsed()
        guard seconds.isFinite, seconds <= TimeInterval(Int.max) / 100 else { return nil }
        let centiseconds = Int((seconds * 100).rounded(.down))
        guard centiseconds >= minimumCentiseconds(for: size) else { return nil }
        return GameCenterScore(leaderboardID: id(for: size), value: centiseconds)
    }
}
