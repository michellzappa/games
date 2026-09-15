import GameShell
import SwiftUI

struct DIGPlayStyleView: View {
    @Environment(\.dismiss) private var dismiss
    private let stats = DIGStats.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    let s = stats.snapshot
                    ForEach(MineSize.allCases) { size in
                        let r = stats.record(for: size)
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(size.name).font(.subheadline.weight(.semibold))
                                Text(size.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(r.bestSeconds.map(TimeFormat.clock) ?? "—")
                                    .font(.title3.weight(.semibold)).monospacedDigit()
                                Text(r.played == 0 ? "not played" : "\(r.won) of \(r.played) cleared")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .glassPanel(cornerRadius: 14)
                    }
                    HStack(spacing: 10) {
                        metric("Guesses", "\(s.guesses)")
                        metric("Hints", "\(s.hints)")
                    }
                    HStack(spacing: 10) {
                        metric("Losses, provable", "\(s.lossesProven)")
                        metric("Losses, forced", "\(s.lossesForced)")
                    }
                    metric("Best daily streak", "\(s.dailyBestStreak)")
                    TutorialText.paragraph(advice)
                }
                .padding(24)
            }
            .background(Appearance.shared.gameBackground)
            .navigationTitle("Play style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private var advice: String {
        let s = stats.snapshot
        let played = MineSize.allCases.reduce(0) { $0 + stats.record(for: $1).played }
        if played == 0 { return "Clear a few boards and this screen starts to say something." }
        if s.lossesProven > s.lossesForced && s.lossesProven > 2 {
            return "Most of your losses were provable. Before a risky dig, press Hint: if it finds a safe cell, the numbers already knew."
        }
        if s.guesses > played * 2 {
            return "You guess often. Look for a number whose closed neighbors equal its count; those cells are mines, and flagging them opens the rest."
        }
        return "You play by the numbers. The clock is the only thing left to beat."
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassPanel(cornerRadius: 14)
    }
}
