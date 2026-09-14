import GameShell
import SwiftUI

/// What the player does well and what they miss, in SEEP's own terms.
struct SEEPPlayStyleView: View {
    @Environment(\.dismiss) private var dismiss
    private let stats = SEEPStats.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let s = stats.snapshot
                    HStack(spacing: 10) {
                        metric("Boards flooded", "\(s.roundsWon)")
                        metric("Run out", "\(s.roundsLost)")
                    }
                    HStack(spacing: 10) {
                        metric("Over par, average", String(format: "%.1f", stats.averageOverPar))
                        metric("Best daily streak", "\(s.dailyBestStreak)")
                    }
                    HStack(spacing: 10) {
                        metric("Undos", "\(s.undos)")
                        metric("Hints", "\(s.hints)")
                    }

                    ForEach(FloodPack.allCases) { pack in
                        packRow(pack)
                    }

                    TutorialText.paragraph(advice)
                }
                .padding(24)
            }
            .background(Appearance.shared.gameBackground)
            .navigationTitle("Play style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var advice: String {
        let s = stats.snapshot
        if s.roundsWon == 0 {
            return "Flood a few boards and this screen starts to say something."
        }
        if stats.averageOverPar < 0.5 {
            return "You play at par. The leaderboards reward exactly that."
        }
        if s.undos > s.roundsWon * 3 {
            return "You undo a lot. Before a move, count the cells each color would add; the largest is usually right."
        }
        return "You finish over par. Look two moves ahead: a color that adds few cells now can open a big region next."
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassPanel(cornerRadius: 14)
    }

    private func packRow(_ pack: FloodPack) -> some View {
        let done = stats.levels.completedCount(pack: pack.rawValue, levels: FloodPack.levelCount)
        let stars = (0..<FloodPack.levelCount).reduce(0) { $0 + stats.levels.record(pack: pack.rawValue, index: $1).stars }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.name).font(.subheadline.weight(.semibold))
                Text(pack.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(done)/\(FloodPack.levelCount) · \(stars) stars")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
