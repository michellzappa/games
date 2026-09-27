import Foundation
import GameKit

/// The wire under a multi-device party. `NetworkPartySession` runs the same
/// rules over either transport: a Game Center match, or a local
/// MultipeerConnectivity session that needs no internet.
///
/// Player ids are opaque strings. The session sorts them, and the lowest id
/// among connected devices is host, so every transport must give each device
/// an id that all peers agree on.
protocol PartyTransport: AnyObject {
    var localID: String { get }
    var localName: String { get }
    /// Remote devices connected now.
    var remotePlayers: [(id: String, name: String)] { get }
    /// Called on the main queue.
    var onData: ((Data, String) -> Void)? { get set }
    /// Called on the main queue when a remote device disconnects.
    var onPlayerLeft: ((String) -> Void)? { get set }
    func sendToAll(_ data: Data)
    func send(_ data: Data, to playerID: String)
    func disconnect()
}

/// A Game Center match, online or Game Center nearby.
final class GameCenterTransport: NSObject, PartyTransport, GKMatchDelegate {
    let match: GKMatch
    let localID = GKLocalPlayer.local.gamePlayerID
    let localName = GKLocalPlayer.local.displayName
    var onData: ((Data, String) -> Void)?
    var onPlayerLeft: ((String) -> Void)?

    init(match: GKMatch) {
        self.match = match
        super.init()
        match.delegate = self
    }

    var remotePlayers: [(id: String, name: String)] {
        match.players.map { ($0.gamePlayerID, $0.displayName) }
    }

    func sendToAll(_ data: Data) {
        try? match.sendData(toAllPlayers: data, with: .reliable)
    }

    func send(_ data: Data, to playerID: String) {
        guard let player = match.players.first(where: { $0.gamePlayerID == playerID }) else { return }
        try? match.send(data, to: [player], dataMode: .reliable)
    }

    func disconnect() {
        match.delegate = nil
        match.disconnect()
    }

    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        let id = player.gamePlayerID
        DispatchQueue.main.async { self.onData?(data, id) }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        guard state == .disconnected else { return }
        let id = player.gamePlayerID
        DispatchQueue.main.async { self.onPlayerLeft?(id) }
    }
}
