import Foundation
import GridKit

/// Three packs, each a ladder of board size and color count. A level is a
/// seed, so a pack is a formula, not a file, and every device sees the same
/// board for the same level.
enum FloodPack: String, CaseIterable, Identifiable, Codable {
    case pool, lake, ocean

    var id: String { rawValue }

    var name: String {
        switch self {
        case .pool: "Pool"
        case .lake: "Lake"
        case .ocean: "Ocean"
        }
    }

    var size: Int {
        switch self {
        case .pool: 10
        case .lake: 14
        case .ocean: 18
        }
    }

    var colorCount: Int {
        switch self {
        case .pool: 4
        case .lake: 5
        case .ocean: 6
        }
    }

    var subtitle: String {
        "\(size) by \(size), \(colorCount) colors"
    }

    static let levelCount = 30

    func level(_ index: Int) -> FloodLevel {
        FloodLevel(kind: .pack(self, index), size: size, colorCount: colorCount, seed: Seed.level(pack: rawValue, index: index))
    }
}

/// One playable board: where it came from, its shape, and its seed.
struct FloodLevel: Equatable, Hashable {
    enum Kind: Equatable, Hashable {
        case pack(FloodPack, Int)
        case daily(String)
        case practice
    }

    let kind: Kind
    let size: Int
    let colorCount: Int
    let seed: UInt64

    var title: String {
        switch kind {
        case .pack(let pack, let index): "\(pack.name) \(index + 1)"
        case .daily: "Daily"
        case .practice: "Practice"
        }
    }

    func board() -> FloodBoard {
        var generator = SeededGenerator(seed: seed)
        return FloodBoard.generate(size: size, colorCount: colorCount, using: &generator)
    }

    /// Today's board, the same for everyone. Keyed by the UTC day.
    static func daily(_ date: Date = .now) -> FloodLevel {
        FloodLevel(kind: .daily(dayKey(date)), size: 14, colorCount: 5, seed: Seed.daily(date, salt: "seep"))
    }

    static func practice() -> FloodLevel {
        FloodLevel(kind: .practice, size: 6, colorCount: 3, seed: UInt64.random(in: 0...UInt64.max))
    }

    static func dayKey(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}
