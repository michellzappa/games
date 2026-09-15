import GameShell
import SwiftUI

struct DIGLeaderboardView: View {
    private let stats = DIGStats.shared

    var body: some View {
        LeaderboardView(boards: MineSize.allCases.map { size in
            LeaderboardBoard(
                id: DIGLeaderboard.id(for: size),
                title: size.name,
                description: "Fastest clear, \(size.subtitle). Hinted rounds stay local.",
                personalBest: stats.record(for: size).bestSeconds.map(TimeFormat.clock)
            )
        }) { _ in
            DIGEvent.leaderboardViewed.record()
        }
    }
}
