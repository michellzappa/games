import Foundation
import GridKit

/// The daily deal: every player gets the same 81-card shuffle on the same UTC
/// day. A daily never reaches the leaderboard, because a deal can be replayed
/// and learned. It keeps today's best time and a streak of days played to the
/// end, both on this device.
enum DailyStore {
    private static let salt = "est"
    private static let bestDayKey = "dailyBestDay"
    private static let bestTimeKey = "dailyBestTime"
    private static let lastDayKey = "dailyLastDay"
    private static let streakKey = "dailyStreak"

    private static var defaults: UserDefaults { .standard }

    /// The deck order for `date`'s UTC day.
    static func generator(for date: Date = .now) -> SeededGenerator {
        SeededGenerator(seed: Seed.daily(date, salt: salt))
    }

    /// Whole UTC days since 1970, so yesterday is always today minus one.
    static func day(_ date: Date = .now) -> Int {
        Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Today's best time, nil before the first finish of the day.
    static func best(on date: Date = .now) -> TimeInterval? {
        guard defaults.object(forKey: bestDayKey) != nil,
              defaults.integer(forKey: bestDayKey) == day(date)
        else { return nil }
        let time = defaults.double(forKey: bestTimeKey)
        return time > 0 ? time : nil
    }

    static func isDone(on date: Date = .now) -> Bool {
        best(on: date) != nil
    }

    /// Days in a row with a finished daily. A streak that missed yesterday
    /// reads zero, even before today's daily is played.
    static func streak(on date: Date = .now) -> Int {
        guard defaults.object(forKey: lastDayKey) != nil else { return 0 }
        let last = defaults.integer(forKey: lastDayKey)
        let today = day(date)
        guard last == today || last == today - 1 else { return 0 }
        return defaults.integer(forKey: streakKey)
    }

    /// Records a finished daily that was dealt on `date`'s day. A replay on
    /// the same day can lower the best time but never adds to the streak.
    static func recordFinish(time: TimeInterval, dealtOn date: Date) {
        let dealtDay = day(date)
        if best(on: date).map({ time < $0 }) ?? true {
            defaults.set(dealtDay, forKey: bestDayKey)
            defaults.set(time, forKey: bestTimeKey)
        }
        let hasLast = defaults.object(forKey: lastDayKey) != nil
        let last = defaults.integer(forKey: lastDayKey)
        guard !hasLast || dealtDay > last else { return }
        let streak = hasLast && last == dealtDay - 1
            ? defaults.integer(forKey: streakKey) + 1
            : 1
        defaults.set(dealtDay, forKey: lastDayKey)
        defaults.set(streak, forKey: streakKey)
    }
}
