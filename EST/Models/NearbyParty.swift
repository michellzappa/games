import Foundation
import MultipeerConnectivity
import Observation

/// Multi-device party with no internet: MultipeerConnectivity over
/// peer-to-peer Wi-Fi and Bluetooth. It works on a plane or underground, as
/// long as Wi-Fi or Bluetooth is on. It needs no Game Center sign-in.
///
/// One object is both the lobby and the transport. It opens in the lobby,
/// where it browses for tables. From there the player either joins a table
/// it found or hosts one. When the host starts, every device hands this
/// object to `NetworkPartySession`.
///
/// The host id starts with "0" and a joiner id with "1". The session makes
/// the lowest id host, so the device that opened the table runs the engine.
///
/// Reliability rules, learned on real phones:
/// - The `MCPeerID` is stored and reused. A fresh peer id each time leaves a
///   stale copy of the same device in other browsers, and an invitation to
///   the stale copy fails.
/// - A join retries on a fresh `MCSession` before it reports a failure. The
///   first invitation over a new peer-to-peer link fails often.
/// - A device that drops during a game gets `reconnectGrace` seconds to come
///   back before the session sees it leave. The host advertises again and
///   the joiner invites the host again, with its player id as context.
@Observable
final class NearbyParty: NSObject, PartyTransport {
    enum Role: Equatable {
        case lobby
        case hosting
        case joining
    }

    enum JoinState: Equatable {
        case browsing
        case connecting(String)
        case waiting(String)
        case failed
    }

    struct Member: Identifiable, Equatable {
        let id: String
        let name: String
    }

    struct FoundHost: Identifiable, Equatable {
        let id: String
        let name: String
    }

    /// Bonjour service type. Must match `NSBonjourServices` in Info.plist.
    static let serviceType = "est-party"
    /// Seconds a dropped device has to reconnect during a game.
    static let reconnectGrace: TimeInterval = 15
    /// Invitations per join before the lobby shows a failure.
    private static let joinAttempts = 3
    private static let inviteTimeout: TimeInterval = 10
    private static let peerIDKey = "nearbyPeerID"
    /// Discovery info a host sets while a game runs, so lobbies hide it.
    private static let playingInfo = ["state": "playing"]

    private(set) var role: Role = .lobby
    private(set) var localID: String
    private(set) var localName: String
    let maximumPlayers: Int
    private(set) var members: [Member] = []
    private(set) var hosts: [FoundHost] = []
    private(set) var joinState: JoinState = .browsing
    private(set) var isStarted = false
    /// Set when the host a joiner waits for goes away.
    private(set) var hostLeft = false
    /// Player ids that dropped during the game and may still come back.
    private(set) var reconnectingIDs: Set<String> = []

    var onStart: (() -> Void)?
    var onData: ((Data, String) -> Void)? {
        didSet { flushPendingGameData() }
    }
    var onPlayerLeft: ((String) -> Void)?
    var onPlayerReturned: ((String) -> Void)?

    @ObservationIgnored private var peer: MCPeerID
    @ObservationIgnored private var session: MCSession
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// Peer ids arrive in a hello message after the connection opens.
    @ObservationIgnored private var peerIDs: [MCPeerID: String] = [:]
    @ObservationIgnored private var foundPeers: [String: MCPeerID] = [:]
    @ObservationIgnored private var pendingGameData: [(Data, String)] = []
    /// Joiner: the host peer it joins, kept for retries and reconnects.
    @ObservationIgnored private var hostPeer: MCPeerID?
    @ObservationIgnored private var hostName = ""
    @ObservationIgnored private var attemptsLeft = 0
    /// Every player id that was in the game. Only these may reconnect.
    @ObservationIgnored private var gameIDs: Set<String> = []
    @ObservationIgnored private var graceTimers: [String: DispatchWorkItem] = [:]

    private enum Channel: UInt8 {
        case lobby = 0
        case game = 1
    }

    /// `name` is optional so builds that send only an id still decode.
    private enum LobbyMessage: Codable {
        case hello(id: String, name: String?)
        case start
    }

    init(name: String, maximumPlayers: Int) {
        let displayName = Self.displayName(for: name)
        self.localName = displayName
        self.localID = "1-" + UUID().uuidString
        self.maximumPlayers = maximumPlayers
        peer = Self.storedPeerID(named: displayName)
        session = Self.makeSession(peer: peer)
        super.init()
        session.delegate = self
        startBrowsing()
    }

    var canStart: Bool {
        role == .hosting && !isStarted && members.count + 1 >= PartySession.minimumPlayerCount
    }

    // MARK: - Lobby

    /// Open a table under `name`. Browsing stops; this device advertises.
    func host(name: String) {
        guard role == .lobby else { return }
        stopBrowsing()
        hosts = []
        foundPeers = [:]
        rename(name)
        localID = "0-" + UUID().uuidString
        role = .hosting
        startAdvertising(playing: false)
    }

    /// Host: close the table and go back to the list of tables.
    func closeTable() {
        guard role == .hosting, !isStarted else { return }
        stopAdvertising()
        resetSession()
        members = []
        localID = "1-" + UUID().uuidString
        role = .lobby
        startBrowsing()
    }

    func join(_ host: FoundHost, name: String) {
        guard role == .lobby, let target = foundPeers[host.id] else { return }
        localName = Self.displayName(for: name)
        role = .joining
        hostLeft = false
        hostPeer = target
        hostName = host.name
        attemptsLeft = Self.joinAttempts
        joinState = .connecting(host.name)
        invite(target)
    }

    /// Joiner: back to the list of tables, after a failure or by choice.
    func backToTables() {
        guard role == .joining, !isStarted else { return }
        resetSession()
        members = []
        hostPeer = nil
        hostLeft = false
        role = .lobby
        joinState = .browsing
        if browser == nil { startBrowsing() }
    }

    /// Joiner: try the same table again if it is still visible.
    func retry() {
        guard role == .joining, !isStarted else { return }
        let target = hosts.first { $0.name == hostName }
        backToTables()
        if let target {
            join(target, name: localName)
        }
    }

    /// Host: close the table and tell every device to start.
    func start() {
        guard canStart else { return }
        stopAdvertising()
        sendLobby(.start, to: session.connectedPeers)
        begin()
    }

    private func begin() {
        guard !isStarted else { return }
        isStarted = true
        gameIDs = Set(members.map(\.id))
        stopAdvertising()
        stopBrowsing()
        onStart?()
    }

    private func rename(_ name: String) {
        let displayName = Self.displayName(for: name)
        localName = displayName
        // Other devices see the peer's display name in their table list,
        // so a host with a new name needs a new peer.
        guard displayName != peer.displayName, session.connectedPeers.isEmpty else { return }
        peer = Self.storedPeerID(named: displayName)
        resetSession()
    }

    // MARK: - Discovery

    private func startBrowsing() {
        stopBrowsing()
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    private func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    private func startAdvertising(playing: Bool) {
        stopAdvertising()
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peer,
            discoveryInfo: playing ? Self.playingInfo : nil,
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    private func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Session

    private static func makeSession(peer: MCPeerID) -> MCSession {
        // `.optional` still encrypts against a build that requires it, and
        // avoids the handshake failures that `.required` adds on its own.
        MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .optional)
    }

    /// A fresh session. A session that failed an invitation can keep failing.
    private func resetSession() {
        session.delegate = nil
        session.disconnect()
        peerIDs = [:]
        session = Self.makeSession(peer: peer)
        session.delegate = self
    }

    private func invite(_ target: MCPeerID) {
        attemptsLeft -= 1
        let context = localID.data(using: .utf8)
        browser?.invitePeer(target, to: session, withContext: context, timeout: Self.inviteTimeout)
    }

    /// MCPeerID rejects a display name over 63 bytes of UTF-8.
    private static func displayName(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var displayName = trimmed.isEmpty ? "Player" : trimmed
        while displayName.utf8.count > 63 { displayName.removeLast() }
        return displayName
    }

    /// Apple's guidance: reuse one peer id per display name across launches.
    private static func storedPeerID(named name: String) -> MCPeerID {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: peerIDKey),
           let stored = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data),
           stored.displayName == name {
            return stored
        }
        let peer = MCPeerID(displayName: name)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: peer, requiringSecureCoding: true) {
            defaults.set(data, forKey: peerIDKey)
        }
        return peer
    }

    // MARK: - PartyTransport

    var remotePlayers: [(id: String, name: String)] {
        members.map { ($0.id, $0.name) }
    }

    func sendToAll(_ data: Data) {
        send(frame(.game, data), to: session.connectedPeers)
    }

    func send(_ data: Data, to playerID: String) {
        let peers = peerIDs.filter { $0.value == playerID }.map(\.key)
        send(frame(.game, data), to: peers)
    }

    func disconnect() {
        stopAdvertising()
        stopBrowsing()
        graceTimers.values.forEach { $0.cancel() }
        graceTimers = [:]
        onData = nil
        onPlayerLeft = nil
        onPlayerReturned = nil
        onStart = nil
        session.delegate = nil
        session.disconnect()
    }

    // MARK: - Wire

    private func frame(_ channel: Channel, _ data: Data) -> Data {
        var framed = Data([channel.rawValue])
        framed.append(data)
        return framed
    }

    private func send(_ framed: Data, to peers: [MCPeerID]) {
        guard !peers.isEmpty else { return }
        try? session.send(framed, toPeers: peers, with: .reliable)
    }

    private func sendLobby(_ message: LobbyMessage, to peers: [MCPeerID]) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        send(frame(.lobby, data), to: peers)
    }

    private func receive(_ framed: Data, from peer: MCPeerID) {
        guard let first = framed.first, let channel = Channel(rawValue: first) else { return }
        let body = framed.dropFirst()
        switch channel {
        case .lobby:
            guard let message = try? JSONDecoder().decode(LobbyMessage.self, from: Data(body)) else { return }
            switch message {
            case .hello(let id, let name):
                hello(id: id, name: name ?? peer.displayName, from: peer)
            case .start:
                guard role == .joining else { return }
                begin()
            }
        case .game:
            guard let id = peerIDs[peer] else { return }
            if let onData {
                onData(Data(body), id)
            } else {
                pendingGameData.append((Data(body), id))
            }
        }
    }

    private func hello(id: String, name: String, from peer: MCPeerID) {
        peerIDs[peer] = id
        if !members.contains(where: { $0.id == id }) {
            members.append(Member(id: id, name: name))
        }
        if isStarted {
            guard reconnectingIDs.contains(id) else { return }
            graceTimers.removeValue(forKey: id)?.cancel()
            reconnectingIDs.remove(id)
            if reconnectingIDs.isEmpty { stopReconnecting() }
            onPlayerReturned?(id)
        } else if role == .joining, id.hasPrefix("0-") {
            joinState = .waiting(name)
        }
    }

    /// The first snapshot can arrive before the session installs its handler.
    private func flushPendingGameData() {
        guard let onData, !pendingGameData.isEmpty else { return }
        let pending = pendingGameData
        pendingGameData = []
        for (data, id) in pending {
            onData(data, id)
        }
    }

    private func peerConnected(_ peer: MCPeerID) {
        sendLobby(.hello(id: localID, name: localName), to: [peer])
    }

    private func peerDisconnected(_ peer: MCPeerID) {
        guard let id = peerIDs.removeValue(forKey: peer) else {
            joinAttemptFailed(peer)
            return
        }
        if isStarted {
            startGrace(for: id)
            return
        }
        members.removeAll { $0.id == id }
        if role == .joining, id.hasPrefix("0-") {
            hostLeft = true
            joinState = .failed
        }
    }

    /// Joiner: an invitation that never reached hello. Retry on a fresh
    /// session until the attempts run out.
    private func joinAttemptFailed(_ peer: MCPeerID) {
        if isStarted, reconnectingIDs.contains(where: { $0.hasPrefix("0-") }), peer == hostPeer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self, self.reconnectingIDs.contains(where: { $0.hasPrefix("0-") }) else { return }
                self.invite(peer)
            }
            return
        }
        guard role == .joining, !isStarted, case .connecting = joinState, peer == hostPeer else { return }
        guard attemptsLeft > 0 else {
            joinState = .failed
            return
        }
        resetSession()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, case .connecting = self.joinState, let target = self.hostPeer else { return }
            self.invite(target)
        }
    }

    // MARK: - Reconnect during a game

    private func startGrace(for id: String) {
        reconnectingIDs.insert(id)
        let timer = DispatchWorkItem { [weak self] in
            self?.graceExpired(for: id)
        }
        graceTimers[id]?.cancel()
        graceTimers[id] = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reconnectGrace, execute: timer)

        if role == .hosting {
            if advertiser == nil { startAdvertising(playing: true) }
        } else if id.hasPrefix("0-"), hostPeer != nil {
            // A fresh browser reports the host again when it comes back.
            startBrowsing()
        }
    }

    private func graceExpired(for id: String) {
        graceTimers[id] = nil
        guard reconnectingIDs.remove(id) != nil else { return }
        if reconnectingIDs.isEmpty { stopReconnecting() }
        members.removeAll { $0.id == id }
        onPlayerLeft?(id)
    }

    private func stopReconnecting() {
        stopAdvertising()
        stopBrowsing()
    }
}

// MARK: - MultipeerConnectivity delegates

extension NearbyParty: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            // Callbacks from a session this object already replaced.
            guard session === self.session else { return }
            switch state {
            case .connected: self.peerConnected(peerID)
            case .notConnected: self.peerDisconnected(peerID)
            case .connecting: break
            @unknown default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            guard session === self.session else { return }
            self.receive(data, from: peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbyParty: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        DispatchQueue.main.async {
            let accept: Bool
            if self.isStarted {
                // Only a player who dropped from this game may come back.
                let id = context.flatMap { String(data: $0, encoding: .utf8) }
                accept = id.map { self.gameIDs.contains($0) && self.reconnectingIDs.contains($0) } ?? false
            } else {
                let seats = self.session.connectedPeers.count + 1
                accept = self.role == .hosting && seats < self.maximumPlayers
            }
            invitationHandler(accept, accept ? self.session : nil)
        }
    }
}

extension NearbyParty: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            guard browser === self.browser, peerID != self.peer else { return }
            if self.isStarted {
                // Reconnect: invite the host this device played with.
                if peerID == self.hostPeer, self.reconnectingIDs.contains(where: { $0.hasPrefix("0-") }) {
                    self.invite(peerID)
                }
                return
            }
            // A table with a game running takes no new players.
            guard info != Self.playingInfo else { return }
            let key = "\(peerID.hash)"
            self.foundPeers[key] = peerID
            // A device can show up twice under one name for a moment, when a
            // stale advertisement lingers. Keep the newest.
            if let stale = self.hosts.first(where: { $0.name == peerID.displayName && $0.id != key }) {
                self.foundPeers[stale.id] = nil
                self.hosts.removeAll { $0.id == stale.id }
            }
            if !self.hosts.contains(where: { $0.id == key }) {
                self.hosts.append(FoundHost(id: key, name: peerID.displayName))
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            guard browser === self.browser else { return }
            let key = "\(peerID.hash)"
            self.foundPeers[key] = nil
            self.hosts.removeAll { $0.id == key }
        }
    }
}
