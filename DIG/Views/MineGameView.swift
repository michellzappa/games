import GameShell
import SwiftUI

/// One round: chrome row, the counter row (mines left, clock, mode), the
/// board, undo-less controls (a mine is final), and the end card.
struct MineGameView: View {
    let level: MineLevel
    let onExit: () -> Void
    let onAgain: () -> Void

    @State private var game: MineGame
    @State private var showExitConfirm = false
    @State private var recorded = false
    @State private var newBest = false
    @State private var noHintAvailable = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("digFlagMode") private var flagModeDefault = false
    @Environment(\.estReduceMotion) private var reduceMotion

    init(level: MineLevel, onExit: @escaping () -> Void, onAgain: @escaping () -> Void) {
        self.level = level
        self.onExit = onExit
        self.onAgain = onAgain
        _game = State(initialValue: MineGame(level: level))
    }

    var body: some View {
        VStack(spacing: 14) {
            chrome
            counters
            MineBoardView(
                board: game.board,
                exploded: game.exploded,
                hintCell: game.hintCell,
                onTap: { game.tap($0) },
                onLongPress: { index in
                    game.flag(index)
                }
            )
            .padding(.horizontal, 12)
            .allowsHitTesting(game.status == .ready || game.status == .playing)
            controls
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Appearance.shared.gameBackground)
        .overlay {
            if game.status == .won || game.status == .lost {
                endCard
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: FeedbackTrigger(value: game.digToken, enabled: hapticsEnabled))
        .sensoryFeedback(.selection, trigger: FeedbackTrigger(value: game.flagToken, enabled: hapticsEnabled))
        .onChange(of: game.digToken) { _, _ in GameAudio.shared.play(.deal) }
        .onChange(of: game.flagToken) { _, _ in GameAudio.shared.play(.cardSelected(step: 1)) }
        .onChange(of: game.status) { _, status in
            guard status == .won || status == .lost, !recorded else { return }
            recorded = true
            DIGEvent.gameCompleted.record()
            if status == .won {
                GameAudio.shared.play(.completion)
                DIGEvent.boardWon.record()
            } else {
                GameAudio.shared.play(.mismatch)
                DIGEvent.boardLost.record()
            }
            for _ in 0..<game.guesses { DIGEvent.guess.record() }
            newBest = DIGStats.shared.record(game)
            if let score = DIGLeaderboard.score(for: game) {
                _ = GameCenterManager.shared.submit(score)
            }
        }
        .onAppear {
            game.mode = flagModeDefault ? .flag : .dig
            game.openStart()
            DIGEvent.gameStarted.record()
        }
        .confirmationDialog("Leave this board?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("Leave", role: .destructive, action: onExit)
            Button("Keep playing", role: .cancel) {}
        }
    }

    private var chrome: some View {
        HStack {
            GameExitButton(accessibilityLabel: "Leave board") {
                if game.status == .playing {
                    showExitConfirm = true
                } else {
                    onExit()
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text(level.title)
                    .font(.headline)
                if !game.noGuess {
                    Text("may need a guess")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: onAgain) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
            }
            .buttonStyle(.game(.quiet, tint: .second, size: .icon))
            .accessibilityLabel("New board")
        }
        .padding(.horizontal, 20)
    }

    private var counters: some View {
        HStack {
            Label("\(game.board.remainingMines)", systemImage: "flag.fill")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .accessibilityLabel("\(game.board.remainingMines) mines left")
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text(TimeFormat.clock(game.elapsed()))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            Spacer()
            Button {
                game.mode = game.mode == .dig ? .flag : .dig
                flagModeDefault = game.mode == .flag
            } label: {
                Image(systemName: game.mode == .dig ? "hand.tap.fill" : "flag.fill")
            }
            .buttonStyle(.game(game.mode == .flag ? .secondary : .quiet, tint: .first, size: .icon))
            .accessibilityLabel(game.mode == .dig ? "Tap digs. Switch to flag mode" : "Tap flags. Switch to dig mode")
        }
        .padding(.horizontal, 20)
    }

    private var controls: some View {
        VStack(spacing: 6) {
            Button {
                if game.revealHint() {
                    DIGEvent.hintUsed.record()
                    GameAudio.shared.play(.hint)
                    noHintAvailable = false
                } else {
                    noHintAvailable = true
                }
            } label: {
                Label("Hint", systemImage: "lightbulb")
            }
            .buttonStyle(.game(.secondary, tint: .third, size: .medium))
            .disabled(!(game.status == .ready || game.status == .playing) || game.hintCell != nil)
            Text(noHintAvailable ? "Nothing on the board proves a safe cell right now." : "Tap to dig. Hold to flag. Tap a number to open around it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
    }

    private var endCard: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            if game.status == .won {
                ConfettiView().ignoresSafeArea()
            }
            VStack(spacing: 18) {
                if game.status == .won {
                    Text(newBest ? "New best" : "Cleared")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    Text(TimeFormat.clock(game.elapsed()))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text(game.guesses == 0 ? "No guesses." : "\(game.guesses) \(game.guesses == 1 ? "guess" : "guesses").")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if game.hintUsed {
                        Text("Hinted rounds keep a personal best but stay off the leaderboard.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Mine")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    Text(game.lossReason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    Button("New board", action: onAgain)
                        .buttonStyle(.game(.primary, tint: .second, size: .large))
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
