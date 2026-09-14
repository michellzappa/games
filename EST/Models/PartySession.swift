import GameShell
import SwiftUI
import UIKit
import Observation

/// Local multiplayer on one device. Nobody can touch the board until a player
/// buzzes; the buzzer then has a short window to pick 3 cards.
@Observable
final class PartySession {
    static let minimumPlayerCount = 2
    static let maximumPlayerCount = 4

    /// iPad always offers the four-seat table, including narrow or rotated
    /// windows. Large, square-ish iPhone windows get the same option when
    /// their available footprint can support a player on every edge.
    static var playerCountOptions: [Int] {
        supportsFourPlayerMode(in: UIScreen.main.bounds.size)
            ? [minimumPlayerCount, maximumPlayerCount]
            : [minimumPlayerCount]
    }

    static var fourPlayerDeviceLabel: String {
        "one device"
    }

    static func supportsFourPlayerMode(
        in size: CGSize,
        userInterfaceIdiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) -> Bool {
        if userInterfaceIdiom == .pad {
            return true
        }

        let shortestSide = min(size.width, size.height)
        let longestSide = max(size.width, size.height)
        guard shortestSide >= 600 else { return false }
        return longestSide / shortestSide <= 1.5
    }

    static func isCompactFourPlayerWindow(in size: CGSize) -> Bool {
        supportsFourPlayerMode(in: size) && min(size.width, size.height) < 800
    }

    /// Game Center can fill any match from the minimum to the device's
    /// supported maximum. The protocol and host authority already handle the
    /// whole roster; this is only the matchmaking request's upper bound.
    static var matchmakingMaximumPlayerCount: Int {
        playerCountOptions.last ?? minimumPlayerCount
    }

    struct Player: Identifiable {
        let id: Int
        let name: String
        let color: Color
        var score = 0
        var collectedCards: [Card] = []
        var lockedUntil: Date?

        var cardCount: Int { collectedCards.count }
        var topCard: Card? { collectedCards.last }

        func isLocked(at now: Date) -> Bool {
            guard let lockedUntil else { return false }
            return lockedUntil > now
        }
    }

    /// Player colors deliberately share the themed card palette: P1 is the
    /// card red, P2 the card blue, and P3 the card yellow. P4 uses the
    /// documented soft semantic-success fallback in `Appearance` because
    /// the card deck has only three identity tints.
    static var palette: [(String, Color)] {
        [
            ("P1", Appearance.shared.playerColor(for: 0)),
            ("P2", Appearance.shared.playerColor(for: 1)),
            ("P3", Appearance.shared.playerColor(for: 2)),
            ("P4", Appearance.shared.playerColor(for: 3)),
        ]
    }

    let engine = GameEngine()
    private(set) var players: [Player]
    private(set) var lastCollectorID: Int?
    private(set) var penaltyToken = 0

    private var claimRace = ClaimRace<Int>()
    private var expiryTask: Task<Void, Never>?

    init(playerCount: Int) {
        let count = min(max(playerCount, Self.minimumPlayerCount), Self.maximumPlayerCount)
        players = (0..<count).map { i in
            Player(id: i, name: Self.palette[i].0, color: Self.palette[i].1)
        }
        lastCollectorID = nil
        engine.start()
    }

    var activePlayer: Player? {
        guard let activePlayerID else { return nil }
        return players.first { $0.id == activePlayerID }
    }

    var activePlayerID: Int? { claimRace.activePlayerID }
    var claimDeadline: Date? { claimRace.claimDeadline }

    var winners: [Player] {
        let top = players.map(\.score).max() ?? 0
        return players.filter { $0.score == top }
    }

    func canBuzz(_ id: Int, at now: Date = .now) -> Bool {
        guard !engine.isFinished, players.contains(where: { $0.id == id }) else { return false }
        return claimRace.canClaim(id, at: now)
    }

    func buzz(_ id: Int) {
        guard canBuzz(id), claimRace.claim(id) != nil else { return }
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ClaimRace<Int>.Configuration.standard.claimWindow))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.expireClaim() }
        }
    }

    /// Board taps route through here; ignored unless someone holds the claim.
    func select(_ card: Card) -> GameEngine.SelectionOutcome {
        guard let claimingPlayerID = activePlayerID else { return .pending }
        let outcome = engine.select(card)
        switch outcome {
        case .pending:
            break
        case .matched(let cards):
            lastCollectorID = claimingPlayerID
            award(cards: cards, to: claimingPlayerID)
            endClaim(heldBy: claimingPlayerID)
        case .mismatched:
            penalize(claimingPlayerID)
            endClaim(heldBy: claimingPlayerID)
        }
        return outcome
    }

    private func expireClaim() {
        guard let playerID = claimRace.expire() else { return }
        engine.clearSelection()
        expiryTask = nil
        penalize(playerID)
    }

    private func award(cards: [Card], to playerID: Int) {
        guard let i = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[i].score += 1
        players[i].collectedCards.append(contentsOf: cards)
    }

    private func penalize(_ playerID: Int) {
        guard let i = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[i].score = max(0, players[i].score - 1)
        // `ClaimRace` is the source of truth; the player carries this only
        // because the shared table presentation renders plain player values.
        players[i].lockedUntil = claimRace.penalize(playerID)
        penaltyToken += 1
    }

    private func endClaim(heldBy playerID: Int) {
        expiryTask?.cancel()
        expiryTask = nil
        _ = claimRace.releaseClaim(heldBy: playerID)
    }
}
