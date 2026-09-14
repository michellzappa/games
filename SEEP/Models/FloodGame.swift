import Foundation
import GameShell
import Observation

/// One round of SEEP: a board, the moves so far, undo, par, and the win or
/// loss. Par is the greedy solver's move count; the limit is par plus three,
/// so a player who wanders still finishes most boards, and a player who
/// beats par earns the third star.
@Observable
final class FloodGame {
    enum Status: Equatable {
        case playing
        case won
        case lost
    }

    let level: FloodLevel
    let par: Int
    let limit: Int
    private(set) var board: FloodBoard
    private(set) var history: [FloodBoard] = []
    private(set) var status: Status = .playing
    private(set) var hintColor: Int?
    private(set) var hintUsed = false
    private(set) var undoCount = 0
    /// Bumped on every accepted move, for haptics and audio.
    private(set) var moveToken = 0

    init(level: FloodLevel) {
        let board = level.board()
        self.level = level
        self.board = board
        par = board.greedyPath().count
        limit = par + 3
    }

    var moves: Int { history.count }
    var movesLeft: Int { limit - moves }
    var canUndo: Bool { !history.isEmpty && status != .won }

    /// Stars for a solved board: three at or under par, two one over, one
    /// for any finish.
    var stars: Int {
        guard status == .won else { return 0 }
        if moves <= par { return 3 }
        if moves == par + 1 { return 2 }
        return 1
    }

    /// One line on why the round was lost, from the same solver that set par.
    var lossReason: String {
        "This board floods in \(par) moves. Each move should join the largest color touching the region."
    }

    func select(color: Int) {
        guard status == .playing else { return }
        let before = board
        guard board.flood(to: color) else { return }
        history.append(before)
        hintColor = nil
        moveToken += 1
        if board.isSolved {
            status = .won
        } else if moves >= limit {
            status = .lost
        }
    }

    func undo() {
        guard canUndo, let previous = history.popLast() else { return }
        board = previous
        status = .playing
        hintColor = nil
        undoCount += 1
    }

    func restart() {
        board = level.board()
        history = []
        status = .playing
        hintColor = nil
    }

    /// Shows the greedy move. A hinted round keeps its stars locally but
    /// never counts toward the leaderboard.
    func revealHint() {
        guard status == .playing else { return }
        hintColor = board.greedyMove()
        hintUsed = true
    }
}
