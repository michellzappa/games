import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupportStore.self) private var supportStore
    @Bindable private var appearance = Appearance.shared
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("immersiveGameMode") private var immersiveGameMode = true
    @AppStorage("showSoloTimer") private var showSoloTimer = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @AppStorage("bestSoloTime") private var bestSoloTime: Double = 0
    @AppStorage("bestQuickTime") private var bestQuickTime: Double = 0
    @AppStorage(ESTTelemetry.enabledKey) private var telemetryEnabled = true
    @State private var showFeedback = false
    @State private var showSupport = false
    @State private var showTelemetryPreview = false
    @State private var showResetStatsConfirmation = false
    @State private var showPlayStyle = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance.colorSchemeSetting) {
                        ForEach(Appearance.ColorSchemeSetting.allCases, id: \.self) { setting in
                            Text(setting.name).tag(setting)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("System follows the device. Light and Dark override it for EST only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Fill") {
                    Picker("Fill style", selection: $appearance.fillStyle) {
                        ForEach(Appearance.FillStyle.allCases, id: \.self) { style in
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

                Section("Colors") {
                    ForEach(Appearance.Theme.allCases, id: \.self) { theme in
                        Button {
                            if theme == .dusk && !supportStore.isSupporter {
                                showSupport = true
                            } else {
                                appearance.theme = theme
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text(theme.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                ForEach(GameAccent.identity, id: \.self) { accent in
                                    Circle()
                                        .fill(theme.color(for: accent))
                                        .frame(width: 16, height: 16)
                                }
                                Image(systemName: theme == .dusk && !supportStore.isSupporter ? "lock.fill" : "checkmark")
                                    .font(.footnote.bold())
                                    .foregroundStyle(theme == .dusk && !supportStore.isSupporter ? .secondary : .primary)
                                    .opacity((theme == .dusk && !supportStore.isSupporter) || appearance.theme == theme ? 1 : 0)
                            }
                        }
                    }

                    if supportStore.isSupporter {
                        Toggle("Warm background", isOn: $appearance.warmBackgroundEnabled)
                    } else {
                        Button {
                            showSupport = true
                        } label: {
                            HStack {
                                Text("Warm background")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.footnote.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("A separate optional supporter cosmetic. Dusk changes card colors only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Accessibility") {
                    Picker("Reduce motion", selection: $appearance.reduceMotion) {
                        ForEach(Appearance.AccessibilitySetting.allCases, id: \.self) { setting in
                            Text(setting.name).tag(setting)
                        }
                    }

                    Picker("High contrast", selection: $appearance.highContrast) {
                        ForEach(Appearance.AccessibilitySetting.allCases, id: \.self) { setting in
                            Text(setting.name).tag(setting)
                        }
                    }

                    Picker("Color-blind assist", selection: $appearance.colorBlindAssist) {
                        ForEach(Appearance.AccessibilitySetting.allCases, id: \.self) { setting in
                            Text(setting.name).tag(setting)
                        }
                    }

                    Text("Auto follows the matching iOS Accessibility setting. On and Off override it for EST.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Sound & touch") {
                    Toggle("Sound effects", isOn: $soundEffectsEnabled)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section("Feedback & support") {
                    Button {
                        showFeedback = true
                    } label: {
                        Label("Send feedback", systemImage: "envelope")
                    }
                }

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

                Section("Privacy") {
                    Toggle("Share anonymous diagnostics", isOn: $telemetryEnabled)
                        .onChange(of: telemetryEnabled) { _, enabled in
                            ESTTelemetry.setEnabled(enabled)
                            if enabled {
                                TelemetryCoordinator.shared.start()
                            } else {
                                TelemetryCoordinator.shared.stop()
                            }
                        }

                    DisclosureGroup("What is shared") {
                        Text("When enabled and a diagnostics endpoint is configured, EST sends one aggregate record per ISO week containing the app version, iOS major version, coarse mode activity, and a few feature settings.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("EST never sends your name, Game Center ID, cards, scores, exact times, or gameplay events. Turning this off deletes pending diagnostics and stops new collection.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Link(destination: ESTTelemetry.sourceURL) {
                            Label("Read the telemetry code", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        Link(destination: ESTTelemetry.privacyURL) {
                            Label("Read the privacy policy", systemImage: "hand.raised")
                        }
                        Button {
                            showTelemetryPreview = true
                        } label: {
                            Label("Preview this week's batch", systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(!telemetryEnabled)
                    }
                }

                if telemetryEnabled {
                    Section("Community Pulse") {
                        CommunityPulseView()
                    }
                }

                Section(
                    content: {
                        Button {
                            showSupport = true
                        } label: {
                            HStack {
                                Label("Support EST", systemImage: "heart")
                                Spacer()
                                if supportStore.isSupporter {
                                    Text("Supporter")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(GameAccent.second.color)
                                }
                            }
                        }
                    },
                    header: {
                        Text("Support")
                    },
                    footer: {
                        Text("EST is free and open source. Support is optional and unlocks no gameplay; it adds only supporter thanks and cosmetics.")
                    }
                )

                Section("About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("EST")
                            .font(.headline)
                        Text("A free, open-source iPhone game by Michell Zappa at Centaur Labs, inspired by SET.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    if supportStore.isSupporter {
                        Label("EST Supporter", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GameAccent.second.color)
                    }

                    Link(destination: Self.sourceCodeURL) {
                        Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                Section {
                } footer: {
                    Text("EST \(Self.marketingVersion) (build \(Self.buildNumber))")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showSupport) {
                SupportView()
            }
            .sheet(isPresented: $showPlayStyle) {
                PlayStyleView()
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
            .sheet(isPresented: $showTelemetryPreview) {
                TelemetryPreviewView()
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
            .onChange(of: soundEffectsEnabled) { _, enabled in
                GameAudio.shared.setEnabled(enabled)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static let sourceCodeURL = URL(string: "https://github.com/michellzappa/games")!

    private static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
}

private struct TelemetryPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preview: ESTTelemetryBatch?

    var body: some View {
        NavigationStack {
            Group {
                if let preview {
                    ScrollView {
                        Text(encoded(preview))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else {
                    ProgressView("Building preview…")
                }
            }
            .navigationTitle("Telemetry preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                preview = await TelemetryCoordinator.shared.preview()
            }
        }
    }

    private func encoded(_ batch: ESTTelemetryBatch) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(batch),
              let value = String(data: data, encoding: .utf8)
        else { return "Preview unavailable." }
        return value
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
