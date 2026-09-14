import GameShell
import GridKit
import SwiftUI
import UIKit

@main
struct ESTApp: App {
    @State private var supportStore = SupportStore()

    init() {
        GameIdentity.install(.est)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supportStore)
                .task {
                    if !ProcessInfo.processInfo.arguments.contains("-ESTScreenshotMode"),
                       ESTTelemetry.enabled {
                        TelemetryCoordinator.shared.start()
                    }
                    AppIconManager.update(for: Appearance.shared.theme)
                    await supportStore.start()
                }
        }
    }
}

struct RootView: View {
    enum Screen: Equatable {
        case title
        case solo(GameEngine.Variant)
        case resumeSolo(GameEngine.Variant)
        case party(Int)
        case networkParty
    }

    @State private var screen: Screen = .title
    @State private var showMatchmaker = false
    @State private var showLeaderboards = false
    @State private var showSettings = false
    @State private var networkSession: NetworkPartySession?
    /// First launch opens the tutorial over the title screen. Set once the
    /// learner finishes or skips it; the rules sheet replays it on demand.
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    /// Games can use the full screen by hiding system game chrome. This is
    /// intentionally app-wide so every game mode feels the same.
    @AppStorage("immersiveGameMode") private var immersiveGameMode = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @State private var showTutorial = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemColorDifferentiation
    @Environment(\.colorSchemeContrast) private var systemColorSchemeContrast

    /// The marketing screenshot test needs a clean title screen on every run.
    /// This launch argument is only consumed by UI-test launches; normal users
    /// still get the first-launch tutorial.
    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-ESTScreenshotMode")
    }

    private var isGameScreen: Bool {
        switch screen {
        case .title: false
        case .solo, .resumeSolo, .party, .networkParty: true
        }
    }

    private var shouldHideGameChrome: Bool {
        isGameScreen && immersiveGameMode
    }

    private var effectiveReduceMotion: Bool {
        Appearance.shared.reduceMotion.resolved(using: systemReduceMotion)
    }

    private var effectiveHighContrast: Bool {
        Appearance.shared.highContrast.resolved(using: systemColorSchemeContrast == .increased)
    }

    private var effectiveColorBlindAssist: Bool {
        Appearance.shared.colorBlindAssist.resolved(using: systemColorDifferentiation)
    }

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                TitleView(
                    onSolo: { screen = .solo(.full) },
                    onQuickSolo: { screen = .solo(.quick) },
                    onParty: { screen = .party($0) },
                    onOnlineParty: { showMatchmaker = true },
                    onLeaderboards: { showLeaderboards = true },
                    onResumeSolo: { screen = .resumeSolo($0) },
                    showSettings: $showSettings
                )
                .transition(.opacity)
            case .solo(let variant):
                SoloGameView(variant: variant, onExit: { screen = .title })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .resumeSolo(let variant):
                SoloGameView(
                    variant: variant,
                    resumesSavedRun: true,
                    onExit: { screen = .title }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .party(let count):
                PartyGameView(playerCount: count, onExit: { screen = .title })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .networkParty:
                if let networkSession {
                    NetworkPartyGameView(session: networkSession) {
                        self.networkSession = nil
                        screen = .title
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        // Keep the system status-bar region part of the selected app surface.
        // The child screens all use this same color, so there is no white
        // strip above the title or game board.
        .background(Appearance.shared.gameBackground.ignoresSafeArea())
        .animation(.spring(duration: 0.4), value: screen)
        .environment(\.estReduceMotion, effectiveReduceMotion)
        .environment(\.estHighContrast, effectiveHighContrast)
        .environment(\.estColorBlindAssist, effectiveColorBlindAssist)
        .contrast(effectiveHighContrast ? 1.1 : 1)
        .transaction { transaction in
            if effectiveReduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        // Follows the device unless the player picks Light or Dark in
        // Settings. Themes never force a mode.
        .preferredColorScheme(Appearance.shared.preferredColorScheme)
        .statusBarHidden(shouldHideGameChrome)
        .sheet(isPresented: $showMatchmaker) {
            MatchmakerView(
                configuration: MatchmakerConfiguration(
                    minimumPlayers: PartySession.minimumPlayerCount,
                    maximumPlayers: PartySession.matchmakingMaximumPlayerCount
                ),
                onMatch: { match in
                    showMatchmaker = false
                    networkSession = NetworkPartySession(match: match)
                    screen = .networkParty
                },
                onDismiss: { showMatchmaker = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showLeaderboards) {
            LeaderboardView()
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView {
                hasSeenTutorial = true
                ESTTelemetry.record(.tutorialViewed)
                showTutorial = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            ESTTelemetry.migrateConsentIfNeeded()
            updateGameCenterAccessPoint()
            updateIdleTimer()
            if !isScreenshotMode {
                GameCenterManager.shared.authenticate()
            }
            if !isScreenshotMode && !hasSeenTutorial {
                showTutorial = true
            }
        }
        .onChange(of: screen) { _, _ in
            updateGameCenterAccessPoint()
        }
        .onChange(of: showSettings) { _, _ in
            updateGameCenterAccessPoint()
        }
        .onChange(of: immersiveGameMode) { _, _ in
            updateGameCenterAccessPoint()
        }
        .onChange(of: keepScreenAwake) { _, _ in
            updateIdleTimer()
        }
        .onChange(of: scenePhase) { _, _ in
            updateIdleTimer()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func updateGameCenterAccessPoint() {
        GameCenterManager.shared.setAccessPointVisible(
            screen == .title && !shouldHideGameChrome && !showSettings
        )
    }

    @MainActor
    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && scenePhase == .active
    }
}
