import GameShell
import SwiftUI

struct SEEPSettingsView: View {
    @AppStorage("immersiveGameMode") private var immersiveGameMode = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @State private var showReset = false

    private static let about = SettingsAbout(
        description: "A free, open-source flood-fill puzzle by Michell Zappa at Centaur Labs.",
        sourceCodeURL: URL(string: "https://github.com/michellzappa/games")!
    )

    var body: some View {
        SettingsView(about: Self.about) {
        } game: {
            Section("Game") {
                Toggle("Immersive game mode", isOn: $immersiveGameMode)
                Text("Hides the status bar and Game Center button while playing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Toggle("Keep screen awake", isOn: $keepScreenAwake)
            }
            Section("Data") {
                Button("Reset progress", role: .destructive) { showReset = true }
                Text("Clears board progress, stars, streaks and play-style stats on this device. Game Center scores are not affected.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } afterPrivacy: {
        }
        .confirmationDialog("Reset progress?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { SEEPStats.shared.reset() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
