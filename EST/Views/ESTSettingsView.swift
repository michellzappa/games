import GameShell
import SwiftUI

/// EST's settings: the shell Form plus the card fill, game options, data,
/// and Community Pulse.
struct ESTSettingsView: View {
    @Bindable private var cardAppearance = CardAppearance.shared
    @AppStorage("immersiveGameMode") private var immersiveGameMode = true
    @AppStorage("showSoloTimer") private var showSoloTimer = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @AppStorage("bestSoloTime") private var bestSoloTime: Double = 0
    @AppStorage("bestQuickTime") private var bestQuickTime: Double = 0
    @AppStorage(ESTTelemetry.enabledKey) private var telemetryEnabled = true
    @State private var showResetStatsConfirmation = false
    @State private var showPlayStyle = false

    private static let about = SettingsAbout(
        description: "A free, open-source iPhone game by Michell Zappa at Centaur Labs, inspired by SET.",
        sourceCodeURL: URL(string: "https://github.com/michellzappa/games")!
    )

    var body: some View {
        SettingsView(about: Self.about, confetti: { AnyView(ConfettiView.cards()) }) {
            fillSection
        } game: {
            gameSection
            dataSection
        } afterPrivacy: {
            if telemetryEnabled {
                Section("Community Pulse") {
                    CommunityPulseView()
                }
            }
        }
        .sheet(isPresented: $showPlayStyle) {
            PlayStyleView()
        }
        .confirmationDialog(
            "Reset local stats?",
            isPresented: $showResetStatsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset stats", role: .destructive) {
                bestSoloTime = 0
                bestQuickTime = 0
                PlayerStats.shared.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes personal bests and private learning stats from this device.")
        }
    }

    private var fillSection: some View {
        Section("Fill") {
            Picker("Fill style", selection: $cardAppearance.fillStyle) {
                ForEach(CardAppearance.FillStyle.allCases, id: \.self) { style in
                    Text(style.name).tag(style)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                CardView(card: Card(count: 1, tint: .red, symbol: .circle, fill: .translucent))
                CardView(card: Card(count: 2, tint: .blue, symbol: .square, fill: .translucent))
                CardView(card: Card(count: 3, tint: .yellow, symbol: .triangle, fill: .translucent))
            }
            .frame(height: 72)
            .frame(maxWidth: .infinity)
        }
    }

    private var gameSection: some View {
        Section("Game") {
            Toggle("Immersive game mode", isOn: $immersiveGameMode)
            Text("Hides the iPhone status bar and Game Center button while playing.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Show solo timer", isOn: $showSoloTimer)
            Text("Hides the live clock in Solo 81 and Quick 27 when turned off. Your time is still recorded.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Keep screen awake", isOn: $keepScreenAwake)
            Text("Prevents the display from sleeping while EST is open.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button {
                showPlayStyle = true
            } label: {
                HStack {
                    Text("Your play style")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(.secondary)
                }
            }

            Button("Reset local stats", role: .destructive) {
                showResetStatsConfirmation = true
            }
            Text("Clears personal bests and private play-style stats on this device. Game Center scores are not affected.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CommunityPulseView: View {
    /// One row, three states. The state must not live in the branch structure:
    /// a `Group` applies `.task` to each branch, so a branch switch tears the
    /// row down and cancels the fetch that caused the switch.
    private enum Phase {
        case loading
        case loaded(ESTCommunityStats)
        case unavailable
    }

    @State private var phase = Phase.loading
    @State private var isRefreshing = false
    @State private var reloadID = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch phase {
            case .loading:
                HStack {
                    ProgressView()
                    Text("Loading community activity…")
                        .foregroundStyle(.secondary)
                }
            case .loaded(let stats):
                statsContent(stats)
            case .unavailable:
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        ESTTelemetry.communityEndpoint == nil
                            ? "Community Pulse is not configured"
                            : "Community activity is unavailable",
                        systemImage: "chart.xyaxis.line"
                    )
                    Text(
                        ESTTelemetry.communityEndpoint == nil
                            ? "This source build has no telemetry endpoint."
                            : "Try again when you have a connection."
                    )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Try again") {
                        reloadID += 1
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: reloadID) {
            await reload(id: reloadID)
        }
    }

    @ViewBuilder
    private func statsContent(_ stats: ESTCommunityStats) -> some View {
        if let latest = stats.latest {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(latest.inProgress ? "Week to date" : "Latest reported week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(latest.period)
                        .font(.headline)
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        metric("Active devices", latest.reportingDevices)
                        metric("Games started", latest.activity.gamesStarted)
                    }
                    HStack(spacing: 10) {
                        metric("Games completed", latest.activity.gamesCompleted)
                        metric("Sets found", latest.activity.setsFound)
                    }
                }

                if latest.reportingDevices == nil {
                    Text("Results appear after at least \(stats.privacy.minimumGroupSize) devices report. Small groups stay withheld.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !latest.modes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mode use")
                            .font(.subheadline.weight(.semibold))
                        ForEach(latest.modes) { mode in
                            HStack {
                                Text(modeName(mode.name))
                                Spacer()
                                Text(mode.percent.map { "\($0)%" } ?? "—")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.footnote)
                        }
                    }
                }

                recentWeeks(stats.weeklyActive, minimumGroupSize: stats.privacy.minimumGroupSize)

                Button {
                    reloadID += 1
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("Community Pulse is getting started", systemImage: "chart.xyaxis.line")
                Text("Activity will appear after at least \(stats.privacy.minimumGroupSize) devices have reported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    reloadID += 1
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
    }

    private func metric(_ label: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.map { String($0) } ?? "—")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func recentWeeks(
        _ weeks: [ESTCommunityStats.WeeklyActive],
        minimumGroupSize: Int
    ) -> some View {
        if weeks.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recent weeks")
                    .font(.subheadline.weight(.semibold))
                ForEach(weeks.suffix(8)) { week in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(week.period)
                            Spacer()
                            Text(week.count.map { "\($0) active devices" } ?? "Growing")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        if week.count == nil {
                            Text("Withheld until \(minimumGroupSize) devices report")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(week.gamesStarted.map { String($0) } ?? "—") games started · \(week.gamesCompleted.map { String($0) } ?? "—") completed · \(week.setsFound.map { String($0) } ?? "—") sets")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func modeName(_ name: String) -> String {
        switch name {
        case "full_solo": return "Full solo"
        case "quick_solo": return "Quick solo"
        case "local_duel": return "Local duel"
        case "network_duel": return "Network duel"
        default: return name.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    @MainActor
    private func reload(id: Int) async {
        guard ESTTelemetry.communityEndpoint != nil else {
            phase = .unavailable
            return
        }
        isRefreshing = true
        defer {
            if reloadID == id {
                isRefreshing = false
            }
        }
        do {
            let result = try await ESTCommunityStatsClient.fetch()
            guard reloadID == id else { return }
            phase = .loaded(result)
        } catch {
            // A cancelled fetch means a newer reload replaced this one. Keep
            // the last good numbers when a refresh fails.
            guard reloadID == id, !Task.isCancelled else { return }
            if case .loaded = phase { return }
            phase = .unavailable
        }
    }
}
