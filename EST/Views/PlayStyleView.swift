import GameShell
import SwiftUI

struct PlayStyleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stats = PlayerStats.shared
    @State private var showResetConfirmation = false
    @AppStorage("bestSoloTime") private var bestSoloTime: Double = 0
    @AppStorage("bestQuickTime") private var bestQuickTime: Double = 0

    private let traitNames = ["number", "color", "shape", "fill"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro

                    if stats.attempts == 0 {
                        emptyState
                    } else {
                        overview
                        complexitySection
                        traitSection
                        boardSection
                        learningTip
                    }

                    Button("Reset learning stats", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.game(.quiet, tint: .first, size: .compact))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Appearance.shared.gameBackground)
            .navigationTitle("Your play style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Reset learning stats?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset stats", role: .destructive) { stats.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This only removes the private stats stored on this device.")
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("A private practice mirror", systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(GameAccent.second.color)
            Text("These aggregate stats stay on this device and are never included in anonymous diagnostics.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassPanel(cornerRadius: 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(GameAccent.third.color)
            Text("Play a few solo rounds")
                .font(.headline)
            Text("EST will show which kinds of sets feel natural to you and where a little practice could help.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .glassPanel(cornerRadius: 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("At a glance")
                .font(.headline)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                metric("Sets", value: "\(stats.correctSets)", tint: .blue)
                metric("Accuracy", value: percentage(stats.accuracy), tint: .yellow)
                metric("Rounds", value: "\(stats.completedSoloRounds)", tint: .red)
            }

            // Personal bests live here too. They were only visible on the
            // leaderboard sheet, which needs Game Center to be useful.
            if bestSoloTime > 0 || bestQuickTime > 0 {
                Divider()
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    metric(
                        "Best 81",
                        value: bestSoloTime > 0 ? TimeFormat.clock(bestSoloTime) : "—",
                        tint: .red
                    )
                    metric(
                        "Best 27",
                        value: bestQuickTime > 0 ? TimeFormat.clock(bestQuickTime) : "—",
                        tint: .blue
                    )
                }
            }
        }
        .sectionSurface()
    }

    private var complexitySection: some View {
        let counts = stats.correctByDifference
        let maximum = max(1, counts.dropFirst().max() ?? 0)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Set complexity")
                .font(.headline)
            Text("A set has 1–4 differing traits. This is a pattern profile, not a score: a four-difference set is not always harder.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(Array(1...4), id: \.self) { difference in
                HStack(spacing: 10) {
                    Text("\(difference)")
                        .font(.subheadline.monospacedDigit().bold())
                        .frame(width: 18, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.secondary.opacity(0.10))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(complexityTint(difference).gradient)
                                    .frame(width: proxy.size.width * CGFloat(counts[difference]) / CGFloat(maximum))
                            }
                    }
                    .frame(height: 12)
                    Text("\(counts[difference])")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                    if let average = stats.averageTime(for: difference) {
                        Text(TimeFormat.shortSeconds(average))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    } else {
                        Text("—")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(difference) differing traits, \(counts[difference]) sets")
            }

            Text("Bars show sets found; the time at right is your average time since the previous match.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sectionSurface()
    }

    private var traitSection: some View {
        let errors = stats.mismatchesByTrait
        let totalErrors = errors.reduce(0, +)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Where misses happen")
                .font(.headline)
            if totalErrors == 0 {
                Text("No mismatches yet. Keep checking each trait before committing to a set.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(traitNames.enumerated()), id: \.offset) { index, trait in
                    HStack {
                        Text(trait.capitalized)
                        Spacer()
                        Text("\(errors[index])")
                            .font(.subheadline.monospacedDigit().bold())
                            .foregroundStyle(errors[index] == errors.max() ? GameAccent.first.color : .secondary)
                    }
                    .font(.subheadline)
                }
                if stats.nearMisses > 0 {
                    Text("\(stats.nearMisses) of your misses were one-trait near misses—use those as your best practice clues.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sectionSurface()
    }

    private var boardSection: some View {
        let buckets = stats.boardSetBuckets
        let labels = ["No set", "1 set", "2 sets", "3+ sets"]
        let mostCommon = buckets.indices.max { buckets[$0] < buckets[$1] }

        return VStack(alignment: .leading, spacing: 8) {
            Text("Your search conditions")
                .font(.headline)
            if let mostCommon, buckets[mostCommon] > 0 {
                Text("Most of your attempts happen when the board has \(labels[mostCommon].lowercased()) available.")
                    .font(.subheadline)
            }
            Text("Boards with many sets offer choice; sparse boards reward the two-card completion habit.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .sectionSurface()
    }

    private var learningTip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("A useful next habit", systemImage: "lightbulb")
                .font(.headline)
                .foregroundStyle(GameAccent.third.color)
            Text(tipText)
                .font(.subheadline)
        }
        .padding(16)
        .glassButtonSurface(
            tint: GameAccent.third.color,
            opacity: 0.10,
            cornerRadius: 18
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tipText: String {
        if stats.correctSets < 5 {
            return "Say the four traits out loud for a few sets. The pattern becomes easier to see when you inspect one trait at a time."
        }
        if let index = stats.mismatchesByTrait.indices.max(by: {
            stats.mismatchesByTrait[$0] < stats.mismatchesByTrait[$1]
        }), stats.mismatchesByTrait[index] > 0 {
            return "Your most common check is \(traitNames[index]). Before tapping, ask: are these three values all the same or all different?"
        }
        return "Choose any two cards, mentally calculate the only card that can complete them, then look for that card on the board."
    }

    private func metric(_ title: String, value: String, tint: Card.Tint) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.monospacedDigit().bold())
                .foregroundStyle(tint.color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func percentage(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func complexityTint(_ difference: Int) -> Card.Tint {
        Card.Tint.allCases[(difference - 1) % Card.Tint.allCases.count]
    }
}

private extension View {
    func sectionSurface() -> some View {
        padding(16)
            .glassPanel(cornerRadius: 18)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
