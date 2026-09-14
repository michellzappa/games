import Foundation
import GameShell
import GridKit
import Observation

/// SEEP's progress and private stats: level records through `LevelStore`,
/// the daily streak, hinted levels, and the moves-over-par history that the
/// play-style screen reads back. UserDefaults only; reset clears it all.
@Observable
final class SEEPStats {
    struct Snapshot: Codable, Equatable {
        var roundsPlayed = 0
        var roundsWon = 0
        var roundsLost = 0
        var movesOverPar = 0
        var undos = 0
        var hints = 0
        var dailyLastDay: String?
        var dailyStreak = 0
        var dailyBestStreak = 0
        /// Pack levels solved with a hint, as "pack/index". They keep their
        /// stars but never enter the leaderboard total.
        var hintedLevels: Set<String> = []
    }

    static let shared = SEEPStats()

    let levels = LevelStore(key: "seepLevels")
    private(set) var snapshot: Snapshot
    private let key = "seepStats"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = Snapshot()
        }
    }

    func hinted(_ pack: FloodPack) -> Set<Int> {
        Set(snapshot.hintedLevels.compactMap { key -> Int? in
            let parts = key.split(separator: "/")
            guard parts.count == 2, parts[0] == pack.rawValue else { return nil }
            return Int(parts[1])
        })
    }

    /// Records a finished round and returns the pack whose leaderboard total
    /// just became complete, if any.
    @discardableResult
    func record(_ game: FloodGame) -> FloodPack? {
        snapshot.roundsPlayed += 1
        snapshot.undos += game.undoCount
        if game.hintUsed { snapshot.hints += 1 }
        var completedPack: FloodPack?
        switch game.status {
        case .won:
            snapshot.roundsWon += 1
            snapshot.movesOverPar += max(0, game.moves - game.par)
            switch game.level.kind {
            case .pack(let pack, let index):
                levels.complete(pack: pack.rawValue, index: index, score: game.moves, stars: game.stars)
                if game.hintUsed {
                    snapshot.hintedLevels.insert("\(pack.rawValue)/\(index)")
                }
                if levels.completedCount(pack: pack.rawValue, levels: FloodPack.levelCount) == FloodPack.levelCount {
                    completedPack = pack
                }
            case .daily(let day):
                recordDaily(day)
            case .practice:
                break
            }
        case .lost:
            snapshot.roundsLost += 1
        case .playing:
            break
        }
        save()
        return completedPack
    }

    var averageOverPar: Double {
        snapshot.roundsWon == 0 ? 0 : Double(snapshot.movesOverPar) / Double(snapshot.roundsWon)
    }

    func dailySolved(_ day: String) -> Bool {
        snapshot.dailyLastDay == day
    }

    func reset() {
        snapshot = Snapshot()
        levels.reset()
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
