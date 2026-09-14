import SwiftUI

struct LeaderboardView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var trophySize: CGFloat = 42
    @ScaledMetric(relativeTo: .largeTitle) private var bestTimeSize: CGFloat = 36

    private enum Tab: String, CaseIterable, Identifiable, Hashable {
        case solo
        case quick

        var id: String { rawValue }

        var title: String {
            switch self {
            case .solo: "Solo 81"
            case .quick: "Quick 27"
            }
        }

        var variant: GameEngine.Variant {
            switch self {
            case .solo: .full
            case .quick: .quick
            }
        }

        var description: String {
            switch self {
            case .solo: "Clear all 81 cards against the clock."
            case .quick: "Clear the 27 solid cards in a shorter round."
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Tab = .solo
    @AppStorage("bestSoloTime") private var bestSoloTime: Double = 0
    @AppStorage("bestQuickTime") private var bestQuickTime: Double = 0

    private var personalBest: Double {
        switch selectedTab {
        case .solo: bestSoloTime
        case .quick: bestQuickTime
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Leaderboard", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: trophySize))
                        .foregroundStyle(GameAccent.third.color)

                    Text(selectedTab.title)
                        .font(.title2.weight(.bold))

                    Text(selectedTab.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if personalBest > 0 {
                        VStack(spacing: 2) {
                            Text("Personal best")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(TimeFormat.clock(personalBest))
                                .font(.system(size: bestTimeSize, weight: .black, design: .rounded))
                                .monospacedDigit()
                        }
                        .padding(.top, 8)
                    } else {
                        Text("No personal best yet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassPanel(cornerRadius: 20)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        ESTTelemetry.record(.leaderboardViewed)
                        GameCenterManager.shared.showLeaderboard(
                            id: ESTLeaderboard.leaderboardID(for: selectedTab.variant)
                        )
                    } label: {
                        Label("Open Game Center leaderboard", systemImage: "trophy")
                    }
                    .buttonStyle(.game(.primary, tint: .third, size: .large))
                    .disabled(!GameCenterManager.shared.isAuthenticated)

                    if !GameCenterManager.shared.isAuthenticated {
                        Text("Sign in to Game Center to view rankings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .background(Appearance.shared.gameBackground)
            .navigationTitle("Leaderboards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
