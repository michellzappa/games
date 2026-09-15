import Foundation

/// What the numbers already prove. Two rules, applied until nothing
/// changes: a number whose hidden neighbors equal its remaining mines
/// makes them all mines; a number whose remaining mines are zero makes
/// them all safe; and when one number's hidden set contains another's, the
/// difference is decided by the difference in counts. This is enough to
/// solve most boards without guessing and to explain a loss.
struct MineSolver {
    struct Deduction: Equatable {
        /// The open cell whose number proves it.
        let from: Int
        let cell: Int
        let isMine: Bool
    }

    struct Result: Equatable {
        var safe: [Deduction] = []
        var mines: [Deduction] = []

        var isEmpty: Bool { safe.isEmpty && mines.isEmpty }
    }

    /// Everything provable from the current open cells. Flags are ignored;
    /// the solver trusts only numbers, so a wrong flag cannot mislead it.
    static func deduce(_ board: MineBoard) -> Result {
        var known: [Int: Bool] = [:]   // cell -> isMine, as proven so far
        var result = Result()

        struct Constraint {
            let from: Int
            var hidden: Set<Int>
            var mines: Int
        }

        func constraints() -> [Constraint] {
            var list: [Constraint] = []
            for index in 0..<board.count where board.cells[index].isOpen && !board.cells[index].isMine {
                let around = board.neighbors(of: index)
                var hidden = Set(around.filter { !board.cells[$0].isOpen })
                var mines = board.cells[index].adjacent
                for cell in hidden {
                    if let isMine = known[cell] {
                        hidden.remove(cell)
                        if isMine { mines -= 1 }
                    }
                }
                if !hidden.isEmpty {
                    list.append(Constraint(from: index, hidden: hidden, mines: mines))
                }
            }
            return list
        }

        func learn(_ cell: Int, isMine: Bool, from: Int) -> Bool {
            guard known[cell] == nil else { return false }
            known[cell] = isMine
            let deduction = Deduction(from: from, cell: cell, isMine: isMine)
            if isMine { result.mines.append(deduction) } else { result.safe.append(deduction) }
            return true
        }

        var changed = true
        while changed {
            changed = false
            let list = constraints()
            for constraint in list {
                if constraint.mines == 0 {
                    for cell in constraint.hidden where learn(cell, isMine: false, from: constraint.from) { changed = true }
                } else if constraint.mines == constraint.hidden.count {
                    for cell in constraint.hidden where learn(cell, isMine: true, from: constraint.from) { changed = true }
                }
            }
            if changed { continue }
            // Subset rule: A ⊂ B means B \ A holds (B.mines - A.mines) mines.
            for a in list {
                for b in list where a.from != b.from && a.hidden.isStrictSubset(of: b.hidden) {
                    let rest = b.hidden.subtracting(a.hidden)
                    let mines = b.mines - a.mines
                    if mines == 0 {
                        for cell in rest where learn(cell, isMine: false, from: b.from) { changed = true }
                    } else if mines == rest.count {
                        for cell in rest where learn(cell, isMine: true, from: b.from) { changed = true }
                    }
                }
            }
        }
        return result
    }

    /// True when digging only proven-safe cells from the start clears the
    /// board. Used to pick boards that never need a guess.
    static func isSolvableWithoutGuessing(_ start: MineBoard) -> Bool {
        var board = start
        board.dig(board.start)
        while !board.isCleared {
            let safe = deduce(board).safe
            guard !safe.isEmpty else { return false }
            for deduction in safe { board.dig(deduction.cell) }
        }
        return true
    }
}
