import SwiftUI

/// One leaderboard a game exposes: its Game Center id, how the sheet names
/// it, and the player's local best as display text (nil when none).
public struct LeaderboardBoard: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let personalBest: String?

    public init(id: String, title: String, description: String, personalBest: String?) {
        self.id = id
        self.title = title
        self.description = description
        self.personalBest = personalBest
    }
}

/// The leaderboards sheet. A game passes its boards; the sheet shows one at
/// a time with the local best and a button into Game Center. Two or more
/// boards get a segmented picker, one board gets none.
public struct LeaderboardView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var trophySize: CGFloat = 42
    @ScaledMetric(relativeTo: .largeTitle) private var bestTimeSize: CGFloat = 36

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String

    private let boards: [LeaderboardBoard]
    private let onOpen: (LeaderboardBoard) -> Void

    /// `onOpen` runs before Game Center opens, so a game can record the view.
    public init(boards: [LeaderboardBoard], onOpen: @escaping (LeaderboardBoard) -> Void = { _ in }) {
        precondition(!boards.isEmpty, "LeaderboardView needs at least one board")
        self.boards = boards
        self.onOpen = onOpen
        _selectedID = State(initialValue: boards[0].id)
    }

    private var selected: LeaderboardBoard {
        boards.first { $0.id == selectedID } ?? boards[0]
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if boards.count > 1 {
                    Picker("Leaderboard", selection: $selectedID) {
                        ForEach(boards) { board in
                            Text(board.title).tag(board.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: trophySize))
                        .foregroundStyle(GameAccent.third.color)

                    Text(selected.title)
                        .font(.title2.weight(.bold))

                    Text(selected.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let personalBest = selected.personalBest {
                        VStack(spacing: 2) {
                            Text("Personal best")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(personalBest)
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
                        onOpen(selected)
                        GameCenterManager.shared.showLeaderboard(id: selected.id)
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
