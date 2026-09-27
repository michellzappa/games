import Foundation
import MultipeerConnectivity
import Observation

/// Multi-device party with no internet: MultipeerConnectivity over
/// peer-to-peer Wi-Fi and Bluetooth. It works on a plane or underground, as
/// long as Wi-Fi or Bluetooth is on. It needs no Game Center sign-in.
///
/// One object is both the lobby and the transport. The host advertises and
/// accepts joiners; a joiner browses and asks one host to join. When the host
/// starts, every device hands this object to `NetworkPartySession`.
///
/// The host id starts with "0" and a joiner id with "1". The session makes
/// the lowest id host, so the device that opened the table runs the engine.
@Observable
final class NearbyParty: NSObject, PartyTransport {
    enum Role: Equatable {
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

    let role: Role
    let localID: String
    let localName: String
    let maximumPlayers: Int
    private(set) var members: [Member] = []
    private(set) var hosts: [FoundHost] = []
    private(set) var joinState: JoinState = .browsing
    private(set) var isStarted = false
    /// Set when the host a joiner waits for goes away.
    private(set) var hostLeft = false

    var onStart: (() -> Void)?
    var onData: ((Data, String) -> Void)? {
        didSet { flushPendingGameData() }
    }
    var onPlayerLeft: ((String) -> Void)?

    @ObservationIgnored private let peer: MCPeerID
    @ObservationIgnored private let session: MCSession
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// Peer ids arrive in a hello message after the connection opens.
    @ObservationIgnored private var peerIDs: [MCPeerID: String] = [:]
    @ObservationIgnored private var foundPeers: [String: MCPeerID] = [:]
    @ObservationIgnored private var pendingGameData: [(Data, String)] = []

    private enum Channel: UInt8 {
        case lobby = 0
        case game = 1
    }

    private enum LobbyMessage: Codable {
        case hello(id: String)
        case start
    }

    init(role: Role, name: String, maximumPlayers: Int) {
        self.role = role
        self.localID = (role == .hosting ? "0-" : "1-") + UUID().uuidString
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // MCPeerID rejects a display name over 63 bytes of UTF-8.
        var displayName = trimmed.isEmpty ? "Player" : trimmed
        while displayName.utf8.count > 63 { displayName.removeLast() }
        self.localName = displayName
        self.maximumPlayers = maximumPlayers
        peer = MCPeerID(displayName: displayName)
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self

        switch role {
        case .hosting:
            let advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: Self.serviceType)
            advertiser.delegate = self
            advertiser.startAdvertisingPeer()
            self.advertiser = advertiser
        case .joining:
            startBrowsing()
        }
    }

    var canStart: Bool {
        role == .hosting && !isStarted && members.count + 1 >= PartySession.minimumPlayerCount
    }

    // MARK: - Lobby

    func join(_ host: FoundHost) {
        guard role == .joining, let peer = foundPeers[host.id] else { return }
        joinState = .connecting(host.name)
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    /// Joiner: back to the host list after a failed join.
    func retry() {
        guard role == .joining else { return }
        hostLeft = false
        joinState = .browsing
    }

    /// Host: close the table and tell every device to start.
    func start() {
        guard canStart else { return }
        stopDiscovery()
        sendLobby(.start, to: session.connectedPeers)
        begin()
    }

    private func begin() {
        guard !isStarted else { return }
        isStarted = true
        stopDiscovery()
        onStart?()
    }

    private func startBrowsing() {
        let browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    private func stopDiscovery() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
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
        stopDiscovery()
        onData = nil
        onPlayerLeft = nil
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
            case .hello(let id):
                peerIDs[peer] = id
                if !members.contains(where: { $0.id == id }) {
                    members.append(Member(id: id, name: peer.displayName))
                }
                if role == .joining, id.hasPrefix("0-") {
                    joinState = .waiting(peer.displayName)
                }
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
        sendLobby(.hello(id: localID), to: [peer])
    }

    private func peerDisconnected(_ peer: MCPeerID) {
        guard let id = peerIDs.removeValue(forKey: peer) else {
            // A join that never finished.
            if role == .joining, case .connecting = joinState {
                joinState = .failed
            }
            return
        }
        members.removeAll { $0.id == id }
        if isStarted {
            onPlayerLeft?(id)
        } else if role == .joining, id.hasPrefix("0-") {
            hostLeft = true
            joinState = .failed
        }
    }
}

// MARK: - MultipeerConnectivity delegates

extension NearbyParty: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected: self.peerConnected(peerID)
            case .notConnected: self.peerDisconnected(peerID)
            case .connecting: break
            @unknown default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { self.receive(data, from: peerID) }
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
            let seats = self.session.connectedPeers.count + 1
            let accept = !self.isStarted && seats < self.maximumPlayers
            invitationHandler(accept, accept ? self.session : nil)
        }
    }
}

extension NearbyParty: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            let key = "\(peerID.hash)"
            self.foundPeers[key] = peerID
            if !self.hosts.contains(where: { $0.id == key }) {
                self.hosts.append(FoundHost(id: key, name: peerID.displayName))
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            let key = "\(peerID.hash)"
            self.foundPeers[key] = nil
            self.hosts.removeAll { $0.id == key }
        }
    }
}
