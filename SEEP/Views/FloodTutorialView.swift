import GameShell
import SwiftUI

/// The guided first play: the goal, one move, par and stars, a worked
/// failure, then a practice board the learner floods to continue. Every
/// board is 6 by 6 with three colors, on every step, so a board reads as
/// the same thing throughout.
struct FloodTutorialView: View {
    let onFinish: () -> Void

    @State private var step = 0
    @State private var demo = FloodTutorialView.demoLevel().board()
    @State private var demoMoves = 0
    @State private var practice = FloodGame(level: .practice())

    private static let stepCount = 5

    private static func demoLevel() -> FloodLevel {
        FloodLevel(kind: .practice, size: 6, colorCount: 3, seed: 1_804_289_383)
    }

    var body: some View {
        TutorialFrame(
            stepCount: Self.stepCount,
            step: $step,
            canAdvance: step != 4 || practice.status == .won,
            blockedHint: "Flood the board to continue, or use a hint.",
            onFinish: onFinish
        ) {
            content
        } extra: {
            if step == 4 {
                Button {
                    practice.revealHint()
                } label: {
                    Label("Hint", systemImage: "lightbulb")
                }
                .buttonStyle(.game(.secondary, tint: .third, size: .large))
                .disabled(practice.status != .playing)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch step {
            case 0: goalStep
            case 1: moveStep
            case 2: parStep
            case 3: failureStep
            default: practiceStep
            }
        }
    }

    private var goalStep: some View {
        Group {
            TutorialText.heading("One color", "Make the whole board one color in as few moves as you can.")
            board(demo, highlight: false)
            TutorialText.paragraph("The flood starts in the top-left corner. Every move recolors the region that touches that corner, and the region grows into every neighbor of the new color.")
        }
    }

    private var moveStep: some View {
        Group {
            TutorialText.heading("One move", "Tap a color. The outlined region takes it and grows.")
            board(demo, highlight: true)
            FloodColorBar(board: demo, onSelect: { color in
                if demo.flood(to: color) { demoMoves += 1 }
            })
            .frame(maxWidth: .infinity)
            TutorialText.paragraph(demoMoves == 0
                ? "The outline is the region you own. Pick the color with the most cells touching it."
                : "Move \(demoMoves). The region now owns \(demo.regionSize) of \(demo.size * demo.size) cells.")
            Button {
                withAnimation(.spring(duration: 0.4)) {
                    demo = Self.demoLevel().board()
                    demoMoves = 0
                }
            } label: {
                Label("Reset board", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.game(.quiet, size: .inline))
        }
    }

    private var parStep: some View {
        Group {
            TutorialText.heading("Par and stars", "Every board has a par and a move limit.")
            TutorialText.ruleRow("flag.checkered", "Par", "The moves a steady player needs. Finish at or under par for three stars.")
            TutorialText.ruleRow("star.fill", "Stars", "Three at par, two at one over, one for any finish.")
            TutorialText.ruleRow("xmark.octagon", "Limit", "Par plus three. Run out of moves and the board is lost. Undo takes a move back.")
            TutorialText.ruleRow("lightbulb", "Hints", "A hint shows the strongest next color. A hinted board keeps its stars but stays off the leaderboard.")
        }
    }

    private var failureStep: some View {
        let options = (0..<demo.colorCount).filter { $0 != demo.floodColor }
        let sizes = options.map { ($0, demo.regionSize(afterFloodTo: $0)) }
        let best = sizes.max { $0.1 < $1.1 }
        return Group {
            TutorialText.heading("Why a move fails", "Two colors, two futures.")
            board(Self.demoLevel().board(), highlight: true)
            ForEach(sizes, id: \.0) { color, size in
                HStack(spacing: 12) {
                    Circle().fill(FloodPalette.color(color)).frame(width: 22, height: 22)
                    Text("Flood \(FloodPalette.name(color)): the region grows to \(size) cells")
                        .font(.subheadline)
                    Spacer()
                    if color == best?.0 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(GameAccent.second.color)
                    }
                }
            }
            TutorialText.paragraph("A move that grows the region less leaves more work for later. Over a whole board that is the difference between par and running out.")
        }
    }

    private var practiceStep: some View {
        Group {
            TutorialText.heading("Your turn", "Flood this board in \(practice.limit) moves or fewer.")
            HStack {
                Text("\(practice.moves) of \(practice.limit)")
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .monospacedDigit()
                Spacer()
                Text("par \(practice.par)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            board(practice.board, highlight: true) { color in
                practice.select(color: color)
            }
            FloodColorBar(board: practice.board, hintColor: practice.hintColor, enabled: practice.status == .playing) { color in
                practice.select(color: color)
            }
            .frame(maxWidth: .infinity)
            if practice.status == .won {
                Text(practice.moves <= practice.par ? "Under par. Three stars." : "Flooded in \(practice.moves).")
                    .font(.subheadline.weight(.semibold))
            } else if practice.status == .lost {
                Text(practice.lossReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("Undo") { practice.undo() }
                    .buttonStyle(.game(.quiet, size: .inline))
                    .disabled(!practice.canUndo)
                Button {
                    withAnimation(.spring(duration: 0.4)) { practice = FloodGame(level: .practice()) }
                } label: {
                    Label("New board", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.game(.quiet, size: .inline))
            }
        }
    }

    private func board(_ board: FloodBoard, highlight: Bool, onTap: ((Int) -> Void)? = nil) -> some View {
        FloodBoardView(board: board, highlightRegion: highlight, onTapColor: onTap)
            .frame(width: 216, height: 216)
            .frame(maxWidth: .infinity)
    }
}
