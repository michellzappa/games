import GameShell

/// DIG's activity keys; the Worker whitelists exactly these under `dig`.
enum DIGEvent: String {
    case launch = "launches"
    case gameStarted = "games_started"
    case gameCompleted = "games_completed"
    case boardWon = "boards_won"
    case boardLost = "boards_lost"
    case guess = "guesses"
    case hintUsed = "hints_used"
    case tutorialViewed = "tutorial_viewed"
    case leaderboardViewed = "leaderboard_viewed"

    func record() {
        ESTTelemetry.record(key: rawValue)
    }
}
