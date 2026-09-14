import GameKit
import Observation
import UIKit

/// A validated score ready for any Game Center leaderboard. Individual games
/// own score units and eligibility; this platform service only submits them.
public struct GameCenterScore: Equatable, Sendable {
    public let leaderboardID: String
    public let value: Int
    public var context: Int = 0

    public init(leaderboardID: String, value: Int, context: Int = 0) {
        self.leaderboardID = leaderboardID
        self.value = value
        self.context = context
    }
}

/// Game Center authentication, presentation, and score submission. It has no
/// dependency on EST rules, variants, telemetry, or leaderboard identifiers.
@Observable
public final class GameCenterManager {
    public static let shared = GameCenterManager()

    public private(set) var isAuthenticated = false
    private let dismissDelegate = DismissDelegate()
    private var wantsAccessPointVisible = false

    private init() {}

    public func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let viewController {
                Self.topViewController()?.present(viewController, animated: true)
                return
            }
            self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            self?.updateAccessPoint()
        }
    }

    public func setAccessPointVisible(_ visible: Bool) {
        wantsAccessPointVisible = visible
        updateAccessPoint()
    }

    private func updateAccessPoint() {
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.showHighlights = true
        GKAccessPoint.shared.isActive = wantsAccessPointVisible && isAuthenticated
    }

    /// Submits a score that the calling game has already validated.
    @discardableResult
    public func submit(_ score: GameCenterScore) -> Bool {
        guard isAuthenticated,
              !score.leaderboardID.isEmpty,
              score.value >= 0
        else { return false }

        Task {
            try? await GKLeaderboard.submitScore(
                score.value,
                context: score.context,
                player: GKLocalPlayer.local,
                leaderboardIDs: [score.leaderboardID]
            )
        }
        return true
    }

    public func showLeaderboard(id: String) {
        guard isAuthenticated else { return }
        let vc = GKGameCenterViewController(
            leaderboardID: id,
            playerScope: .global,
            timeScope: .allTime
        )
        vc.gameCenterDelegate = dismissDelegate
        Self.topViewController()?.present(vc, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private final class DismissDelegate: NSObject, GKGameCenterControllerDelegate {
        public func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            gameCenterViewController.dismiss(animated: true)
        }
    }
}
