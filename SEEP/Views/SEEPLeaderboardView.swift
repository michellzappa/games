import GameShell
import SwiftUI

struct SEEPLeaderboardView: View {
    private let stats = SEEPStats.shared

    var body: some View {
        LeaderboardView(boards: FloodPack.allCases.map { pack in
            let score = SEEPLeaderboard.score(for: pack, store: stats.levels, hinted: stats.hinted(pack))
            return LeaderboardBoard(
                id: SEEPLeaderboard.id(for: pack),
                title: pack.name,
                description: "Total moves over all \(FloodPack.levelCount) boards, \(pack.subtitle). Counts once every board is done without hints.",
                personalBest: score.map { "\($0.value) moves" }
            )
        }) { _ in
            SEEPEvent.leaderboardViewed.record()
        }
    }
}
