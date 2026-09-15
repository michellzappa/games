import Foundation

/// A minesweeper board: mines, numbers, and what the player has opened or
/// flagged. The board is laid out once, around a start cell that is always
/// a zero, so the first dig opens an area and a seeded board is the same
/// for everyone.
struct MineBoard: Equatable, Codable {
    struct Cell: Equatable, Codable {
        var isMine = false
        var isOpen = false
        var isFlagged = false
        /// Mines among the eight neighbors, 0...8.
        var adjacent = 0
    }

    let width: Int
    let height: Int
    let mineCount: Int
    let start: Int
    private(set) var cells: [Cell]

    var count: Int { width * height }

    /// Lays mines everywhere except the start cell and its neighbors, so the
    /// start is a zero and the first dig always opens something.
    static func generate<G: RandomNumberGenerator>(
        width: Int, height: Int, mines: Int, start: Int, using generator: inout G
    ) -> MineBoard {
        var board = MineBoard(width: width, height: height, mineCount: mines, start: start, cells: Array(repeating: Cell(), count: width * height))
        let protected = Set(board.neighbors(of: start) + [start])
        var candidates = (0..<board.count).filter { !protected.contains($0) }
        precondition(mines <= candidates.count, "too many mines for the board")
        for _ in 0..<mines {
            let pick = Int.random(in: 0..<candidates.count, using: &generator)
            board.cells[candidates[pick]].isMine = true
            candidates.swapAt(pick, candidates.count - 1)
            candidates.removeLast()
        }
        for index in 0..<board.count {
            board.cells[index].adjacent = board.neighbors(of: index).filter { board.cells[$0].isMine }.count
        }
        return board
    }

    func index(row: Int, column: Int) -> Int { row * width + column }
    func row(_ index: Int) -> Int { index / width }
    func column(_ index: Int) -> Int { index % width }

    func neighbors(of index: Int) -> [Int] {
        let r = row(index), c = column(index)
        var result: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 where dr != 0 || dc != 0 {
                let nr = r + dr, nc = c + dc
                if nr >= 0, nr < height, nc >= 0, nc < width {
                    result.append(nr * width + nc)
                }
            }
        }
        return result
    }

    var flagCount: Int { cells.filter(\.isFlagged).count }
    var openCount: Int { cells.filter(\.isOpen).count }
    var remainingMines: Int { mineCount - flagCount }
    var isCleared: Bool { openCount == count - mineCount }

    enum DigResult: Equatable {
        case nothing
        case opened(Int)
        case mine
    }

    /// Opens a cell. A zero floods into its neighbors. A flagged or open
    /// cell is left alone. Returns how many cells opened, or `.mine`.
    @discardableResult
    mutating func dig(_ index: Int) -> DigResult {
        guard !cells[index].isOpen, !cells[index].isFlagged else { return .nothing }
        if cells[index].isMine {
            cells[index].isOpen = true
            return .mine
        }
        var opened = 0
        var stack = [index]
        while let current = stack.popLast() {
            guard !cells[current].isOpen, !cells[current].isFlagged else { continue }
            cells[current].isOpen = true
            opened += 1
            if cells[current].adjacent == 0 {
                stack.append(contentsOf: neighbors(of: current).filter { !cells[$0].isOpen && !cells[$0].isMine })
            }
        }
        return .opened(opened)
    }

    mutating func toggleFlag(_ index: Int) {
        guard !cells[index].isOpen else { return }
        cells[index].isFlagged.toggle()
    }

    /// Chord: on an open number whose flagged neighbors match it, open every
    /// other neighbor. A wrong flag makes this hit a mine, which is the
    /// player's risk, as in the original.
    @discardableResult
    mutating func chord(_ index: Int) -> DigResult {
        let cell = cells[index]
        guard cell.isOpen, cell.adjacent > 0 else { return .nothing }
        let around = neighbors(of: index)
        guard around.filter({ cells[$0].isFlagged }).count == cell.adjacent else { return .nothing }
        var opened = 0
        for neighbor in around where !cells[neighbor].isOpen && !cells[neighbor].isFlagged {
            switch dig(neighbor) {
            case .mine: return .mine
            case .opened(let n): opened += n
            case .nothing: break
            }
        }
        return opened == 0 ? .nothing : .opened(opened)
    }

    /// Closes one cell again. The loss card uses it to ask the solver what
    /// the board proved before the fatal dig.
    mutating func close(_ index: Int) {
        cells[index].isOpen = false
    }

    /// Reveals every mine, for the loss screen. Wrong flags stay flagged so
    /// the player can see them.
    mutating func revealMines() {
        for index in cells.indices where cells[index].isMine {
            cells[index].isOpen = true
        }
    }
}
