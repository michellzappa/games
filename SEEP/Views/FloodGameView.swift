import GameShell
import SwiftUI

/// One round: chrome row, move counter, board, color bar, undo and hint,
/// and the win or loss card over the board when it ends.
struct FloodGameView: View {
    let level: FloodLevel
    let onExit: () -> Void
    /// The next level in the pack, when there is one, so the win card can
    /// go straight on.
    var onNext: (() -> Void)?

    @State private var game: FloodGame
    @State private var showExitConfirm = false
    @State private var recorded = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @Environment(\.estReduceMotion) private var reduceMotion

    init(level: FloodLevel, onExit: @escaping () -> Void, onNext: (() -> Void)? = nil) {
        self.level = level
        self.onExit = onExit
        self.onNext = onNext
        _game = State(initialValue: FloodGame(level: level))
    }

    var body: some View {
        VStack(spacing: 16) {
            chrome
            counter
            FloodBoardView(board: game.board, onTapColor: select)
                .padding(.horizontal, 20)
                .allowsHitTesting(game.status == .playing)
            FloodColorBar(board: game.board, hintColor: game.hintColor, enabled: game.status == .playing, onSelect: select)
            controls
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Appearance.shared.gameBackground)
        .overlay {
            if game.status != .playing {
                endCard
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: FeedbackTrigger(value: game.moveToken, enabled: hapticsEnabled))
        .onChange(of: game.moveToken) { _, _ in
            GameAudio.shared.play(.deal)
        }
        .onChange(of: game.status) { _, status in
            guard status != .playing, !recorded else { return }
            recorded = true
            if status == .won {
                GameAudio.shared.play(.completion)
                SEEPEvent.gameCompleted.record()
                if case .pack = level.kind { SEEPEvent.levelCompleted.record() }
            } else {
                GameAudio.shared.play(.mismatch)
            }
            if let pack = SEEPStats.shared.record(game),
               let score = SEEPLeaderboard.score(for: pack, store: SEEPStats.shared.levels, hinted: SEEPStats.shared.hinted(pack)) {
                _ = GameCenterManager.shared.submit(score)
            }
        }
        .onAppear {
            SEEPEvent.gameStarted.record()
        }
        .confirmationDialog("Leave this board?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive, action: onExit)
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Your moves on this board are lost.")
        }
    }

    private var chrome: some View {
        HStack {
            GameExitButton(accessibilityLabel: "Leave board") {
                if game.moves == 0 || game.status != .playing {
                    onExit()
                } else {
                    showExitConfirm = true
                }
            }
            Spacer()
            Text(level.title)
                .font(.headline)
            Spacer()
            Button {
                game.restart()
                recorded = false
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
            }
            .buttonStyle(.game(.quiet, tint: .second, size: .icon))
            .accessibilityLabel("Restart board")
        }
        .padding(.horizontal, 20)
    }

    private var counter: some View {
        VStack(spacing: 2) {
            Text("\(game.moves) of \(game.limit)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .spring(duration: 0.3), value: game.moves)
            Text("par \(game.par)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(game.moves) of \(game.limit) moves, par \(game.par)")
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                game.undo()
                SEEPEvent.undoUsed.record()
                recorded = false
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.game(.secondary, tint: .second, size: .medium))
            .disabled(!game.canUndo)

            Button {
                game.revealHint()
                SEEPEvent.hintUsed.record()
                GameAudio.shared.play(.hint)
            } label: {
                Label("Hint", systemImage: "lightbulb")
            }
            .buttonStyle(.game(.secondary, tint: .third, size: .medium))
            .disabled(game.status != .playing || game.hintColor != nil)
        }
        .padding(.horizontal, 20)
    }

    private func select(_ color: Int) {
        game.select(color: color)
    }

    private var endCard: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            if game.status == .won {
                ConfettiView(colors: (0..<game.board.colorCount).map(FloodPalette.color))
                    .ignoresSafeArea()
            }
            VStack(spacing: 18) {
                if game.status == .won {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < game.stars ? "star.fill" : "star")
                                .font(.title)
                                .foregroundStyle(index < game.stars ? GameAccent.third.color : .secondary)
                        }
                    }
                    Text(game.moves <= game.par ? "Under par" : "Flooded")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    Text("\(game.moves) moves, par \(game.par)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if game.hintUsed {
                        Text("Hinted rounds keep their stars but stay off the leaderboard.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Out of moves")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    Text(game.lossReason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    if game.status == .won, let onNext {
                        Button("Next board", action: onNext)
                            .buttonStyle(.game(.primary, tint: .second, size: .large))
                    } else if game.status == .lost {
                        Button("Undo last move") {
                            game.undo()
                            recorded = false
                        }
                        .buttonStyle(.game(.primary, tint: .second, size: .large))
                    }
                    Button("Play again") {
                        game.restart()
                        recorded = false
                    }
                    .buttonStyle(.game(.secondary, tint: .second, size: .large))
                    Button("Back", action: onExit)
                        .buttonStyle(.game(.quiet, size: .large))
                }
            }
            .padding(24)
            .frame(maxWidth: 360)
            .glassPanel(cornerRadius: 24)
            .padding(24)
        }
        .transition(.opacity)
    }
}
