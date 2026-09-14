import GameShell
import SwiftUI

/// Local multiplayer on one device. A two-player game keeps the compact
/// top-and-bottom duel layout; the four-player iPad game places one seat on
/// every edge of the table.
struct PartyGameView: View {
    @State private var session: PartySession
    @State private var pileFrames = PileFrames()
    @State private var showExitConfirm = false
    /// How the card symbols face. A quarter turn per tap, so a duel can stop
    /// halfway and read the cards from the side. The grid itself never moves.
    @State private var boardRotation: Angle = .zero
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    var onExit: () -> Void

    init(playerCount: Int, onExit: @escaping () -> Void) {
        _session = State(initialValue: PartySession(playerCount: playerCount))
        self.onExit = onExit
    }

    private var topPlayers: [PartySession.Player] {
        session.players.filter { $0.id % 2 == 1 }
    }

    private var bottomPlayers: [PartySession.Player] {
        session.players.filter { $0.id % 2 == 0 }
    }

    private var usesFourPlayerLayout: Bool {
        session.players.count == PartySession.maximumPlayerCount
    }

    var body: some View {
        VStack(spacing: 0) {
            gameChrome

            Group {
                if usesFourPlayerLayout {
                    fourPlayerLayout
                } else {
                    twoPlayerLayout
                }
            }
        }
        .padding()
        .coordinateSpace(name: "game")
        .onPreferenceChange(PileFramesKey.self) { pileFrames = $0 }
        .background(Appearance.shared.gameBackground)
        .confirmationDialog("End this game?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("End game", role: .destructive) { onExit() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Your scores will be lost.")
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: session.engine.matchToken, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .success
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: session.engine.mismatchToken, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .error
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: session.activePlayerID, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value, newValue.value != nil else { return nil }
            return .impact(weight: .heavy, intensity: 0.9)
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: session.engine.isFinished, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, !oldValue.value, newValue.value else { return nil }
            return .success
        }
        .onChange(of: session.activePlayerID) { _, playerID in
            if playerID != nil {
                GameAudio.shared.play(.buzz)
            }
        }
        .onChange(of: session.penaltyToken) { _, newToken in
            if newToken > 0 {
                GameAudio.shared.play(.penalty)
            }
        }
        .onChange(of: session.engine.isFinished) { _, finished in
            if finished {
                GameAudio.shared.play(.completion)
            }
        }
        .overlay {
            if session.engine.isFinished {
                PartyGameOverView(session: session, onExit: onExit)
            }
        }
        .onAppear {
            ESTTelemetry.record(.gamesStarted)
            ESTTelemetry.record(.localDuelStarted)
        }
        .onChange(of: session.engine.matchToken) { oldToken, newToken in
            guard newToken > oldToken else { return }
            ESTTelemetry.record(.setFound)
        }
        .onChange(of: session.engine.isFinished) { _, finished in
            if finished {
                ESTTelemetry.record(.gamesCompleted)
                ESTTelemetry.record(.localDuelCompleted)
                Task {
                    await TelemetryCoordinator.shared.flushCurrentPeriod()
                }
            }
        }
    }

    private var gameChrome: some View {
        HStack {
            exitButton
            Spacer()
            GameFlipButton {
                boardRotation += GameFlipButton.step
            }
        }
        .frame(minHeight: GameButtonStyle.Size.icon.height)
    }

    private var twoPlayerLayout: some View {
        VStack(spacing: 10) {
            playerRow(topPlayers, flipped: true)

            gameBoard

            playerRow(bottomPlayers, flipped: false)
        }
    }

    /// Four seats fit around a shared-device table. Each seat gets a real
    /// layout region before it is rotated, so the board remains centered in
    /// both tall iPhone windows and iPad landscape.
    private var fourPlayerLayout: some View {
        GeometryReader { proxy in
            let isCompactSquare = PartySession.isCompactFourPlayerWindow(in: proxy.size)
            let seatButtonWidth = isCompactSquare
                ? min(210, max(180, proxy.size.width * 0.28))
                : min(260, max(220, proxy.size.width * 0.24))
            let gridGap: CGFloat = 10
            let rows = max(1, Int(ceil(Double(session.engine.table.count) / 3)))
            let seatThickness = GameButtonStyle.Size.large.height
            let edgeGap: CGFloat = 8

            // Side controls are rotated, so their visible width is the
            // button height. Reserve that actual footprint on each side of
            // the table rather than reserving the unrotated button width.
            let availableBoardWidth = max(
                1,
                proxy.size.width - (seatThickness + edgeGap) * 2
            )
            let availableBoardHeight = max(
                1,
                proxy.size.height
                    - (seatThickness + edgeGap) * 2
            )
            let widthLimitedCardSide = max(
                1,
                (availableBoardWidth - gridGap * 2) / 3
            )
            let fittedCardSide = min(
                widthLimitedCardSide,
                max(1, (availableBoardHeight - CGFloat(rows - 1) * gridGap) / CGFloat(rows))
            )
            // Leave a generous visual moat between the table and all four
            // player controls. The board still responds to available space,
            // just at a deliberately more comfortable scale.
            let cardSide = fittedCardSide * 0.8
            let boardWidth = cardSide * 3 + gridGap * 2
            let boardHeight = cardSide * CGFloat(rows) + gridGap * CGFloat(rows - 1)
            let boardCenter = CGPoint(
                x: proxy.size.width / 2,
                y: proxy.size.height / 2
            )

            ZStack {
                gameBoard
                    .frame(width: boardWidth, height: boardHeight)
                    .position(boardCenter)

                playerSeat(
                    playerIndex: 2,
                    buttonWidth: seatButtonWidth,
                    rotation: .degrees(180)
                )
                .position(x: proxy.size.width / 2, y: seatThickness / 2)

                playerSeat(playerIndex: 0, buttonWidth: seatButtonWidth)
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height - seatThickness / 2
                    )

                playerSeat(
                    playerIndex: 1,
                    buttonWidth: seatButtonWidth,
                    rotation: .degrees(90),
                    isSideSeat: true
                )
                .position(x: seatThickness / 2, y: proxy.size.height / 2)

                playerSeat(
                    playerIndex: 3,
                    buttonWidth: seatButtonWidth,
                    rotation: .degrees(-90),
                    isSideSeat: true
                )
                .position(
                    x: proxy.size.width - seatThickness / 2,
                    y: proxy.size.height / 2
                )
            }
        }
    }

    private var gameBoard: some View {
        BoardGridView(
            engine: session.engine,
            collectionTargetID: session.lastCollectorID.map { "player-\($0)" },
            pileFrames: pileFrames,
            isInteractive: session.activePlayerID != nil && !session.engine.isFinished,
            claimColor: session.activePlayer?.color,
            claimDeadline: session.claimDeadline,
            // The seat layouts above already fit the grid and frame it.
            maximumCardSide: .infinity
        ) { card in
            _ = session.select(card)
        }
        .overlay(alignment: .bottom) {
            MismatchExplainer(
                reasons: session.engine.mismatchReasons,
                token: session.engine.mismatchToken
            )
            .padding(.bottom, 6)
        }
        .environment(\.estCardRotation, boardRotation)
    }

    private var exitButton: some View {
        GameExitButton {
            if session.engine.isFinished {
                onExit()
            } else {
                showExitConfirm = true
            }
        }
    }

    private func playerRow(_ players: [PartySession.Player], flipped: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(players) { player in
                HStack(spacing: 8) {
                    playerName(player)
                    BuzzButton(session: session, playerID: player.id)
                        .frame(maxWidth: .infinity)
                    PlayerDeckView(
                        cardCount: player.cardCount,
                        frameID: "player-\(player.id)"
                    )
                }
                .frame(maxWidth: .infinity)
                    .rotationEffect(flipped ? .degrees(180) : .zero)
            }
        }
    }

    private func playerSeat(
        playerIndex: Int,
        buttonWidth: CGFloat,
        rotation: Angle = .zero,
        isSideSeat: Bool = false
    ) -> some View {
        let player = session.players[playerIndex]
        let seatThickness = GameButtonStyle.Size.large.height
        let seatLength = buttonWidth + seatThickness * 2 + 8 * 2
        return HStack(spacing: 8) {
            // The label and deck reserve identical space, placing SET at the
            // exact center of this player's edge of the table.
            playerName(player, metadataWidth: seatThickness)
            BuzzButton(session: session, playerID: player.id)
                .frame(width: buttonWidth)
            PlayerDeckView(
                cardCount: player.cardCount,
                frameID: "player-\(player.id)"
            )
        }
        .frame(width: seatLength, height: seatThickness)
        .rotationEffect(rotation)
        // Rotation is a drawing transform: it does not swap a view's layout
        // dimensions. This outer frame matches the transformed footprint so
        // a side seat occupies a narrow, tall edge region as intended.
        .frame(
            width: isSideSeat ? seatThickness : seatLength,
            height: isSideSeat ? seatLength : seatThickness
        )
    }

    private func playerName(
        _ player: PartySession.Player,
        metadataWidth: CGFloat = 34
    ) -> some View {
        Text(player.name)
            .font(.headline.bold())
            .foregroundStyle(player.color)
            .frame(width: metadataWidth)
    }
}

/// Animated claim indicator for party mode. The pulse starts restrained and
/// accelerates as the claim window gets close to expiring.
struct PartyClaimOutline: View {
    let color: Color
    let deadline: Date?

    @Environment(\.estReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let values = pulseValues(at: context.date)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(values.glowOpacity), lineWidth: values.lineWidth + 4)
                    .blur(radius: values.glowRadius)

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(color.opacity(values.opacity), lineWidth: values.lineWidth)
            }
            .allowsHitTesting(false)
        }
    }

    private func pulseValues(at date: Date) -> PulseValues {
        guard !reduceMotion else {
            return PulseValues(opacity: 0.9, glowOpacity: 0.18, lineWidth: 3, glowRadius: 4)
        }

        let claimWindow = ClaimRace<Int>.Configuration.standard.claimWindow
        let remaining = max(0, deadline?.timeIntervalSince(date) ?? claimWindow)
        let elapsed = min(max(claimWindow - remaining, 0), claimWindow)
        let progress = elapsed / claimWindow
        let startingCyclesPerSecond = 0.35
        let endingCyclesPerSecond = 1.8
        let frequencySlope = (endingCyclesPerSecond - startingCyclesPerSecond) / claimWindow
        let completedCycles = startingCyclesPerSecond * elapsed
            + 0.5 * frequencySlope * elapsed * elapsed
        let phase = completedCycles * 2 * .pi
        let wave = 0.5 + 0.5 * sin(phase - .pi / 2)

        return PulseValues(
            opacity: 0.22 + wave * (0.48 + progress * 0.24),
            glowOpacity: 0.06 + wave * (0.18 + progress * 0.16),
            lineWidth: 2.4 + wave * (1.1 + progress * 1.0),
            glowRadius: 3 + wave * (4 + progress * 4)
        )
    }

    private struct PulseValues {
        let opacity: Double
        let glowOpacity: Double
        let lineWidth: CGFloat
        let glowRadius: CGFloat
    }
}

/// A player's claim button is deliberately just the SET action. While they
/// hold the claim, it also shows a draining countdown bar for the selection
/// window; identity and score live beside it in the seat layout.
private struct BuzzButton: View {
    let session: PartySession
    let playerID: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let now = context.date
            let player = session.players.first { $0.id == playerID }!
            let isActive = session.activePlayerID == playerID
            let isLocked = player.isLocked(at: now)
            let enabled = session.canBuzz(playerID, at: now)
            let isUnavailable = !enabled && !isActive

            Button {
                guard session.canBuzz(playerID) else { return }
                session.buzz(playerID)
            } label: {
                VStack(spacing: 2) {
                    Text("SET")
                        .font(.headline.bold())
                    if isActive, let deadline = session.claimDeadline {
                        let claimWindow = ClaimRace<Int>.Configuration.standard.claimWindow
                        let progress = max(0, deadline.timeIntervalSince(now) / claimWindow)
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: proxy.size.width * progress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 4)
                    } else if isLocked {
                        Image(systemName: "hourglass")
                            .font(.caption2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .frame(minHeight: GameButtonStyle.Size.large.height)
                .glassButtonSurface(
                    tint: player.color,
                    opacity: isActive ? 1 : isLocked || isUnavailable ? 0.25 : 0.8,
                    cornerRadius: 14
                )
                .foregroundStyle(.white)
            }
            .disabled(!enabled && !isActive)
            .accessibilityLabel("\(player.name)'s SET")
            .accessibilityHint("Claim the board before selecting a set")
        }
    }
}

private struct PartyGameOverView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var winnerSize: CGFloat = 34
    let session: PartySession
    let onExit: () -> Void

    var body: some View {
        ZStack {
            ConfettiView.cards(tints: confettiTints)
                .ignoresSafeArea()
            card
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private var confettiTints: [Card.Tint] {
        let winnerColors = session.winners.map(\.color)
        let matching = Card.Tint.allCases.filter { winnerColors.contains($0.color) }
        return matching.isEmpty ? Card.Tint.allCases : matching
    }

    private var card: some View {
        VStack(spacing: 20) {
            VaryingTitleView(fontSize: 40)
            let winners = session.winners
            Text(winners.count == 1 ? "\(winners[0].name) wins" : "Tie game")
                .font(.system(size: winnerSize, weight: .black, design: .rounded))
                .foregroundStyle(winners.count == 1 ? winners[0].color : .primary)

            VStack(spacing: 8) {
                ForEach(session.players.sorted { $0.score > $1.score }) { player in
                    HStack {
                        Circle().fill(player.color).frame(width: 12, height: 12)
                        Text(player.name)
                        Spacer()
                        Text("\(player.score)")
                            .monospacedDigit()
                            .bold()
                    }
                    .font(.headline)
                }
            }
            .padding(.horizontal, 32)

            Button("Menu", action: onExit)
                .buttonStyle(.game(.primary, tint: .second, size: .large))
                .padding(.horizontal, 24)
        }
        .padding(32)
        .glassCard(cornerRadius: 24)
        .padding(24)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}
