import GameShell
import SwiftUI

struct SoloGameView: View {
    var variant: GameEngine.Variant = .full
    /// Set by the title screen's Resume entry. The run is read once, on
    /// appear; the store is the source, not this flag.
    var resumesSavedRun = false
    @State private var engine = GameEngine()
    @AppStorage("bestSoloTime") private var bestFullTime: Double = 0
    @AppStorage("bestQuickTime") private var bestQuickTime: Double = 0
    @State private var submittedScore = false
    @State private var hintedIDs: Set<Int> = []
    /// The set the hint is pointing at. The second hint reveals its second
    /// card; it is never re-chosen while it is still on the table.
    @State private var hintSet: [Card] = []
    @State private var runInsight = RunInsight()
    @State private var hintUsed = false
    @State private var pileFrames = PileFrames()
    @State private var showExitConfirm = false
    @State private var showHintWarning = false
    @State private var lastMatchElapsed: TimeInterval = 0
    /// How the card symbols face. A quarter turn per tap.
    @State private var boardRotation: Angle = .zero
    @State private var isWide = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("showSoloTimer") private var showSoloTimer = true
    /// Which trait Quick 27 holds constant, chosen on the Solo menu.
    @AppStorage("quickTrait") private var quickTraitRaw = Card.Trait.fill.rawValue

    private var quickTrait: Card.Trait {
        Card.Trait(rawValue: quickTraitRaw) ?? .fill
    }
    var onExit: () -> Void

    private var bestTime: Double {
        variant == .quick ? bestQuickTime : bestFullTime
    }

    private var leaderboardID: String {
        ESTLeaderboard.leaderboardID(for: variant)
    }

    /// Marketing captures need to communicate the core interaction at a
    /// glance. This is presentation-only: the real engine selection remains
    /// empty until the player taps, so no gameplay or scoring behavior changes.
    private var screenshotSelectedIDs: Set<Int>? {
        guard ProcessInfo.processInfo.arguments.contains("-ESTScreenshotMode"),
              variant == .full else { return nil }
        return Set(engine.table.prefix(3).map(\.id))
    }

    private var board: some View {
        BoardGridView(
            engine: engine,
            selectedIDsOverride: screenshotSelectedIDs,
            hintedIDs: hintedIDs,
            pileFrames: pileFrames,
            isInteractive: !engine.isFinished && !engine.isPaused,
            // Solo gives the board the whole screen, so the ceiling is what
            // stops a card reaching a third of an iPad's width.
            maximumCardSide: horizontalSizeClass == .regular
                ? BoardGridView.regularMaximumCardSide
                : BoardGridView.compactMaximumCardSide
        ) { card in
            select(card)
        }
        .overlay(alignment: .bottom) {
            MismatchExplainer(reasons: engine.mismatchReasons, token: engine.mismatchToken)
                .padding(.bottom, 6)
        }
        .overlay {
            if engine.isPaused {
                VStack(spacing: 8) {
                    Image(systemName: "pause.circle.fill")
                        .font(.largeTitle)
                    Text("Paused")
                        .font(.headline)
                        .textCase(.uppercase)
                }
                .foregroundStyle(.secondary)
                .padding(28)
                .glassPanel(cornerRadius: 20)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: engine.isPaused)
        .environment(\.estCardRotation, boardRotation)
    }

    var body: some View {
        let piles = PilesView(engine: engine)
        Group {
            if isWide {
                // A wide window gives the height to the board: the piles move
                // beside it and the progress bar sits under the HUD.
                VStack(spacing: 12) {
                    hud
                    piles.progressBar
                        .frame(maxWidth: 360)
                    HStack(spacing: 24) {
                        piles.deckPile
                        board
                        piles.playedPile
                    }
                }
            } else {
                VStack(spacing: 12) {
                    hud
                    board
                    piles
                        .padding(.horizontal, 6)
                }
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isWide = $0 }
        .gameScreenPadding()
        .coordinateSpace(name: "game")
        .onPreferenceChange(PileFramesKey.self) { pileFrames = $0 }
        .background(Appearance.shared.gameBackground)
        .confirmationDialog("End this game?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("End game", role: .destructive) {
                SoloRunStore.clear()
                onExit()
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("The run and its time are lost.")
        }
        .alert("Use a hint?", isPresented: $showHintWarning) {
            Button("Use hint", role: .destructive) {
                revealHint()
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("If you use a hint, this run will not appear on the Game Center leaderboard. Your time can still become a personal best.")
        }
        // Only leaving the app pauses the clock, and only a pause takes a
        // run off the leaderboard. The exit and hint dialogs, Control Center
        // and Notification Center leave the clock running: the player loses
        // a few seconds but keeps a ranked run. They used to pause, which
        // quietly disqualified most full-deck runs.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                engine.resume()
            case .inactive:
                saveRun()
            default:
                engine.pause()
                saveRun()
            }
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: engine.matchToken, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .success
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: engine.mismatchToken, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .error
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: engine.isFinished, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, !oldValue.value, newValue.value else { return nil }
            return .success
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: hintedIDs, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .impact(flexibility: .rigid, intensity: 0.5)
        }
        .overlay {
            if engine.isFinished {
                SoloGameOverView(
                    time: engine.elapsed(),
                    bestTime: bestTime,
                    setsFound: engine.setsFound,
                    setsTotal: engine.setsTotal,
                    leftover: engine.table.count,
                    totalCards: engine.totalCards,
                    hintUsed: hintUsed,
                    runWasPaused: engine.wasPaused,
                    insight: runInsight,
                    leaderboardID: leaderboardID,
                    onPlayAgain: {
                        submittedScore = false
                        hintUsed = false
                        hintedIDs = []
                        hintSet = []
                        runInsight = RunInsight()
                        lastMatchElapsed = 0
                        engine.start(variant: variant, quickTrait: quickTrait)
                        saveRun()
                        ESTTelemetry.record(.gamesStarted)
                        ESTTelemetry.record(variant == .quick
                            ? .quickSoloStarted
                            : .fullSoloStarted)
                    },
                    onExit: onExit
                )
            }
        }
        .onAppear {
            lastMatchElapsed = 0
            // The engine advances by itself when a celebration ends. That is
            // the moment the table changes, so it is the moment to save.
            engine.onAutoAdvance = { saveRun() }
            if resumesSavedRun, let run = SoloRunStore.load() {
                hintUsed = run.hintUsed
                engine.restore(run)
            } else {
                engine.start(variant: variant, quickTrait: quickTrait)
            }
            ESTTelemetry.record(.gamesStarted)
            ESTTelemetry.record(variant == .quick
                ? .quickSoloStarted
                : .fullSoloStarted)
            saveRun()
        }
        .onDisappear {
            engine.onAutoAdvance = nil
        }
        .onChange(of: engine.table) {
            hintedIDs = []
            hintSet = []
        }
        .onChange(of: engine.matchToken) { oldToken, newToken in
            guard newToken > oldToken else { return }
            ESTTelemetry.record(.setFound)
        }
        .onChange(of: engine.isFinished) { _, finished in
            if finished {
                SoloRunStore.clear()
                GameAudio.shared.play(.completion)
                PlayerStats.shared.recordCompletedRound(variant)
                ESTTelemetry.record(.gamesCompleted)
                ESTTelemetry.record(variant == .quick
                    ? .quickSoloCompleted
                    : .fullSoloCompleted)
                Task {
                    await TelemetryCoordinator.shared.flushCurrentPeriod()
                }
            }
            guard finished, !submittedScore else { return }
            submittedScore = true
            let time = engine.elapsed()
            if bestTime == 0 || time < bestTime {
                if variant == .quick {
                    bestQuickTime = time
                } else {
                    bestFullTime = time
                }
            }
            // A hinted run keeps its local best but stays off the leaderboard.
            if !hintUsed,
               let score = ESTLeaderboard.score(
                   for: time,
                   variant: variant,
                   wasPaused: engine.wasPaused
               ) {
                GameCenterManager.shared.submit(score) { error in
                    ESTTelemetry.record(error == nil
                        ? .leaderboardSubmitted
                        : .leaderboardSubmitFailed)
                }
            }
        }
    }

    private var hud: some View {
        ZStack {
            // The timer sits in a ZStack so it is centered on screen, not
            // between the unequal left and right button groups.
            if showSoloTimer {
                TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                    Text(TimeFormat.clock(engine.elapsed()))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .monospacedDigit()
                }
                // An overlay, so the timer stays centered when it appears.
                .overlay(alignment: .trailing) {
                    if isUnranked {
                        Image(systemName: "nosign")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.secondary)
                            .alignmentGuide(.trailing) { $0[.leading] - 6 }
                            .accessibilityLabel("Unranked. This run will not reach the leaderboard.")
                    }
                }
            }
            HStack {
                GameExitButton {
                    if engine.isFinished {
                        onExit()
                    } else {
                        showExitConfirm = true
                    }
                }
                Spacer()
                GameFlipButton {
                    boardRotation += GameFlipButton.step
                }
                if variant == .full {
                    Button {
                        if hintUsed {
                            revealHint()
                        } else {
                            showHintWarning = true
                        }
                    } label: {
                        Image(systemName: hintUsed ? "lightbulb.fill" : "lightbulb")
                    }
                    .buttonStyle(.game(.quiet, tint: .third, size: .icon))
                    .disabled(engine.isFinished || hintedIDs.count >= 2)
                    .accessibilityLabel("Hint")
                    .accessibilityHint(!hintUsed
                        ? "Ask for a hint. This run will not appear on the leaderboard"
                        : hintedIDs.count == 1
                            ? "Reveal a second card of the same set"
                            : "Reveal a card from a set")
                }
            }
        }
    }

    /// A run that will not reach the leaderboard, shown while it is still
    /// running. Without Game Center nothing is ranked, so nothing is marked.
    private var isUnranked: Bool {
        GameCenterManager.shared.isAuthenticated
            && !engine.isFinished
            && (hintUsed || engine.wasPaused)
    }

    /// The first hint shows one card of a valid set, the second shows another
    /// card of the same set. The third card stays for the player to find.
    /// Marks the run: it will not submit to the leaderboard.
    private func revealHint() {
        let onTable = Set(engine.table)
        if hintSet.isEmpty || !hintSet.allSatisfy(onTable.contains) {
            guard let set = Card.findSet(in: engine.table) else { return }
            hintSet = set
            hintedIDs = []
        }
        guard hintedIDs.count < 2 else { return }
        hintedIDs.insert(hintSet[hintedIDs.count].id)
        hintUsed = true
        ESTTelemetry.record(.hintUsed)
        GameAudio.shared.play(.hint)
    }

    private func saveRun() {
        SoloRunStore.save(engine.savedRun(hintUsed: hintUsed))
    }

    private func select(_ card: Card) {
        let boardSetCount = Card.countSets(in: engine.table)
        let elapsed = engine.elapsed()
        switch engine.select(card) {
        case .pending:
            break
        case .matched(let cards):
            let seconds = elapsed - lastMatchElapsed
            PlayerStats.shared.recordMatch(
                cards,
                boardSetCount: boardSetCount,
                timeSincePreviousMatch: seconds,
                hinted: cards.contains { hintedIDs.contains($0.id) }
            )
            runInsight.recordMatch(cards, seconds: seconds)
            lastMatchElapsed = elapsed
        case .mismatched(let cards):
            PlayerStats.shared.recordMismatch(cards, boardSetCount: boardSetCount)
            runInsight.recordMismatch(cards)
        }
    }
}

struct SoloGameOverView: View {
    /// The completion time is the point of this screen, so it scales with
    /// the reader's text size instead of staying at a fixed 52 points.
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 52
    let time: TimeInterval
    let bestTime: Double
    var setsFound = 27
    var setsTotal = 27
    var leftover = 0
    var totalCards = 81
    var hintUsed = false
    var runWasPaused = false
    var insight = RunInsight()
    var leaderboardID = ESTLeaderboard.soloCompletionTimeID
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            ConfettiView.cards()
                .ignoresSafeArea()
            card
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    /// Where this run went fast and slow. Each line appears only when the
    /// run has the data for it.
    private var insightLines: [String] {
        var lines: [String] = []
        if let fastest = insight.fastest, let slowest = insight.slowest, setsFound > 1 {
            lines.append("Fastest set \(TimeFormat.shortSeconds(fastest)), slowest \(TimeFormat.shortSeconds(slowest))")
        }
        if let kind = insight.slowestKind {
            let traits = kind.differences == 1 ? "1 trait differs" : "\(kind.differences) traits differ"
            lines.append("Slowest when \(traits): \(TimeFormat.shortSeconds(kind.average)) on average")
        }
        if let missed = insight.mostMissedTrait {
            let misses = insight.mismatches == 1 ? "1 miss" : "\(insight.mismatches) misses"
            lines.append("\(misses), most often on \(missed.name)")
        } else if setsFound > 0 {
            lines.append("No misses")
        }
        return lines
    }

    private var card: some View {
        VStack(spacing: 20) {
            VaryingTitleView(fontSize: 40)
            Text("Complete")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(TimeFormat.clock(time))
                .font(.system(size: timeSize, weight: .black, design: .rounded))
                .monospacedDigit()

            Text("\(setsFound) sets, about \(String(format: "%.0f", time / Double(max(1, setsFound)))) seconds each")
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.85))

            // The zero-sum fact: the leftover always sums to zero, and a
            // leftover with no set is a cap. Never exactly 3 cards.
            Text(leftover == 0
                ? "Perfect clear: all \(totalCards) cards played."
                : "The last \(leftover) cards contain no set. This is a \(leftover)-card cap.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !insightLines.isEmpty {
                VStack(spacing: 4) {
                    ForEach(insightLines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.footnote)
                .foregroundStyle(Color.primary.opacity(0.85))
                .multilineTextAlignment(.center)
            }

            if bestTime > 0 {
                // A personal best is the good news on the card, so it reads
                // as a highlight rather than as another gray footnote.
                Text(time <= bestTime ? "New personal best" : "Best: \(TimeFormat.clock(bestTime))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(time <= bestTime ? Card.Tint.yellow.color : Color.primary.opacity(0.85))
            }

            if hintUsed {
                Label("Hint used. This run was not submitted.", systemImage: "lightbulb.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if runWasPaused {
                Label("You left the app during this run, so it was not submitted.", systemImage: "pause.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Button("Play again", action: onPlayAgain)
                    .buttonStyle(.game(.primary, tint: .second, size: .large))

                if GameCenterManager.shared.isAuthenticated {
                    Button("Leaderboard") {
                        GameCenterManager.shared.showLeaderboard(id: leaderboardID)
                    }
                    .buttonStyle(.game(.secondary, tint: .third))
                }

                Button("Menu", action: onExit)
                    .buttonStyle(.game(.quiet))
            }
            .padding(.horizontal, 24)
        }
        .padding(32)
        .glassCard(cornerRadius: 24)
        .padding(24)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}
