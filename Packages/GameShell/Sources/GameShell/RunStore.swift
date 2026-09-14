import Foundation

/// A run that can be saved mid-game and resumed after a relaunch.
public protocol SavedRunRecord: Codable {
    var savedAt: Date { get }
}

/// Keeps one interrupted run on disk so a player who leaves mid-game can come
/// back to the same board. A game instantiates it with its own run type and
/// key; EST saves only solo runs, because a party run needs everyone back in
/// the room and a network run needs the match.
public struct RunStore<Run: SavedRunRecord> {
    private let key: String
    private let maximumAge: TimeInterval
    private let defaults: UserDefaults

    /// Runs older than `maximumAge` are dropped. The default is three days:
    /// a week-old board is a new game, not a resume, and the Resume button
    /// should not outlive the player's memory of what it points at.
    public init(
        key: String,
        maximumAge: TimeInterval = 60 * 60 * 24 * 3,
        defaults: UserDefaults = .standard
    ) {
        self.key = key
        self.maximumAge = maximumAge
        self.defaults = defaults
    }

    public func save(_ run: Run?) {
        guard let run, let data = try? JSONEncoder().encode(run) else {
            clear()
            return
        }
        defaults.set(data, forKey: key)
    }

    public func load() -> Run? {
        guard let data = defaults.data(forKey: key),
              let run = try? JSONDecoder().decode(Run.self, from: data)
        else { return nil }
        guard Date.now.timeIntervalSince(run.savedAt) < maximumAge else {
            clear()
            return nil
        }
        return run
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
