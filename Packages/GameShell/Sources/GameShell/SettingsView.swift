import SwiftUI

/// What the About section says about the game.
public struct SettingsAbout {
    public let description: String
    public let sourceCodeURL: URL

    public init(description: String, sourceCodeURL: URL) {
        self.description = description
        self.sourceCodeURL = sourceCodeURL
    }
}

/// The settings Form every game shares. It owns the universal sections:
/// appearance, colors, accessibility, sound and touch, feedback, privacy,
/// support, about, and the version footer. A game adds its own sections in
/// three slots: `look` after Appearance (EST: card fill), `game` after
/// Feedback (EST: game options, data), and `afterPrivacy` (EST: Community
/// Pulse). Settings is a Form and keeps native rows; the game button style
/// is for game screens.
public struct SettingsView<Look: View, Game: View, AfterPrivacy: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupportStore.self) private var supportStore
    @Bindable private var appearance = Appearance.shared
    @AppStorage("soundEffectsEnabled") private var soundEffectsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage(ESTTelemetry.enabledKey) private var telemetryEnabled = true
    @State private var showFeedback = false
    @State private var showSupport = false
    @State private var showTelemetryPreview = false

    private let about: SettingsAbout
    private let confetti: () -> AnyView
    private let look: Look
    private let game: Game
    private let afterPrivacy: AfterPrivacy

    private var name: String { GameIdentity.current.name }

    public init(
        about: SettingsAbout,
        confetti: @escaping () -> AnyView = { AnyView(ConfettiView()) },
        @ViewBuilder look: () -> Look,
        @ViewBuilder game: () -> Game,
        @ViewBuilder afterPrivacy: () -> AfterPrivacy
    ) {
        self.about = about
        self.confetti = confetti
        self.look = look()
        self.game = game()
        self.afterPrivacy = afterPrivacy()
    }

    public var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                look
                colorsSection
                accessibilitySection

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

                game
                privacySection
                afterPrivacy
                supportSection
                aboutSection

                Section {
                } footer: {
                    Text("\(name) \(Self.marketingVersion) (build \(Self.buildNumber))")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showSupport) {
                SupportView(confetti: confetti)
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
            .sheet(isPresented: $showTelemetryPreview) {
                TelemetryPreviewView()
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

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Appearance", selection: $appearance.colorSchemeSetting) {
                ForEach(Appearance.ColorSchemeSetting.allCases, id: \.self) { setting in
                    Text(setting.name).tag(setting)
                }
            }
            .pickerStyle(.segmented)

            Text("System follows the device. Light and Dark override it for \(name) only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var colorsSection: some View {
        Section("Colors") {
            ForEach(Appearance.Theme.allCases, id: \.self) { theme in
                themeRow(theme)
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
            Text("A separate optional supporter cosmetic. Dusk changes the identity colors only.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var accessibilitySection: some View {
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

            Text("Auto follows the matching iOS Accessibility setting. On and Off override it for \(name).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
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
                Text("When enabled and a diagnostics endpoint is configured, \(name) sends one aggregate record per ISO week containing the app version, iOS major version, coarse mode activity, and a few feature settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(name) never sends your name, Game Center ID, moves, scores, exact times, or gameplay events. Turning this off deletes pending diagnostics and stops new collection.")
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
    }

    @ViewBuilder
    private var supportSection: some View {
        if GameIdentity.current.supportProductID != nil {
            Section(
                content: {
                    Button {
                        showSupport = true
                    } label: {
                        HStack {
                            Label("Support \(name)", systemImage: "heart")
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
                    Text("\(name) is free and open source. Support is optional and unlocks no gameplay; it adds only supporter thanks and cosmetics.")
                }
            )
        }
    }

    private var aboutSection: some View {
        Section("About") {
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                Text(about.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            if supportStore.isSupporter {
                Label("\(name) Supporter", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GameAccent.second.color)
            }

            Link(destination: about.sourceCodeURL) {
                Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    private func themeRow(_ theme: Appearance.Theme) -> some View {
        let locked = theme == .dusk && !supportStore.isSupporter
        let selected = appearance.theme == theme
        return Button {
            if locked {
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
                Image(systemName: locked ? "lock.fill" : "checkmark")
                    .font(.footnote.bold())
                    .foregroundStyle(locked ? .secondary : .primary)
                    .opacity(locked || selected ? 1 : 0)
            }
        }
    }

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
