import Foundation
import GameShell
import Observation

/// One round: the board, the clock, the outcome, and the one line that
/// explains a loss. The clock starts on the first dig and stops at the
/// moment of the win or the mine, on a monotonic clock, as in EST.
@Observable
final class MineGame {
    enum Status: Equatable {
        case ready
        case playing
        case won
        case lost
    }

    enum Mode {
        case dig
        case flag
    }

    let level: MineLevel
    let noGuess: Bool
    private(set) var board: MineBoard
    private(set) var status: Status = .ready
    /// The cell that blew up, on a loss.
    private(set) var exploded: Int?
    private(set) var hintCell: Int?
    private(set) var hintUsed = false
    /// Digs the solver could not prove safe at the time. A count, not a
    /// verdict: a forced guess on a hard board is not a mistake.
    private(set) var guesses = 0
    private(set) var digToken = 0
    private(set) var flagToken = 0
    var mode: Mode = .dig

    private var startInstant: ContinuousClock.Instant?
    private var endInstant: ContinuousClock.Instant?

    init(level: MineLevel) {
        self.level = level
        let laid = level.board()
        board = laid.board
        noGuess = laid.noGuess
    }

    func elapsed() -> TimeInterval {
        guard let startInstant else { return 0 }
        let end = endInstant ?? .now
        let parts = startInstant.duration(to: end).components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    /// Opens the start cell without starting the clock, so a daily board
    /// and a random board both begin with an open area and nothing else.
    func openStart() {
        guard status == .ready, board.openCount == 0 else { return }
        board.dig(board.start)
    }

    /// A tap: dig in dig mode, flag in flag mode. On an open number a tap
    /// chords in either mode.
    func tap(_ index: Int) {
        guard status == .ready || status == .playing else { return }
        if board.cells[index].isOpen {
            apply(board.chord(index), at: index)
            return
        }
        switch mode {
        case .dig: dig(index)
        case .flag: flag(index)
        }
    }

    func dig(_ index: Int) {
        guard status == .ready || status == .playing, !board.cells[index].isOpen, !board.cells[index].isFlagged else { return }
        if !MineSolver.deduce(board).safe.contains(where: { $0.cell == index }), hintCell != index {
            // Not provable from the numbers: the player is guessing, or
            // sees something the two solver rules do not.
            guesses += 1
        }
        hintCell = nil
        apply(board.dig(index), at: index)
    }

    func flag(_ index: Int) {
        guard status == .ready || status == .playing else { return }
        board.toggleFlag(index)
        flagToken += 1
        if status == .ready { begin() }
    }

    /// The solver's safest next dig. When nothing is provable, the hint
    /// says so instead of guessing for the player.
    func revealHint() -> Bool {
        guard status == .ready || status == .playing else { return false }
        let safe = MineSolver.deduce(board).safe
        guard let first = safe.first else { return false }
        hintCell = first.cell
        hintUsed = true
        return true
    }

    /// One line for the loss card, from the same solver that powers hints.
    var lossReason: String {
        guard let exploded, status == .lost else { return "" }
        var before = board
        before.close(exploded)
        // Mines revealed by the loss must not count as open numbers.
        for index in 0..<before.count where before.cells[index].isMine && index != exploded {
            before.close(index)
        }
        let proof = MineSolver.deduce(before)
        if let d = proof.mines.first(where: { $0.cell == exploded }) {
            return "The \(before.cells[d.from].adjacent) at row \(before.row(d.from) + 1), column \(before.column(d.from) + 1) already proved that cell was a mine."
        }
        if proof.safe.isEmpty {
            return "Nothing on the board proved a safe cell. That was a forced guess, not a mistake."
        }
        return "That cell was unproven while \(proof.safe.count) safe \(proof.safe.count == 1 ? "cell was" : "cells were") still open to you."
    }

    private func apply(_ result: MineBoard.DigResult, at index: Int) {
        switch result {
        case .nothing:
            return
        case .opened:
            if status == .ready { begin() }
            digToken += 1
            if board.isCleared {
                status = .won
                endInstant = .now
            }
        case .mine:
            if status == .ready { begin() }
            exploded = index
            status = .lost
            endInstant = .now
            board.revealMines()
        }
    }

    private func begin() {
        status = .playing
        startInstant = .now
    }
}
