import SwiftUI
import Observation

/// Party mode across devices. The wire is a `PartyTransport`: a Game Center
/// match, or a local MultipeerConnectivity session with no internet.
///
/// The device with the lowest player id is the host and runs the only real
/// `GameEngine`. Clients render snapshots and send buzz/select events. Claim
/// window and lockout reuse the constants in `PartySession`.
@Observable
final class NetworkPartySession {
    struct PlayerDisplay: Identifiable {
        let id: String
        let name: String
        let color: Color
        var score: Int
        var cardCount: Int
        var topCard: Card?
        var lockedUntil: Date?

        func isLocked(at now: Date) -> Bool {
            guard let lockedUntil else { return false }
            return lockedUntil > now
        }
    }

    let transport: PartyTransport
    /// Not fixed for the life of the match. The lowest player id among the
    /// devices still connected is the host, so a host that leaves hands the
    /// role to the next device.
    private(set) var isHost: Bool
    let localID: String

    // Display state. On the host this mirrors the engine; on clients it is
    // whatever the last snapshot said.
    private(set) var players: [PlayerDisplay] = []
    private(set) var table: [Card] = []
    private(set) var selectedIDs: Set<Int> = []
    private(set) var mismatchIDs: Set<Int> = []
    private(set) var mismatchToken = 0
    private(set) var mismatchReasons: [String] = []
    private(set) var celebrationIDs: Set<Int> = []
    private(set) var matchToken = 0
    private(set) var dealToken = 0
    private(set) var penaltyToken = 0
    private(set) var deckCount = 0
    private(set) var doneCount = 0
    private(set) var doneTop: Card?
    private(set) var lastCollectorID: String? = nil
    private(set) var isFinished = false
    private(set) var someoneLeft = false

    // Host-only authority.
    private let engine = GameEngine()
    private var roster: [(id: String, name: String)] = []
    private var scores: [String: Int] = [:]
    private var collectedCards: [String: [Card]] = [:]
    private var claimRace = ClaimRace<String>()
    private var expiryTask: Task<Void, Never>?
    private var remoteHostID: String?
    /// Palette slots are pinned per player. A player who leaves must not
    /// recolor everyone behind them.
    private var colorIndexes: [String: Int] = [:]
    /// Clients keep the last snapshot so one of them can become host from it.
    private var lastSnapshot: NetSnapshot?

    init(transport: PartyTransport) {
        self.transport = transport
        localID = transport.localID
        let everyone = (transport.remotePlayers + [(id: transport.localID, name: transport.localName)])
            .sorted { $0.id < $1.id }
        let hostID = everyone.first?.id
        isHost = hostID == localID
        remoteHostID = isHost ? nil : hostID

        transport.onPlayerLeft = { [weak self] playerID in
            self?.playerLeft(playerID)
        }
        transport.onData = { [weak self] data, playerID in
            self?.receive(data, from: playerID)
        }

        if isHost {
            roster = everyone.map { ($0.id, $0.name) }
            for (index, entry) in roster.enumerated() {
                scores[entry.id] = 0
                collectedCards[entry.id] = []
                colorIndexes[entry.id] = index % PartySession.palette.count
            }
            engine.onAutoAdvance = { [weak self] in self?.publishAndBroadcast() }
            engine.start()
            publishAndBroadcast()
        }
    }

    var localPlayer: PlayerDisplay? {
        players.first { $0.id == localID }
    }

    var activePlayerID: String? { claimRace.activePlayerID }
    var claimDeadline: Date? { claimRace.claimDeadline }

    var winners: [PlayerDisplay] {
        let top = players.map(\.score).max() ?? 0
        return players.filter { $0.score == top }
    }

    func canBuzzLocally(at now: Date = .now) -> Bool {
        guard !isFinished else { return false }
        return claimRace.canClaim(localID, at: now)
    }

    func buzzLocal() {
        if isHost {
            handleBuzz(from: localID)
        } else {
            send(.event(.buzz))
        }
    }

    func selectLocal(_ card: Card) {
        guard activePlayerID == localID else { return }
        if isHost {
            handleSelect(from: localID, cardID: card.id)
        } else {
            send(.event(.select(card.id)))
        }
    }

    func leave() {
        expiryTask?.cancel()
        transport.disconnect()
    }

    // MARK: - Host authority

    private func handleBuzz(from playerID: String) {
        guard isHost,
              !engine.isFinished,
              roster.contains(where: { $0.id == playerID }),
              claimRace.claim(playerID) != nil
        else { return }
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ClaimRace<String>.Configuration.standard.claimWindow))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.expireClaim() }
        }
        publishAndBroadcast()
    }

    private func handleSelect(from playerID: String, cardID: Int) {
        guard isHost, activePlayerID == playerID else { return }
        guard let card = engine.table.first(where: { $0.id == cardID }) else { return }
        let claimingPlayerID = activePlayerID
        switch engine.select(card) {
        case .pending:
            break
        case .matched(let cards):
            lastCollectorID = claimingPlayerID
            scores[playerID, default: 0] += 1
            collectedCards[playerID, default: []].append(contentsOf: cards)
            endClaim(heldBy: playerID)
        case .mismatched:
            penalize(playerID)
            endClaim(heldBy: playerID)
        }
        publishAndBroadcast()
    }

    private func expireClaim() {
        guard isHost, let activePlayerID = claimRace.expire() else { return }
        engine.clearSelection()
        penalize(activePlayerID)
        expiryTask = nil
        publishAndBroadcast()
    }

    private func penalize(_ playerID: String) {
        scores[playerID] = max(0, (scores[playerID] ?? 0) - 1)
        _ = claimRace.penalize(playerID)
        penaltyToken += 1
    }

    private func endClaim(heldBy playerID: String) {
        expiryTask?.cancel()
        expiryTask = nil
        _ = claimRace.releaseClaim(heldBy: playerID)
    }

    /// Host: mirror the engine into the display fields, then broadcast.
    private func publishAndBroadcast() {
        table = engine.table
        selectedIDs = Set(engine.selection.map(\.id))
        mismatchIDs = engine.lastMismatch
        mismatchToken = engine.mismatchToken
        mismatchReasons = engine.mismatchReasons
        celebrationIDs = engine.celebrationIDs
        matchToken = engine.matchToken
        dealToken = engine.dealToken
        deckCount = engine.deck.count
        doneCount = engine.done.count
        doneTop = engine.done.last
        isFinished = engine.isFinished
        players = roster.map { entry in
            return PlayerDisplay(
                id: entry.id,
                name: entry.name,
                color: PartySession.palette[colorIndexes[entry.id] ?? 0].1,
                score: scores[entry.id] ?? 0,
                cardCount: collectedCards[entry.id]?.count ?? 0,
                topCard: collectedCards[entry.id]?.last,
                lockedUntil: claimRace.lockDeadline(for: entry.id)
            )
        }

        let now = Date.now
        let snapshot = NetSnapshot(
            players: roster.map { entry in
                NetSnapshot.PlayerState(
                    id: entry.id,
                    name: entry.name,
                    colorIndex: colorIndexes[entry.id] ?? 0,
                    score: scores[entry.id] ?? 0,
                    cardCount: collectedCards[entry.id]?.count ?? 0,
                    topCardID: collectedCards[entry.id]?.last?.id,
                    lockRemaining: claimRace.lockDeadline(for: entry.id).flatMap {
                        $0 > now ? $0.timeIntervalSince(now) : nil
                    },
                    collectedIDs: collectedCards[entry.id]?.map(\.id) ?? []
                )
            },
            tableIDs: table.map(\.id),
            outOfPlayIDs: engine.done.map(\.id) + Array(celebrationIDs),
            selectedIDs: Array(selectedIDs),
            mismatchIDs: Array(mismatchIDs),
            mismatchToken: mismatchToken,
            mismatchReasons: mismatchReasons,
            celebrationIDs: Array(celebrationIDs),
            matchToken: matchToken,
            dealToken: dealToken,
            penaltyToken: penaltyToken,
            deckCount: deckCount,
            doneCount: doneCount,
            doneTopID: doneTop?.id,
            lastCollectorID: lastCollectorID,
            activePlayerID: activePlayerID,
            claimRemaining: claimDeadline.map { $0.timeIntervalSince(now) },
            isFinished: isFinished
        )
        send(.snapshot(snapshot))
    }

    // MARK: - Wire

    private func send(_ message: NetMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        if isHost {
            transport.sendToAll(data)
        } else if let remoteHostID {
            transport.send(data, to: remoteHostID)
        }
    }

    private func receive(_ data: Data, from senderID: String) {
        guard let message = try? JSONDecoder().decode(NetMessage.self, from: data) else { return }
        switch message {
        case .event(let event):
            guard isHost else { return }
            switch event {
            case .buzz:
                handleBuzz(from: senderID)
            case .select(let cardID):
                handleSelect(from: senderID, cardID: cardID)
            }
        case .snapshot(let snapshot):
            guard !isHost else { return }
            apply(snapshot)
        }
    }

    /// Client: adopt the host's snapshot, mapping remaining-times onto the
    /// local clock.
    private func apply(_ snapshot: NetSnapshot) {
        let now = Date.now
        var lockDeadlines: [String: Date] = [:]
        players = snapshot.players.map { state in
            let lockDeadline = state.lockRemaining.map { now.addingTimeInterval($0) }
            if let lockDeadline {
                lockDeadlines[state.id] = lockDeadline
            }
            return PlayerDisplay(
                id: state.id,
                name: state.name,
                color: PartySession.palette[state.colorIndex].1,
                score: state.score,
                cardCount: state.cardCount,
                topCard: state.topCardID.map { Card(id: $0) },
                lockedUntil: lockDeadline
            )
        }
        table = snapshot.tableIDs.map { Card(id: $0) }
        selectedIDs = Set(snapshot.selectedIDs)
        mismatchIDs = Set(snapshot.mismatchIDs)
        mismatchToken = snapshot.mismatchToken
        mismatchReasons = snapshot.mismatchReasons
        celebrationIDs = Set(snapshot.celebrationIDs)
        matchToken = snapshot.matchToken
        dealToken = snapshot.dealToken
        penaltyToken = snapshot.penaltyToken
        deckCount = snapshot.deckCount
        doneCount = snapshot.doneCount
        doneTop = snapshot.doneTopID.map { Card(id: $0) }
        lastCollectorID = snapshot.lastCollectorID
        claimRace.adoptAuthoritativeState(
            activePlayerID: snapshot.activePlayerID,
            claimDeadline: snapshot.claimRemaining.map { now.addingTimeInterval($0) },
            lockDeadlines: lockDeadlines
        )
        isFinished = snapshot.isFinished
        lastSnapshot = snapshot
    }

    // MARK: - Leaving and host migration

    /// Every device still in the match, lowest player id first. The first
    /// entry is the host.
    private func connectedIDs(excluding leaver: String? = nil) -> [String] {
        var ids = transport.remotePlayers.map(\.id) + [localID]
        if let leaver {
            ids.removeAll { $0 == leaver }
        }
        return ids.sorted()
    }

    private func playerLeft(_ playerID: String) {
        guard !someoneLeft, !isFinished else { return }
        let remaining = connectedIDs(excluding: playerID)
        // A table needs two. Below that the game ends, as it always did.
        guard remaining.count >= PartySession.minimumPlayerCount else {
            expiryTask?.cancel()
            expiryTask = nil
            someoneLeft = true
            return
        }
        if isHost {
            dropFromRoster(playerID)
            publishAndBroadcast()
        } else {
            adoptHost(remaining)
        }
    }

    /// Host: a player left. Their cards stay out of play, so the deck math is
    /// unchanged; only their seat goes away.
    private func dropFromRoster(_ playerID: String) {
        roster.removeAll { $0.id == playerID }
        scores[playerID] = nil
        collectedCards[playerID] = nil
        colorIndexes[playerID] = nil
        if claimRace.activePlayerID == playerID {
            expiryTask?.cancel()
            expiryTask = nil
            _ = claimRace.releaseClaim(heldBy: playerID)
            engine.clearSelection()
        }
    }

    /// Client: point at whoever is host now, and take the role if it is this
    /// device.
    private func adoptHost(_ remaining: [String]) {
        guard let hostID = remaining.first else {
            someoneLeft = true
            return
        }
        remoteHostID = hostID == localID ? nil : hostID
        guard hostID == localID else { return }
        promoteToHost(connected: Set(remaining))
    }

    /// Rebuild authority from the last snapshot. Everything needed is public
    /// information: the table, the cards out of play, and each player's pile.
    /// The remaining deck is reshuffled here because its order never crossed
    /// the wire, and nobody has seen it.
    private func promoteToHost(connected: Set<String>) {
        guard let snapshot = lastSnapshot else {
            someoneLeft = true
            return
        }
        let survivors = snapshot.players.filter { connected.contains($0.id) }
        guard survivors.count >= PartySession.minimumPlayerCount else {
            someoneLeft = true
            return
        }

        roster = survivors.map { ($0.id, $0.name) }
        scores = [:]
        collectedCards = [:]
        colorIndexes = [:]
        for state in survivors {
            scores[state.id] = state.score
            collectedCards[state.id] = state.collectedIDs.map(Card.init(id:))
            colorIndexes[state.id] = state.colorIndex
        }

        let celebrating = Set(snapshot.celebrationIDs)
        let tableCards = snapshot.tableIDs.map(Card.init(id:))
        let doneCards = snapshot.outOfPlayIDs
            .filter { !celebrating.contains($0) }
            .map(Card.init(id:))
        var unavailable = Set(snapshot.outOfPlayIDs)
        unavailable.formUnion(snapshot.tableIDs)
        let deckCards = Card.fullDeck.filter { !unavailable.contains($0.id) }.shuffled()

        engine.onAutoAdvance = { [weak self] in self?.publishAndBroadcast() }
        engine.adoptAsHost(
            table: tableCards,
            done: doneCards,
            deck: deckCards,
            celebrating: celebrating,
            matchToken: snapshot.matchToken,
            mismatchToken: snapshot.mismatchToken,
            dealToken: snapshot.dealToken
        )
        // No claim survives the handover. A buzz in flight to a device that is
        // gone would otherwise hold the table for its full window.
        claimRace.adoptAuthoritativeState(
            activePlayerID: nil,
            claimDeadline: nil,
            lockDeadlines: [:]
        )
        expiryTask?.cancel()
        expiryTask = nil
        penaltyToken = snapshot.penaltyToken
        lastCollectorID = snapshot.lastCollectorID
        remoteHostID = nil
        isHost = true
        publishAndBroadcast()
    }
}
