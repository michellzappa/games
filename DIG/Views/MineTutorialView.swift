import GameShell
import SwiftUI

/// The guided first play: the goal, what a number means, flags, one
/// worked deduction, then a practice board the learner clears. Every board
/// is 6 by 6 with four mines, on every step.
struct MineTutorialView: View {
    let onFinish: () -> Void

    @State private var step = 0
    @State private var practice = MineTutorialView.freshPractice()

    private static let stepCount = 5
    private static let demoSeed: UInt64 = 90_210

    private static func freshPractice() -> MineGame {
        let game = MineGame(level: .practice())
        game.openStart()
        return game
    }

    /// A fixed, solvable 6 by 6 with its start opened, for the worked steps.
    private static func demoBoard() -> MineBoard {
        var board = MineLevel.practice(seed: demoSeed).board().board
        board.dig(board.start)
        return board
    }

    var body: some View {
        TutorialFrame(
            stepCount: Self.stepCount,
            step: $step,
            canAdvance: step != 4 || practice.status == .won,
            blockedHint: "Clear the board to continue, or use a hint.",
            onFinish: onFinish
        ) {
            VStack(alignment: .leading, spacing: 18) {
                switch step {
                case 0: goalStep
                case 1: numbersStep
                case 2: flagsStep
                case 3: deductionStep
                default: practiceStep
                }
            }
        } extra: {
            if step == 4 {
                Button {
                    _ = practice.revealHint()
                } label: {
                    Label("Hint", systemImage: "lightbulb")
                }
                .buttonStyle(.game(.secondary, tint: .third, size: .large))
                .disabled(practice.status == .won || practice.status == .lost)
            }
        }
    }

    private var goalStep: some View {
        Group {
            TutorialText.heading("Open every safe cell", "Some cells hide a mine. Open all the others and the board is cleared.")
            board(Self.demoBoard())
            TutorialText.paragraph("The first cell is open for you and it is always a zero, so the board starts with an open area. Tap a closed cell to dig it. Dig a mine and the round ends.")
        }
    }

    private var numbersStep: some View {
        Group {
            TutorialText.heading("A number counts mines", "Each open number says how many of its eight neighbors are mines.")
            board(Self.demoBoard())
            TutorialText.ruleRow("0.circle", "Zero", "No mine touches it, so its neighbors open on their own.")
            TutorialText.ruleRow("1.circle", "One", "Exactly one of the closed cells around it is a mine.")
            TutorialText.ruleRow("questionmark.circle", "Closed", "Unknown until a number proves it, or you take a risk.")
        }
    }

    private var flagsStep: some View {
        Group {
            TutorialText.heading("Flags", "Hold a cell to flag it as a mine. Flags are notes, not proof.")
            TutorialText.ruleRow("flag.fill", "Mark what you know", "The mine counter goes down by one for each flag.")
            TutorialText.ruleRow("hand.tap", "Tap a number", "When the flags around a number match it, tapping the number opens the rest. A wrong flag makes that dig hit a mine.")
            TutorialText.ruleRow("hand.tap.fill", "Flag mode", "The switch beside the clock makes every tap a flag, for one-handed play.")
        }
    }

    private var deductionStep: some View {
        let demo = Self.demoBoard()
        let proof = MineSolver.deduce(demo)
        return Group {
            TutorialText.heading("One deduction", "A number with as many closed neighbors as mines makes them all mines. A number with all its mines flagged makes the rest safe.")
            board(demo, hint: proof.safe.first?.cell)
            if let safe = proof.safe.first {
                TutorialText.paragraph("The \(demo.cells[safe.from].adjacent) at row \(demo.row(safe.from) + 1), column \(demo.column(safe.from) + 1) already has its mines accounted for, so the outlined cell is safe.")
            }
            if let mine = proof.mines.first {
                TutorialText.paragraph("The \(demo.cells[mine.from].adjacent) at row \(demo.row(mine.from) + 1), column \(demo.column(mine.from) + 1) has exactly that many closed neighbors, so row \(demo.row(mine.cell) + 1), column \(demo.column(mine.cell) + 1) is a mine.")
            }
            TutorialText.paragraph("That is the whole game: every move is a number proving a cell. When nothing proves anything, a hint says so, and the only move left is a guess.")
        }
    }

    private var practiceStep: some View {
        Group {
            TutorialText.heading("Your turn", "Clear this board. Tap to dig, hold to flag.")
            HStack {
                Label("\(practice.board.remainingMines)", systemImage: "flag.fill")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Spacer()
                Text(practice.status == .won ? "Cleared" : practice.status == .lost ? "Mine" : "")
                    .font(.headline)
            }
            MineBoardView(
                board: practice.board,
                exploded: practice.exploded,
                hintCell: practice.hintCell,
                onTap: { practice.tap($0) },
                onLongPress: { practice.flag($0) }
            )
            .frame(width: 216, height: 216)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(practice.status == .ready || practice.status == .playing)
            if practice.status == .lost {
                Text(practice.lossReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                withAnimation(.spring(duration: 0.4)) { practice = Self.freshPractice() }
            } label: {
                Label("New board", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.game(.quiet, size: .inline))
        }
    }

    private func board(_ board: MineBoard, hint: Int? = nil) -> some View {
        MineBoardView(board: board, hintCell: hint)
            .frame(width: 216, height: 216)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
    }
}
