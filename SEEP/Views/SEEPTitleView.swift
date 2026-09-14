import GameShell
import SwiftUI

/// The title screen: play the next board, today's board, the packs, and
/// the utility row. A small live board fills itself as the screen sits.
struct SEEPTitleView: View {
    let onPlay: (FloodLevel) -> Void
    let onLevels: () -> Void
    let onLeaderboards: () -> Void
    let onSettings: () -> Void
    let onHowToPlay: () -> Void

    @State private var showExplainer = false
    @State private var showPlayStyle = false
    @State private var demo = FloodLevel(kind: .practice, size: 8, colorCount: 4, seed: 7).board()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.estReduceMotion) private var reduceMotion

    private let stats = SEEPStats.shared

    /// The first unsolved board in the first unfinished pack.
    private var nextLevel: FloodLevel {
        for pack in FloodPack.allCases {
            for index in 0..<FloodPack.levelCount
            where !stats.levels.record(pack: pack.rawValue, index: index).completed {
                return pack.level(index)
            }
        }
        return FloodPack.ocean.level(FloodPack.levelCount - 1)
    }

    private var today: FloodLevel { .daily() }

    private var dailyDone: Bool {
        if case .daily(let day) = today.kind { return stats.dailySolved(day) }
        return false
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { content }
            } else {
                content
            }
        }
        .background(Appearance.shared.gameBackground)
        .sheet(isPresented: $showExplainer) {
            FloodExplainerView()
        }
        .sheet(isPresented: $showPlayStyle) {
            SEEPPlayStyleView()
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.spring(duration: 0.5)) {
                    if demo.isSolved {
                        var generator = SystemRandomNumberGenerator()
                        demo = FloodBoard.generate(size: 8, colorCount: 4, using: &generator)
                    } else {
                        demo.flood(to: demo.greedyMove())
                    }
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            Text("SEEP")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .tracking(6)
            Text("Flood the board. Beat par.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            FloodBoardView(board: demo, highlightRegion: false)
                .frame(width: 140, height: 140)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                Button {
                    onPlay(nextLevel)
                } label: {
                    Label("Play \(nextLevel.title)", systemImage: "play.fill")
                }
                .buttonStyle(.game(.primary, tint: .second, size: .large))

                Button {
                    onPlay(today)
                } label: {
                    Label(dailyDone ? "Daily done, play again" : "Today's board", systemImage: "calendar")
                }
                .buttonStyle(.game(.secondary, tint: .third, size: .large))

                Button(action: onLevels) {
                    Label("All boards", systemImage: "square.grid.3x3")
                }
                .buttonStyle(.game(.secondary, tint: .first, size: .large))

                if stats.snapshot.dailyStreak > 0 {
                    Text("Daily streak: \(stats.snapshot.dailyStreak)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(action: onHowToPlay) {
                    Label("How to play", systemImage: "questionmark.circle")
                }
                Button { showExplainer = true } label: {
                    Label("The idea", systemImage: "function")
                }
                Button { showPlayStyle = true } label: {
                    Label("Play style", systemImage: "chart.bar.xaxis")
                }
            }
            .buttonStyle(.game(.quiet, size: .compact))

            HStack(spacing: 10) {
                Button(action: onLeaderboards) {
                    Label("Leaderboards", systemImage: "trophy")
                }
                Button(action: onSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .buttonStyle(.game(.quiet, size: .compact))
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
