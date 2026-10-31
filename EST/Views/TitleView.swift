import GameShell
import SwiftUI

/// The app's name never settles: the three letters keep shuffling through
/// permutations of S, E, T (skipping the one spelling that names the
/// original game).
struct VaryingTitleView: View {
    var fontSize: CGFloat = 72
    /// Fired on every letter shuffle so companions (the title screen's demo
    /// cards) can cycle on the same beat.
    var onCycle: (() -> Void)? = nil

    private static let permutations = ["EST", "TSE", "STE", "ETS", "TES"]
    @State private var index = 0

    var body: some View {
        HStack(spacing: fontSize * 0.06) {
            ForEach(Array(Self.permutations[index]), id: \.self) { letter in
                Text(String(letter))
                    .font(.system(size: fontSize, weight: .black, design: .rounded))
                    .foregroundStyle(color(for: letter))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("EST")
        .accessibilityAddTraits(.isHeader)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7.2))
                withAnimation(.spring(duration: 0.7)) {
                    index = (index + 1) % Self.permutations.count
                }
                onCycle?()
            }
        }
    }

    private func color(for letter: Character) -> Color {
        switch letter {
        case "E": Card.Tint.red.color
        case "S": Card.Tint.blue.color
        default: Card.Tint.yellow.color
        }
    }
}

struct TitleView: View {
    var onSolo: () -> Void
    var onQuickSolo: () -> Void
    var onDaily: () -> Void = {}
    var onParty: (Int) -> Void
    var onOnlineParty: () -> Void
    var onNearbyParty: () -> Void
    var onLeaderboards: () -> Void
    var onResumeSolo: (GameEngine.Variant) -> Void = { _ in }
    @Binding var showSettings: Bool

    /// An interrupted solo run, read when the title screen appears. While one
    /// exists, Resume is the primary action and Solo 81 steps down, so the
    /// screen still has exactly one primary button.
    @State private var savedRun: GameEngine.SavedRun?
    @State private var showRules = false
    @State private var showPlayStyle = false
    @State private var showTraining = false
    @State private var menu: HomeMenu = .root
    /// Set by the Stats sheet's Leaderboard button. The app root presents
    /// the leaderboard, so it opens only after the Stats sheet is gone.
    @State private var opensLeaderboardsAfterStats = false
    @AppStorage("quickTrait") private var quickTraitRaw = Card.Trait.fill.rawValue

    private enum HomeMenu {
        case root, solo, together
    }
    @State private var demoCards = Card.randomValidSet()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        // A NavigationStack only for its toolbar: the system places Rules,
        // Stats and Settings in the top bar on iPhone and iPad, and in the
        // side rail on iPhone Duo.
        NavigationStack {
            GeometryReader { proxy in
                let supportsFourPlayerMode = PartySession.supportsFourPlayerMode(in: proxy.size)
                let isWide = proxy.size.width > proxy.size.height && !usesAccessibilityLayout

                Group {
                    if usesAccessibilityLayout {
                        ScrollView {
                            titleContent(supportsFourPlayerMode: supportsFourPlayerMode, isWide: isWide)
                        }
                    } else {
                        titleContent(supportsFourPlayerMode: supportsFourPlayerMode, isWide: isWide)
                    }
                }
            }
            .background(Appearance.shared.gameBackground)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                // Game Center's floating access point sat over this corner of
                // the screen whatever the layout, so EST opens its
                // leaderboards from here instead.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Leaderboards", systemImage: "trophy", action: onLeaderboards)
                    Button("Rules", systemImage: "questionmark.circle") { showRules = true }
                    Button("Stats", systemImage: "chart.bar.xaxis") { showPlayStyle = true }
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
        }
        .sheet(isPresented: $showRules) {
            RulesView()
        }
        .sheet(isPresented: $showSettings) {
            ESTSettingsView()
        }
        .sheet(isPresented: $showTraining) {
            TrainingView()
        }
        .sheet(isPresented: $showPlayStyle, onDismiss: {
            if opensLeaderboardsAfterStats {
                opensLeaderboardsAfterStats = false
                onLeaderboards()
            }
        }) {
            PlayStyleView {
                opensLeaderboardsAfterStats = true
                showPlayStyle = false
            }
        }
        .onAppear {
            // Marketing captures need the same title screen on every run, so
            // a leftover run never adds a button there.
            savedRun = ProcessInfo.processInfo.arguments.contains("-ESTScreenshotMode")
                ? nil
                : SoloRunStore.load()
        }
    }

    /// The screen has two parts: the hero (name, tagline, demo set) on the
    /// plain background, and every choice inside one panel. A wide window
    /// puts them side by side.
    @ViewBuilder
    private func titleContent(supportsFourPlayerMode: Bool, isWide: Bool) -> some View {
        if isWide {
            HStack(spacing: 32) {
                hero
                    .frame(maxWidth: .infinity)
                menuPanel(supportsFourPlayerMode: supportsFourPlayerMode)
            }
            .padding(32)
            .frame(maxHeight: .infinity)
        } else {
            VStack(spacing: 24) {
                if !usesAccessibilityLayout {
                    Spacer()
                }
                hero
                if !usesAccessibilityLayout {
                    Spacer()
                }
                menuPanel(supportsFourPlayerMode: supportsFourPlayerMode)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            // GeometryReader pins its content top-leading. Once the panel
            // stops at its maximum width, it must still sit centered.
            .frame(maxWidth: .infinity)
        }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            VaryingTitleView {
                withAnimation(.spring(duration: 0.7)) {
                    demoCards = Card.randomValidSet()
                }
            }
            Text("A game of patterns")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            demoRow
                .padding(.top, 8)
        }
    }

    private func menuPanel(supportsFourPlayerMode: Bool) -> some View {
        VStack(spacing: 16) {
            // Back lives in the panel header, next to the choices it leaves.
            HStack(spacing: 12) {
                if menu != .root {
                    Button {
                        menu = .root
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .buttonStyle(.game(.quiet, size: .icon))
                    .accessibilityLabel("Back")
                }
                Text(menuTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: GameButtonStyle.Size.icon.height, alignment: .leading)
            menuButtons(supportsFourPlayerMode: supportsFourPlayerMode)
                .id(menu)
                .transition(.asymmetric(
                    insertion: .move(edge: menu == .root ? .leading : .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
        }
        .animation(.spring(duration: 0.35), value: menu)
        .padding(Self.menuPanelPadding)
        .frame(maxWidth: 460)
        .glassPanel(cornerRadius: Self.menuPanelCornerRadius)
    }

    private static let menuPanelPadding: CGFloat = 20
    /// Concentric with the large buttons inside: their corner radius (0.32 of
    /// the height, as GameButtonStyle draws it) plus the panel padding.
    private static let menuPanelCornerRadius =
        GameButtonStyle.Size.large.height * 0.32 + menuPanelPadding

    private var menuTitle: String {
        switch menu {
        case .root: "Play"
        case .solo: "Solo"
        case .together: "Together"
        }
    }

    /// Home asks one question at a time: who plays, then which game. Only
    /// the root level shows Resume.
    @ViewBuilder
    private func menuButtons(supportsFourPlayerMode: Bool) -> some View {
        VStack(spacing: 12) {
            switch menu {
            case .root:
                if savedRun != nil {
                    resumeButton
                }
                Button {
                    menu = .solo
                } label: {
                    Label("Solo", systemImage: "person.fill")
                }
                .buttonStyle(.game(savedRun == nil ? .primary : .secondary, tint: .second, size: .large))
                Button {
                    menu = .together
                } label: {
                    Label("Together", systemImage: "person.2.fill")
                }
                .buttonStyle(.game(.secondary, tint: .first, size: .large))
            case .solo:
                pairRow {
                    soloButton
                    quickSoloButton
                }
                quickTraitPicker
                dailyButton
                trainingButton
            case .together:
                menuSection("This device") {
                    pairRow {
                        partyButton(
                            playerCount: PartySession.minimumPlayerCount,
                            title: "Duel",
                            systemImage: "person.2.fill"
                        )
                        if supportsFourPlayerMode {
                            partyButton(
                                playerCount: PartySession.maximumPlayerCount,
                                title: "\(PartySession.maximumPlayerCount) players",
                                systemImage: "person.3.fill"
                            )
                        }
                    }
                }
                menuSection("Separate devices") {
                    pairRow {
                        nearbyPartyButton
                        onlinePartyButton
                    }
                }
            }
        }
    }

    /// Two choices side by side; stacked at accessibility text sizes.
    @ViewBuilder
    private func pairRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if usesAccessibilityLayout {
            VStack(spacing: 12, content: content)
        } else {
            HStack(spacing: 12, content: content)
        }
    }

    private func menuSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var soloButton: some View {
        Button(action: onSolo) {
            Label("Solo 81", systemImage: "timer")
        }
        .buttonStyle(.game(.primary, tint: .second, size: .large))
    }

    @ViewBuilder
    private var resumeButton: some View {
        if let savedRun {
            let variant = GameEngine.Variant(rawValue: savedRun.variant) ?? .full
            let found = savedRun.done.count / 3
            let total = (variant == .quick ? 27 : 81) / 3
            Button {
                onResumeSolo(variant)
            } label: {
                Label("Resume, \(found) of \(total)", systemImage: "play.fill")
            }
            .buttonStyle(.game(.primary, tint: .first, size: .large))
        }
    }

    /// Quick 27 holds one trait constant. Every choice is the same game
    /// underneath, but each looks different: one-symbol cards, one color,
    /// one shape, or one fill.
    private var quickTraitPicker: some View {
        VStack(spacing: 6) {
            Text("Quick 27 holds one trait")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Picker("Quick 27 holds", selection: $quickTraitRaw) {
                ForEach(Card.Trait.allCases) { trait in
                    Text(trait.name.capitalized).tag(trait.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var quickSoloButton: some View {
        Button(action: onQuickSolo) {
            Label("Quick 27", systemImage: "bolt.fill")
        }
        .buttonStyle(.game(.secondary, tint: .second, size: .large))
    }

    private func partyButton(
        playerCount: Int,
        title: String,
        systemImage: String
    ) -> some View {
        Button {
            onParty(playerCount)
        } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.game(.secondary, tint: .first, size: .large))
    }

    private var onlinePartyButton: some View {
        Button(action: onOnlineParty) {
            Label("Online", systemImage: "antenna.radiowaves.left.and.right")
        }
        .buttonStyle(.game(.secondary, tint: .first, size: .large))
        .disabled(!GameCenterManager.shared.isAuthenticated)
    }

    /// Devices in the same room, over Wi-Fi and Bluetooth. Needs no Game
    /// Center sign-in and no internet, so it is never disabled.
    private var nearbyPartyButton: some View {
        Button(action: onNearbyParty) {
            Label("Same room", systemImage: "wifi")
        }
        .buttonStyle(.game(.secondary, tint: .first, size: .large))
    }

    /// Today's shared deal. Shows the streak, and a check once today's is
    /// finished; it can still be replayed for a better time.
    private var dailyButton: some View {
        let streak = DailyStore.streak()
        let title = DailyStore.isDone()
            ? (streak > 1 ? "Daily done, \(streak) days" : "Daily done")
            : (streak > 0 ? "Daily, \(streak) day streak" : "Daily deal")
        return Button(action: onDaily) {
            Label(title, systemImage: DailyStore.isDone() ? "checkmark.seal.fill" : "calendar")
        }
        .buttonStyle(.game(.secondary, tint: .third, size: .large))
    }

    private var trainingButton: some View {
        Button {
            showTraining = true
        } label: {
            Label("Is this a set?", systemImage: "graduationcap.fill")
        }
        .buttonStyle(.game(.secondary, tint: .second, size: .large))
    }

    /// Always a valid EST, re-rolled on the same beat as the name shuffle.
    private var demoRow: some View {
        HStack(spacing: 12) {
            // Keep each physical position stable. The cards are shuffled as a
            // set, but the animation belongs to each of these three slots.
            ForEach(0..<3, id: \.self) { index in
                DemoCardSlot(card: demoCards[index])
            }
        }
        .frame(height: 84)
    }
}

private struct DemoCardSlot: View {
    let card: Card

    @State private var displayedCard: Card
    @State private var angle: Double = 0
    @State private var showingEdgeFrame = false

    init(card: Card) {
        self.card = card
        _displayedCard = State(initialValue: card)
    }

    var body: some View {
        ZStack {
            CardView(card: displayedCard)
                .rotation3DEffect(
                    .degrees(angle),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.65
                )

            if showingEdgeFrame {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Appearance.shared.theme.border)
                    .frame(width: 2, height: 84)
            }
        }
            .task(id: card.id) {
                guard displayedCard.id != card.id else { return }
                await flip(to: card)
            }
    }

    @MainActor
    private func flip(to newCard: Card) async {
        showingEdgeFrame = false
        withAnimation(.easeInOut(duration: 0.32)) {
            angle = 90
        }

        try? await Task.sleep(for: .seconds(0.32))
        guard !Task.isCancelled else { return }

        // The edge cue is its own state rather than an angle threshold, so it
        // cannot fade in while the card is still face-on or linger after the
        // card has started the second half of the flip.
        showingEdgeFrame = true
        try? await Task.sleep(for: .seconds(1.0 / 60.0))
        guard !Task.isCancelled else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedCard = newCard
            angle = -90
            showingEdgeFrame = false
        }

        withAnimation(.easeInOut(duration: 0.32)) {
            angle = 0
        }
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showTutorial = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro

                    rulesSection(
                        "Learn the rule",
                        "Start here if you are new to EST."
                    ) {
                        Button {
                            showTutorial = true
                        } label: {
                            Label("Walk me through it", systemImage: "graduationcap")
                        }
                        .buttonStyle(.game(.primary, tint: .second, size: .large))

                        NavigationLink {
                            MathVisualizerView()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "function")
                                    .font(.title3)
                                    .frame(width: 28)
                                    .foregroundStyle(Card.Tint.blue.color)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("The mathematics")
                                        .font(.subheadline.weight(.semibold))
                                    Text("Cards are points. Sets are lines. Explore the four-trit structure.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .glassButtonSurface(
                                tint: Card.Tint.blue.color,
                                opacity: 0.10,
                                cornerRadius: 14
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    rulesSection(
                        "Choose a mode",
                        "Pick a game and start playing."
                    ) {
                        ruleRow(
                            "timer",
                            "Solo 81",
                            "Clear all 81 cards against the clock. Your best time can go to Game Center."
                        )
                        ruleRow(
                            "bolt.fill",
                            "Quick 27",
                            "Play 27 cards that share one trait, for a shorter, faster round. Pick which trait from the Solo menu."
                        )
                        ruleRow(
                            "person.2.fill",
                            "Duel",
                            "Play pass-around on one phone, or live across phones over Game Center."
                        )
                    }

                    rulesSection(
                        "How the game works",
                        "The same rule applies in every mode."
                    ) {
                        ruleRow(
                            "square.grid.3x3.fill",
                            "The deck",
                            "81 cards cover every combination of count, color, shape, and fill. Each trait has three values."
                        )
                        ruleRow(
                            "checkmark.circle",
                            "A valid set",
                            "Three cards work when every trait is either the same on all three or different on all three. Two and one never works."
                        )
                        ruleRow(
                            "rectangle.3.group",
                            "The table",
                            "Start with 12 cards. Tap three that form a set. If none exists, three more cards appear automatically."
                        )
                        ruleRow(
                            "hand.tap",
                            "In a duel",
                            "Buzz first, then tap the three cards within \(Int(ClaimRace<Int>.Configuration.standard.claimWindow)) seconds. A miss costs a point and a short lockout."
                        )
                    }

                    rulesSection(
                        "About EST",
                        "A free game built around the structure of its deck."
                    ) {
                        Text("EST is a free, open-source iPhone game inspired by SET, the card game Marsha Falco created in 1974. It has its own name, artwork, and code, and is not affiliated with or endorsed by SET's makers. SET is a registered trademark of Cannei, LLC.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
            .background(Appearance.shared.gameBackground.ignoresSafeArea())
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showTutorial) {
                TutorialView { showTutorial = false }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Learn the rule, then play it")
                .font(.title2.bold())
            Text("A quick guide to the game, its modes, and the idea underneath all 81 cards.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func rulesSection<Content: View>(
        _ title: String,
        _ subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(16)
        .glassPanel(cornerRadius: 22)
    }

    private func ruleRow(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(Card.Tint.blue.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
