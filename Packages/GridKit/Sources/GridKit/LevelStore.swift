import Foundation
import Observation

/// Per-level progress: the best score so far (lower is better, moves or
/// centiseconds), how many stars that earned, and whether it is done.
public struct LevelRecord: Codable, Equatable {
    public var best: Int?
    public var stars: Int
    public var completed: Bool

    public init(best: Int? = nil, stars: Int = 0, completed: Bool = false) {
        self.best = best
        self.stars = stars
        self.completed = completed
    }
}

/// Progress through packs of levels, in UserDefaults as one JSON blob.
/// A pack is an id and a count; a level is unlocked when the previous one
/// is completed. Games decide what a score means and how many stars it is
/// worth; this stores the answer.
@Observable
public final class LevelStore {
    private let key: String
    private let defaults: UserDefaults
    private var records: [String: LevelRecord]

    public init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([String: LevelRecord].self, from: data) {
            records = saved
        } else {
            records = [:]
        }
    }

    public func record(pack: String, index: Int) -> LevelRecord {
        records[Self.id(pack, index)] ?? LevelRecord()
    }

    public func isUnlocked(pack: String, index: Int) -> Bool {
        index == 0 || record(pack: pack, index: index - 1).completed
    }

    public func completedCount(pack: String, levels: Int) -> Int {
        (0..<levels).filter { record(pack: pack, index: $0).completed }.count
    }

    /// Records a finished level. `best` keeps the lower score; `stars` keeps
    /// the higher count, so a worse replay never takes a star away.
    public func complete(pack: String, index: Int, score: Int, stars: Int) {
        var current = record(pack: pack, index: index)
        current.completed = true
        current.best = current.best.map { min($0, score) } ?? score
        current.stars = max(current.stars, stars)
        records[Self.id(pack, index)] = current
        save()
    }

    public func reset() {
        records = [:]
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
    }

    private static func id(_ pack: String, _ index: Int) -> String {
        "\(pack)/\(index)"
    }
}
