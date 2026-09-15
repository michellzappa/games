import GameShell
import SwiftUI
import UIKit

@main
struct DIGApp: App {
    @State private var supportStore = SupportStore()

    init() {
        GameIdentity.install(.dig)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supportStore)
                .task {
                    if !ProcessInfo.processInfo.arguments.contains("-DIGScreenshotMode"),
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
        case game(MineLevel)
    }

    @State private var screen: Screen = .title
    @State private var showLeaderboards = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage("immersiveGameMode") private var immersiveGameMode = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @Bindable private var appearance = Appearance.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var systemColorDifferentiation
    @Environment(\.colorSchemeContrast) private var systemColorSchemeContrast

    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-DIGScreenshotMode")
    }

    private var inGame: Bool {
        if case .game = screen { return true }
        return false
    }

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                DIGTitleView(
                    onPlay: { level in screen = .game(level) },
                    onLeaderboards: { showLeaderboards = true },
                    onSettings: { showSettings = true },
                    onHowToPlay: { showTutorial = true }
                )
                .transition(.opacity)
            case .game(let level):
                MineGameView(level: level, onExit: { screen = .title }, onAgain: { screen = .game(again(level)) })
                    .id(level)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: screen)
        .preferredColorScheme(appearance.preferredColorScheme)
        .environment(\.estReduceMotion, appearance.reduceMotion.resolved(using: systemReduceMotion))
        .environment(\.estHighContrast, appearance.highContrast.resolved(using: systemColorSchemeContrast == .increased))
        .environment(\.estColorBlindAssist, appearance.colorBlindAssist.resolved(using: systemColorDifferentiation))
        .statusBarHidden(inGame && immersiveGameMode)
        .sheet(isPresented: $showSettings) { DIGSettingsView() }
        .sheet(isPresented: $showLeaderboards) { DIGLeaderboardView() }
        .fullScreenCover(isPresented: $showTutorial) {
            MineTutorialView {
                hasSeenTutorial = true
                DIGEvent.tutorialViewed.record()
                showTutorial = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            ESTTelemetry.migrateConsentIfNeeded()
            DIGEvent.launch.record()
            updateGameCenterAccessPoint()
            updateIdleTimer()
            if !isScreenshotMode {
                GameCenterManager.shared.authenticate()
            }
            if !isScreenshotMode && !hasSeenTutorial {
                showTutorial = true
            }
        }
        .onChange(of: screen) { _, _ in updateGameCenterAccessPoint() }
        .onChange(of: showSettings) { _, _ in updateGameCenterAccessPoint() }
        .onChange(of: immersiveGameMode) { _, _ in updateGameCenterAccessPoint() }
        .onChange(of: keepScreenAwake) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, _ in updateIdleTimer() }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// A new board of the same kind: a fresh seed for a size, the same
    /// board for the daily.
    private func again(_ level: MineLevel) -> MineLevel {
        if case .random(let size) = level.kind { return .random(size) }
        return level
    }

    private func updateGameCenterAccessPoint() {
        GameCenterManager.shared.setAccessPointVisible(screen == .title && !showSettings)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && scenePhase == .active && inGame
    }
}
