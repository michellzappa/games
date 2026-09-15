import Foundation
import Observation

/// DIG's private stats: per size, best time and win rate; the daily
/// streak; guesses and hints. UserDefaults only.
@Observable
final class DIGStats {
    struct SizeRecord: Codable, Equatable {
        var played = 0
        var won = 0
        var bestSeconds: TimeInterval?
    }

    struct Snapshot: Codable, Equatable {
        var sizes: [String: SizeRecord] = [:]
        var guesses = 0
        var hints = 0
        var lossesProven = 0
        var lossesForced = 0
        var dailyLastDay: String?
        var dailyStreak = 0
        var dailyBestStreak = 0
    }

    static let shared = DIGStats()

    private(set) var snapshot: Snapshot
    private let key = "digStats"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = Snapshot()
        }
    }

    func record(for size: MineSize) -> SizeRecord {
        snapshot.sizes[size.rawValue] ?? SizeRecord()
    }

    /// Records a finished round. Returns true when it set a new best time.
    @discardableResult
    func record(_ game: MineGame) -> Bool {
        snapshot.guesses += game.guesses
        if game.hintUsed { snapshot.hints += 1 }
        var newBest = false
        if let size = game.level.size, case .random = game.level.kind {
            var record = self.record(for: size)
            record.played += 1
            if game.status == .won {
                record.won += 1
                let seconds = game.elapsed()
                if record.bestSeconds.map({ seconds < $0 }) ?? true {
                    record.bestSeconds = seconds
                    newBest = true
                }
            }
            snapshot.sizes[size.rawValue] = record
        }
        if game.status == .lost {
            if game.lossReason.hasPrefix("Nothing") { snapshot.lossesForced += 1 } else { snapshot.lossesProven += 1 }
        }
        if game.status == .won, case .daily(let day) = game.level.kind {
            recordDaily(day)
        }
        save()
        return newBest
    }

    func dailySolved(_ day: String) -> Bool { snapshot.dailyLastDay == day }

    func reset() {
        snapshot = Snapshot()
        save()
    }

    private func recordDaily(_ day: String) {
        guard snapshot.dailyLastDay != day else { return }
        if let last = snapshot.dailyLastDay, isYesterday(last, of: day) {
            snapshot.dailyStreak += 1
        } else {
            snapshot.dailyStreak = 1
        }
        snapshot.dailyBestStreak = max(snapshot.dailyBestStreak, snapshot.dailyStreak)
        snapshot.dailyLastDay = day
    }

    private func isYesterday(_ earlier: String, of later: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let a = formatter.date(from: earlier), let b = formatter.date(from: later) else { return false }
        return abs(b.timeIntervalSince(a) - 86_400) < 1
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
