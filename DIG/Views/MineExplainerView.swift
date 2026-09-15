import GameShell
import SwiftUI

/// The idea behind DIG: every number is a constraint, and two rules decide
/// most boards. Where the rules run out, only probability is left, and
/// that is what a guess is.
struct MineExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var board = MineExplainerView.sample()
    @State private var shown = 0

    private static func sample() -> MineBoard {
        var board = MineLevel.practice(seed: 31_337).board().board
        board.dig(board.start)
        return board
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("01 / constraints", "Every number is an equation") {
                        TutorialText.paragraph("A 2 with three closed neighbors says: of these three cells, exactly two are mines. The board is a system of such equations, one per open number, and solving it is the game.")
                        let proof = MineSolver.deduce(board)
                        MineBoardView(board: board, hintCell: proof.safe.indices.contains(shown) ? proof.safe[shown].cell : nil)
                            .frame(width: 216, height: 216)
                            .frame(maxWidth: .infinity)
                            .allowsHitTesting(false)
                        Text("\(proof.safe.count) safe cells and \(proof.mines.count) mines are provable right now.")
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 12) {
                            Button("Next proof") { shown = proof.safe.isEmpty ? 0 : (shown + 1) % proof.safe.count }
                                .buttonStyle(.game(.secondary, tint: .second, size: .inline))
                            Button {
                                withAnimation { apply(proof) }
                            } label: {
                                Label("Apply them", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.game(.secondary, tint: .third, size: .inline))
                            .disabled(proof.isEmpty)
                        }
                    }

                    section("02 / two rules", "What the hint knows") {
                        TutorialText.ruleRow("equal", "Saturation", "Closed neighbors equal remaining mines: all of them are mines. Remaining mines are zero: all of them are safe.")
                        TutorialText.ruleRow("rectangle.on.rectangle", "Subset", "If one number's closed cells sit inside another's, the difference in cells holds the difference in mines. This is the 1-2-1 and 1-1 pattern, stated once.")
                        TutorialText.paragraph("The hint and the loss card use exactly these two rules, so when the hint says nothing is provable, that is the same claim.")
                    }

                    section("03 / guessing", "Where logic ends") {
                        TutorialText.paragraph("Some boards reach a state where no rule applies and the mine could be in any of two cells. No skill resolves it; only a coin does. DIG lays Patch and Field boards that the two rules clear from the start, so a guess there is always your choice. Quarry boards are too dense to verify, and the title says so.")
                        Button {
                            board = Self.sample()
                            shown = 0
                        } label: {
                            Label("Reset the board", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.game(.quiet, size: .inline))
                    }
                }
                .padding(24)
            }
            .background(Appearance.shared.gameBackground)
            .navigationTitle("The idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func apply(_ proof: MineSolver.Result) {
        for deduction in proof.safe { board.dig(deduction.cell) }
        for deduction in proof.mines where !board.cells[deduction.cell].isFlagged { board.toggleFlag(deduction.cell) }
        shown = 0
    }

    private func section<Content: View>(_ eyebrow: String, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassPanel(cornerRadius: 20)
    }
}
