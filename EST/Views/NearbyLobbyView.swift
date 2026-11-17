import GameKit
import GameShell
import SwiftUI

/// The lobby for a party with no internet. One page lists the tables nearby
/// and has a Host button under the list. The list always keeps room for one
/// row, so the button stays in place unless two or more tables show up.
struct NearbyLobbyView: View {
    let maximumPlayers: Int
    var onStart: (NearbyParty) -> Void
    var onCancel: () -> Void

    @AppStorage("nearbyPlayerName") private var name = ""
    @State private var party: NearbyParty?

    private static let rowHeight: CGFloat = 50

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let party {
                        switch party.role {
                        case .lobby: lobbyContent(party)
                        case .hosting: hostingContent(party)
                        case .joining: joiningContent(party)
                        }
                    }
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .padding(24)
            }
            .background(Appearance.shared.gameBackground)
            .navigationTitle("Play nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
            }
        }
        .onAppear {
            if name.isEmpty, GKLocalPlayer.local.isAuthenticated {
                name = GKLocalPlayer.local.displayName
            }
            if party == nil {
                open()
            }
        }
        .onDisappear {
            if let party, !party.isStarted {
                party.disconnect()
            }
        }
    }

    // MARK: - Lobby

    private func lobbyContent(_ party: NearbyParty) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(GameAccent.first.color)
            Text("No internet needed. Phones and iPads find each other over Wi-Fi and Bluetooth. On a plane, turn Wi-Fi or Bluetooth back on after airplane mode.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Your name", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.horizontal, 16)
                .frame(height: Self.rowHeight)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Tables nearby")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                if party.hosts.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Looking for tables")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: Self.rowHeight)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ForEach(party.hosts) { host in
                        tableRow(host, in: party)
                    }
                }
            }

            Button {
                party.host(name: name)
            } label: {
                Label("Host a table", systemImage: "person.3.fill")
            }
            .buttonStyle(.game(.primary, tint: .first, size: .large))
        }
        .animation(.default, value: party.hosts)
    }

    private func tableRow(_ host: NearbyParty.FoundHost, in party: NearbyParty) -> some View {
        Button {
            party.join(host, name: name)
        } label: {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(GameAccent.first.color)
                Text(host.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(GameAccent.second.color)
            }
            .padding(.horizontal, 16)
            .frame(height: Self.rowHeight)
            .contentShape(Rectangle())
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Host

    private func hostingContent(_ party: NearbyParty) -> some View {
        VStack(spacing: 16) {
            Text("Your table is open")
                .font(.title3.weight(.bold))
            Text("Other players open Play nearby and pick \(party.localName).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                playerRow(party.localName, detail: "You")
                ForEach(party.members) { member in
                    playerRow(member.name, detail: "Joined")
                }
                if party.members.count + 1 < party.maximumPlayers {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Waiting for players")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                }
            }

            Button {
                party.start()
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .buttonStyle(.game(.primary, tint: .first, size: .large))
            .disabled(!party.canStart)

            Button("Close table") {
                party.closeTable()
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    // MARK: - Join

    @ViewBuilder
    private func joiningContent(_ party: NearbyParty) -> some View {
        switch party.joinState {
        case .browsing:
            EmptyView()
        case .connecting(let hostName):
            statusContent(title: "Joining \(hostName)", showsProgress: true)
        case .waiting(let hostName):
            statusContent(title: "You're in", detail: "Waiting for \(hostName) to start.", showsProgress: true)
        case .failed:
            VStack(spacing: 16) {
                statusContent(
                    title: party.hostLeft ? "The host left" : "Could not join",
                    detail: "Check that both devices have Wi-Fi or Bluetooth on.",
                    showsProgress: false
                )
                Button {
                    party.retry()
                } label: {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.game(.primary, tint: .first, size: .large))

                Button("Tables nearby") {
                    party.backToTables()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func statusContent(title: String, detail: String? = nil, showsProgress: Bool) -> some View {
        VStack(spacing: 12) {
            if showsProgress {
                ProgressView()
            }
            Text(title)
                .font(.title3.weight(.bold))
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 24)
    }

    private func playerRow(_ name: String, detail: String) -> some View {
        HStack {
            Image(systemName: "person.fill")
                .foregroundStyle(GameAccent.first.color)
            Text(name)
                .font(.body.weight(.semibold))
            Spacer()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Actions

    private func open() {
        let party = NearbyParty(name: name, maximumPlayers: maximumPlayers)
        party.onStart = { [weak party] in
            guard let party else { return }
            onStart(party)
        }
        self.party = party
    }

    private func cancel() {
        party?.disconnect()
        party = nil
        onCancel()
    }
}
