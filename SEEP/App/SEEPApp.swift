import GameShell
import SwiftUI
import UIKit

@main
struct SEEPApp: App {
    @State private var supportStore = SupportStore()

    init() {
        GameIdentity.install(.seep)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supportStore)
                .task {
                    if !ProcessInfo.processInfo.arguments.contains("-SEEPScreenshotMode"),
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
        case levels
        case game(FloodLevel)
    }

    @State private var screen: Screen = .title
    @State private var pack: FloodPack = .pool
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
        ProcessInfo.processInfo.arguments.contains("-SEEPScreenshotMode")
    }

    private var inGame: Bool {
        if case .game = screen { return true }
        return false
    }

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                SEEPTitleView(
                    onPlay: { level in screen = .game(level) },
                    onLevels: { screen = .levels },
                    onLeaderboards: { showLeaderboards = true },
                    onSettings: { showSettings = true },
                    onHowToPlay: { showTutorial = true }
                )
                .transition(.opacity)
            case .levels:
                LevelGridView(pack: $pack, onPlay: { pack, index in
                    screen = .game(pack.level(index))
                }, onBack: { screen = .title })
                .transition(.opacity)
            case .game(let level):
                FloodGameView(level: level, onExit: { screen = exitTarget(for: level) }, onNext: next(after: level))
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
        .sheet(isPresented: $showSettings) {
            SEEPSettingsView()
        }
        .sheet(isPresented: $showLeaderboards) {
            SEEPLeaderboardView()
        }
        .fullScreenCover(isPresented: $showTutorial) {
            FloodTutorialView {
                hasSeenTutorial = true
                SEEPEvent.tutorialViewed.record()
                showTutorial = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            ESTTelemetry.migrateConsentIfNeeded()
            SEEPEvent.launch.record()
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
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func exitTarget(for level: FloodLevel) -> Screen {
        if case .pack(let p, _) = level.kind {
            pack = p
            return .levels
        }
        return .title
    }

    private func next(after level: FloodLevel) -> (() -> Void)? {
        guard case .pack(let p, let index) = level.kind, index + 1 < FloodPack.levelCount else { return nil }
        return { screen = .game(p.level(index + 1)) }
    }

    private func updateGameCenterAccessPoint() {
        GameCenterManager.shared.setAccessPointVisible(screen == .title && !showSettings)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && scenePhase == .active && inGame
    }
}
