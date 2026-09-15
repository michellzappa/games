import GameShell
import SwiftUI

struct DIGTitleView: View {
    let onPlay: (MineLevel) -> Void
    let onLeaderboards: () -> Void
    let onSettings: () -> Void
    let onHowToPlay: () -> Void

    @State private var showExplainer = false
    @State private var showPlayStyle = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let stats = DIGStats.shared

    private var today: MineLevel { .daily() }

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
        .sheet(isPresented: $showExplainer) { MineExplainerView() }
        .sheet(isPresented: $showPlayStyle) { DIGPlayStyleView() }
    }

    private var content: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)
            Text("DIG")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .tracking(8)
            Text("Every number is a clue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(1...3, id: \.self) { n in
                    Text("\(n)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(MinePalette.number(n))
                        .frame(width: 56, height: 56)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                Image(systemName: "flag.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(GameAccent.first.color)
                    .frame(width: 56, height: 56)
                    .background(Appearance.shared.theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityHidden(true)

            Spacer(minLength: 12)

            VStack(spacing: 12) {
                ForEach(MineSize.allCases) { size in
                    Button {
                        onPlay(.random(size))
                    } label: {
                        HStack {
                            Label(size.name, systemImage: size == .patch ? "square.grid.3x3" : size == .field ? "square.grid.4x3.fill" : "rectangle.grid.3x2.fill")
                            Spacer()
                            if let best = stats.record(for: size).bestSeconds {
                                Text(TimeFormat.clock(best))
                                    .font(.footnote.weight(.semibold))
                                    .monospacedDigit()
                                    .opacity(0.8)
                            }
                        }
                    }
                    .buttonStyle(.game(size == .patch ? .primary : .secondary, tint: size == .field ? .third : .second, size: .large))
                    .accessibilityLabel("\(size.name), \(size.subtitle)")
                }

                Button {
                    onPlay(today)
                } label: {
                    Label(dailyDone ? "Daily done, play again" : "Today's board", systemImage: "calendar")
                }
                .buttonStyle(.game(.secondary, tint: .first, size: .large))

                if stats.snapshot.dailyStreak > 0 {
                    Text("Daily streak: \(stats.snapshot.dailyStreak)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(action: onHowToPlay) { Label("How to play", systemImage: "questionmark.circle") }
                Button { showExplainer = true } label: { Label("The idea", systemImage: "function") }
                Button { showPlayStyle = true } label: { Label("Play style", systemImage: "chart.bar.xaxis") }
            }
            .buttonStyle(.game(.quiet, size: .compact))

            HStack(spacing: 10) {
                Button(action: onLeaderboards) { Label("Leaderboards", systemImage: "trophy") }
                Button(action: onSettings) { Label("Settings", systemImage: "gearshape") }
            }
            .buttonStyle(.game(.quiet, size: .compact))
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
