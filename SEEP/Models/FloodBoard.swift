import Foundation
import GridKit

/// A square board of colored cells and the one move the game has: flood
/// the region that touches the top-left corner with a new color. The region
/// grows to include every neighbor of that color. The board is solved when
/// one color covers it.
struct FloodBoard: Equatable, Codable {
    let size: Int
    let colorCount: Int
    /// Row-major color indexes, 0..<colorCount.
    private(set) var cells: [Int]

    init(size: Int, colorCount: Int, cells: [Int]) {
        precondition(cells.count == size * size)
        self.size = size
        self.colorCount = colorCount
        self.cells = cells
    }

    /// A random board. The generator decides the board, so a level is a
    /// seed and every device sees the same cells.
    static func generate<G: RandomNumberGenerator>(size: Int, colorCount: Int, using generator: inout G) -> FloodBoard {
        let cells = (0..<(size * size)).map { _ in Int.random(in: 0..<colorCount, using: &generator) }
        return FloodBoard(size: size, colorCount: colorCount, cells: cells)
    }

    func color(row: Int, column: Int) -> Int {
        cells[row * size + column]
    }

    /// The color of the corner the flood grows from.
    var floodColor: Int { cells[0] }

    var isSolved: Bool {
        cells.allSatisfy { $0 == cells[0] }
    }

    /// Cell indexes connected to the corner through cells of the corner's
    /// color. Breadth-first over the four neighbors.
    func region() -> [Int] {
        region(ifCornerWere: floodColor)
    }

    var regionSize: Int { region().count }

    /// The region the corner would own after a flood to `color`: the current
    /// region plus every cell of `color` connected to it. Used by the greedy
    /// solver and the hint without copying the board.
    func regionSize(afterFloodTo color: Int) -> Int {
        guard color != floodColor else { return regionSize }
        var visited = [Bool](repeating: false, count: cells.count)
        var queue = [0]
        visited[0] = true
        var count = 0
        let own = floodColor
        while let index = queue.popLast() {
            count += 1
            for next in neighbors(of: index) where !visited[next] {
                let value = cells[next]
                if value == own || value == color {
                    visited[next] = true
                    queue.append(next)
                }
            }
        }
        return count
    }

    /// Floods the corner region with `color`. Returns false and changes
    /// nothing when `color` is already the corner color, so a wasted tap
    /// never counts as a move.
    @discardableResult
    mutating func flood(to color: Int) -> Bool {
        guard color != floodColor, (0..<colorCount).contains(color) else { return false }
        for index in region() {
            cells[index] = color
        }
        return true
    }

    /// The color that grows the region most on the next move. Ties go to
    /// the lowest index, so the hint is deterministic.
    func greedyMove() -> Int {
        var best = (color: floodColor, size: 0)
        for color in 0..<colorCount where color != floodColor {
            let size = regionSize(afterFloodTo: color)
            if size > best.size {
                best = (color, size)
            }
        }
        return best.color
    }

    /// The moves the greedy player takes to solve this board. It is not the
    /// optimum, which is NP-hard to find, but it is a par a careful player
    /// can beat, and it is cheap: at most a few hundred region scans.
    func greedyPath() -> [Int] {
        var board = self
        var path: [Int] = []
        while !board.isSolved {
            let move = board.greedyMove()
            board.flood(to: move)
            path.append(move)
        }
        return path
    }

    private func region(ifCornerWere color: Int) -> [Int] {
        var visited = [Bool](repeating: false, count: cells.count)
        var queue = [0]
        visited[0] = true
        var found: [Int] = []
        while let index = queue.popLast() {
            found.append(index)
            for next in neighbors(of: index) where !visited[next] && cells[next] == color {
                visited[next] = true
                queue.append(next)
            }
        }
        return found
    }

    private func neighbors(of index: Int) -> [Int] {
        let row = index / size, column = index % size
        var result: [Int] = []
        if row > 0 { result.append(index - size) }
        if row < size - 1 { result.append(index + size) }
        if column > 0 { result.append(index - 1) }
        if column < size - 1 { result.append(index + 1) }
        return result
    }
}
