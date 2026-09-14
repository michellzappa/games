import GameShell
import GridKit
import SwiftUI

/// Multi-device party: every player holds their own phone. Each player's
/// collected-card deck is shown beside their player controls or summary.
struct NetworkPartyGameView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var winnerSize: CGFloat = 30
    let session: NetworkPartySession
    @State private var pileFrames = PileFrames()
    @State private var showExitConfirm = false
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    var onExit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            gameChrome
            opponentsRow

            adaptiveBoard

            HStack(spacing: 12) {
                if let me = session.localPlayer {
                    Text(me.name)
                        .font(.headline.bold())
                        .foregroundStyle(me.color)
                        .frame(width: GameButtonStyle.Size.large.height)
                }
                localBuzzButton
                if let me = session.localPlayer {
                    PlayerDeckView(
                        cardCount: me.cardCount,
                        frameID: "player-\(me.id)"
                    )
                }
            }
        }
        .padding()
        .coordinateSpace(name: "game")
        .onPreferenceChange(PileFramesKey.self) { pileFrames = $0 }
        .background(Appearance.shared.gameBackground)
        .confirmationDialog("Leave the match?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("Leave match", role: .destructive) { exit() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Leaving ends the match for everyone.")
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: session.matchToken, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .success
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: session.mismatchToken, enabled: hapticsEnabled)
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
            trigger: FeedbackTrigger(value: session.isFinished, enabled: hapticsEnabled)
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
        .onChange(of: session.isFinished) { _, finished in
            if finished {
                GameAudio.shared.play(.completion)
            }
        }
        .overlay {
            if session.someoneLeft {
                endCard {
                    Text("A player disconnected")
                        .font(.headline)
                }
            } else if session.isFinished {
                endCard(celebratory: true) {
                    let winners = session.winners
                    Text(winners.count == 1 ? "\(winners[0].name) wins" : "Tie game")
                        .font(.system(size: winnerSize, weight: .black, design: .rounded))
                        .foregroundStyle(winners.count == 1 ? winners[0].color : .primary)
                    scoreList
                }
            }
        }
        .onAppear {
            ESTTelemetry.record(.gamesStarted)
            ESTTelemetry.record(.networkDuelStarted)
        }
        .onChange(of: session.matchToken) { oldToken, newToken in
            guard newToken > oldToken else { return }
            ESTTelemetry.record(.setFound)
        }
        .onChange(of: session.isFinished) { _, finished in
            if finished {
                ESTTelemetry.record(.gamesCompleted)
                ESTTelemetry.record(.networkDuelCompleted)
                Task {
                    await TelemetryCoordinator.shared.flushCurrentPeriod()
                }
            }
        }
        .onDisappear {
            session.leave()
        }
    }

    private func exit() {
        session.leave()
        onExit()
    }

    private var gameChrome: some View {
        HStack {
            exitButton
            Spacer()
        }
        .frame(minHeight: GameButtonStyle.Size.icon.height)
    }

    private var exitButton: some View {
        GameExitButton(accessibilityLabel: "Leave match") {
            if session.isFinished || session.someoneLeft {
                exit()
            } else {
                showExitConfirm = true
            }
        }
    }

    private var activePlayer: NetworkPartySession.PlayerDisplay? {
        guard let activeID = session.activePlayerID else { return nil }
        return session.players.first { $0.id == activeID }
    }

    /// Keeps the card grid close to the player who claimed it. The outer
    /// geometry is flexible, while the inner grid is only as tall as its
    /// fitted cards require, so alignment can move it toward either side.
    private var adaptiveBoard: some View {
        GeometryReader { proxy in
            let layout = GridLayout.fitting(
                columns: 3,
                rows: GridLayout.rows(for: session.table.count, columns: 3),
                gap: 10,
                in: proxy.size
            )
            let width = layout.width
            let height = layout.height
            let alignment: Alignment = session.activePlayerID == session.localID
                ? .bottom
                : session.activePlayerID == nil ? .center : .top

            boardView
                .frame(width: width, height: height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
        .frame(maxHeight: .infinity)
        .animation(.spring(duration: 0.45), value: session.activePlayerID)
    }

    private var boardView: some View {
        BoardGridView(
            table: session.table,
            selectedIDs: session.selectedIDs,
            mismatchIDs: session.mismatchIDs,
            mismatchToken: session.mismatchToken,
            dealToken: session.dealToken,
            celebrationIDs: session.celebrationIDs,
            collectedCount: session.doneCount,
            collectionTargetID: session.lastCollectorID.map { "player-\($0)" },
            pileFrames: pileFrames,
            isInteractive: session.activePlayerID == session.localID && !session.isFinished,
            claimColor: activePlayer?.color,
            claimDeadline: session.claimDeadline,
            // adaptiveBoard already fits the grid and frames it.
            maximumCardSide: .infinity
        ) { card in
            session.selectLocal(card)
        }
        .overlay(alignment: .bottom) {
            MismatchExplainer(
                reasons: session.mismatchReasons,
                token: session.mismatchToken
            )
            .padding(.bottom, 6)
        }
    }

    private var opponentsRow: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            HStack(spacing: 8) {
                ForEach(session.players.filter { $0.id != session.localID }) { player in
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle().fill(player.color).frame(width: 10, height: 10)
                                Text(player.name)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                if player.isLocked(at: context.date) {
                                    Image(systemName: "hourglass")
                                        .font(.caption2)
                                }
                            }
                            Text("Their cards")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        PlayerDeckView(
                            cardCount: player.cardCount,
                            frameID: "player-\(player.id)"
                        )
                            .rotationEffect(.degrees(180))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            player.color.opacity(session.activePlayerID == player.id ? 0.35 : 0.12)
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var localBuzzButton: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let now = context.date
            let me = session.localPlayer
            let isActive = session.activePlayerID == session.localID
            let isLocked = me?.isLocked(at: now) ?? false
            let enabled = session.canBuzzLocally(at: now)
            let isUnavailable = !enabled && !isActive
            let color = me?.color ?? .accentColor

            Button {
                    guard session.canBuzzLocally() else { return }
                    session.buzzLocal()
                } label: {
                VStack(spacing: 2) {
                    Text("SET")
                        .font(.headline.bold())
                    if isActive, let deadline = session.claimDeadline {
                        let claimWindow = ClaimRace<String>.Configuration.standard.claimWindow
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
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .frame(minHeight: GameButtonStyle.Size.large.height)
                .glassButtonSurface(
                    tint: color,
                    opacity: isActive ? 1 : isLocked || isUnavailable ? 0.25 : 0.85,
                    cornerRadius: 16
                )
                .foregroundStyle(.white)
            }
            .disabled(!enabled && !isActive)
            .accessibilityLabel("Your SET")
            .accessibilityHint("Claim the board before selecting a set")
        }
    }

    private var scoreList: some View {
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
        .padding(.horizontal, 24)
    }

    private func endCard(
        celebratory: Bool = false,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ZStack {
            if celebratory {
                ConfettiView.cards()
                    .ignoresSafeArea()
            }
            VStack(spacing: 20) {
                VaryingTitleView(fontSize: 40)
                content()
                Button("Menu", action: exit)
                    .buttonStyle(.game(.primary, tint: .second, size: .large))
                    .padding(.horizontal, 24)
            }
            .padding(32)
            .glassCard(cornerRadius: 24)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}
