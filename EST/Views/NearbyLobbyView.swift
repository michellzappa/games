import GameKit
import GameShell
import SwiftUI

/// The lobby for a party with no internet. One device hosts a table, the
/// others join it, and the host starts when everyone is in.
struct NearbyLobbyView: View {
    let maximumPlayers: Int
    var onStart: (NearbyParty) -> Void
    var onCancel: () -> Void

    @AppStorage("nearbyPlayerName") private var name = ""
    @State private var party: NearbyParty?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let party {
                        switch party.role {
                        case .hosting: hostingContent(party)
                        case .joining: joiningContent(party)
                        }
                    } else {
                        chooseRole
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
        }
        .onDisappear {
            if let party, !party.isStarted {
                party.disconnect()
            }
        }
    }

    // MARK: - Choose

    private var chooseRole: some View {
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
                .frame(height: 50)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                open(.hosting)
            } label: {
                Label("Host a table", systemImage: "person.3.fill")
            }
            .buttonStyle(.game(.primary, tint: .first, size: .large))

            Button {
                open(.joining)
            } label: {
                Label("Join a table", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.game(.secondary, tint: .second, size: .large))
        }
    }

    // MARK: - Host

    private func hostingContent(_ party: NearbyParty) -> some View {
        VStack(spacing: 16) {
            Text("Your table is open")
                .font(.title3.weight(.bold))
            Text("Other players open Play nearby, tap Join a table, and pick \(party.localName).")
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
        }
    }

    // MARK: - Join

    @ViewBuilder
    private func joiningContent(_ party: NearbyParty) -> some View {
        switch party.joinState {
        case .browsing:
            VStack(spacing: 16) {
                Text("Pick a table")
                    .font(.title3.weight(.bold))
                if party.hosts.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Looking for tables nearby")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 50)
                    Text("Ask the host to tap Host a table.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(party.hosts) { host in
                        Button {
                            party.join(host)
                        } label: {
                            Label(host.name, systemImage: "person.fill")
                        }
                        .buttonStyle(.game(.secondary, tint: .first, size: .medium))
                    }
                }
            }
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

    private func open(_ role: NearbyParty.Role) {
        let party = NearbyParty(role: role, name: name, maximumPlayers: maximumPlayers)
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
