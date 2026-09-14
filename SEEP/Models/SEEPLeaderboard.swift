import Foundation
import GameShell
import GridKit

/// One board per pack: the total of the best move counts over all thirty
/// levels, ascending. A pack enters the board only when every level is
/// done and no level was hinted, so the total is a real, comparable score.
enum SEEPLeaderboard {
    static func id(for pack: FloodPack) -> String {
        "seep.\(pack.rawValue).moves"
    }

    static func score(for pack: FloodPack, store: LevelStore, hinted: Set<Int>) -> GameCenterScore? {
        var total = 0
        for index in 0..<FloodPack.levelCount {
            let record = store.record(pack: pack.rawValue, index: index)
            guard record.completed, let best = record.best, !hinted.contains(index) else { return nil }
            total += best
        }
        return GameCenterScore(leaderboardID: id(for: pack), value: total)
    }
}
