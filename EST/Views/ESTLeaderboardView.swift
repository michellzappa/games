import GameShell
import SwiftUI

/// EST's two boards on the shell's leaderboard sheet: Solo 81 and Quick 27,
/// each with the local personal best as a clock.
struct ESTLeaderboardView: View {
    @AppStorage("bestSoloTime") private var bestSoloTime: Double = 0
    @AppStorage("bestQuickTime") private var bestQuickTime: Double = 0

    private var boards: [LeaderboardBoard] {
        [
            LeaderboardBoard(
                id: ESTLeaderboard.leaderboardID(for: .full),
                title: "Solo 81",
                description: "Clear all 81 cards against the clock.",
                personalBest: bestSoloTime > 0 ? TimeFormat.clock(bestSoloTime) : nil
            ),
            LeaderboardBoard(
                id: ESTLeaderboard.leaderboardID(for: .quick),
                title: "Quick 27",
                description: "Clear the 27 solid cards in a shorter round.",
                personalBest: bestQuickTime > 0 ? TimeFormat.clock(bestQuickTime) : nil
            ),
        ]
    }

    var body: some View {
        LeaderboardView(boards: boards) { _ in
            ESTTelemetry.record(.leaderboardViewed)
        }
    }
}
