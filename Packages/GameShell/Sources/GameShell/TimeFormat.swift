import Foundation

public enum TimeFormat {
    /// mm:ss everywhere. The leaderboard still receives centiseconds; only
    /// the display rounds.
    public static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    public static func shortSeconds(_ interval: TimeInterval) -> String {
        String(format: "%.1fs", max(0, interval))
    }
}
