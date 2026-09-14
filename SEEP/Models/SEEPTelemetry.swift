import GameShell

/// SEEP's activity keys. The Worker whitelists exactly these under the
/// `seep` product; a key added here must be added there too.
enum SEEPEvent: String {
    case launch = "launches"
    case gameStarted = "games_started"
    case gameCompleted = "games_completed"
    case levelCompleted = "levels_completed"
    case undoUsed = "undos_used"
    case hintUsed = "hints_used"
    case tutorialViewed = "tutorial_viewed"
    case leaderboardViewed = "leaderboard_viewed"

    func record() {
        ESTTelemetry.record(key: rawValue)
    }
}
