import Foundation
import GridKit

/// The three classic sizes. Expert is 16 wide and 30 tall here, turned for
/// a portrait phone.
enum MineSize: String, CaseIterable, Identifiable, Codable {
    case patch, field, quarry

    var id: String { rawValue }

    var name: String {
        switch self {
        case .patch: "Patch"
        case .field: "Field"
        case .quarry: "Quarry"
        }
    }

    var width: Int {
        switch self {
        case .patch: 9
        case .field: 16
        case .quarry: 16
        }
    }

    var height: Int {
        switch self {
        case .patch: 9
        case .field: 16
        case .quarry: 30
        }
    }

    var mines: Int {
        switch self {
        case .patch: 10
        case .field: 40
        case .quarry: 99
        }
    }

    var subtitle: String { "\(width) by \(height), \(mines) mines" }

    /// Tries this many seeds for a board the solver clears without a
    /// guess before giving up. Quarry rarely passes; it is marked instead.
    var noGuessAttempts: Int {
        switch self {
        case .patch: 200
        case .field: 60
        case .quarry: 12
        }
    }
}

/// One playable board: where it came from, its size, and how it is laid.
struct MineLevel: Equatable, Hashable {
    enum Kind: Equatable, Hashable {
        case random(MineSize)
        case daily(String)
        case practice
    }

    let kind: Kind
    let size: MineSize?
    let width: Int
    let height: Int
    let mines: Int
    let seed: UInt64

    var title: String {
        switch kind {
        case .random(let size): size.name
        case .daily: "Daily"
        case .practice: "Practice"
        }
    }

    static func random(_ size: MineSize) -> MineLevel {
        MineLevel(kind: .random(size), size: size, width: size.width, height: size.height, mines: size.mines, seed: UInt64.random(in: 0...UInt64.max))
    }

    /// Today's board, the same for everyone: Field size, one seed per UTC day.
    static func daily(_ date: Date = .now) -> MineLevel {
        let size = MineSize.field
        return MineLevel(kind: .daily(dayKey(date)), size: size, width: size.width, height: size.height, mines: size.mines, seed: Seed.daily(date, salt: "dig"))
    }

    static func practice(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) -> MineLevel {
        MineLevel(kind: .practice, size: nil, width: 6, height: 6, mines: 4, seed: seed)
    }

    /// Lays the board. The start cell is seeded too, so a daily opens the
    /// same corner of the same board for everyone. Tries seeds derived from
    /// this one until the solver clears the board without a guess, or the
    /// attempts run out; the second value says which.
    func board() -> (board: MineBoard, noGuess: Bool) {
        var generator = SeededGenerator(seed: seed)
        let start = Int.random(in: 0..<(width * height), using: &generator)
        let attempts = size?.noGuessAttempts ?? 200
        var first: MineBoard?
        for _ in 0..<attempts {
            let candidate = MineBoard.generate(width: width, height: height, mines: mines, start: start, using: &generator)
            if first == nil { first = candidate }
            if MineSolver.isSolvableWithoutGuessing(candidate) {
                return (candidate, true)
            }
        }
        return (first!, false)
    }

    static func dayKey(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}
