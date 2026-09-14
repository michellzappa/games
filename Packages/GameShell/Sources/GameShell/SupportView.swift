import SwiftUI

/// The optional patronage screen. It deliberately explains that the purchase
/// changes nothing about gameplay, so it cannot be mistaken for a paywall.
public struct SupportView: View {
    /// Confetti for the thank-you screen, in the game's own shapes. Default
    /// is the shell's plain circles in the identity colors.
    private let confetti: () -> AnyView

    public init(confetti: @escaping () -> AnyView = { AnyView(ConfettiView()) }) {
        self.confetti = confetti
    }

    private var name: String { GameIdentity.current.name }

    /// The mark and its glyph scale together, so the heart keeps its
    /// proportion inside the circle at every text size.
    @ScaledMetric(relativeTo: .largeTitle) private var markSide: CGFloat = 88
    @ScaledMetric(relativeTo: .largeTitle) private var markGlyphSize: CGFloat = 34
    @Environment(\.dismiss) private var dismiss
    @Environment(SupportStore.self) private var store
    @State private var showThankYou = false

    private var isWorking: Bool {
        store.isLoading || store.isPurchasing || store.isRestoring
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    supporterMark

                    VStack(spacing: 8) {
                        Text(store.isSupporter ? "Thank you for supporting \(name)" : "Support \(name)")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text("\(name) is free and open source. If you enjoy playing it, a one-time gift helps keep it independent and ad-free.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        reasonRow("gift", "Keeps every mode free")
                        reasonRow("sparkles", "Helps pay for maintenance")
                        reasonRow("nosign", "Keeps ads out of the game")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassPanel(cornerRadius: 20)

                    perksPanel

                    Text("This purchase unlocks no gameplay. Every player gets the same game.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let message = store.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if store.isSupporter {
                        VStack(spacing: 12) {
                            Label("You're an \(name) supporter", systemImage: "checkmark.seal.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GameAccent.second.color)

                            Button {
                                Appearance.shared.theme = .dusk
                            } label: {
                                Label("Use Dusk colors", systemImage: "paintpalette")
                            }
                            .buttonStyle(.game(.secondary, tint: .third, size: .medium))
                        }
                    } else {
                        Button {
                            Task {
                                if await store.purchase() {
                                    showThankYou = true
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if store.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("Support EST")
                                if let product = store.product {
                                    Text("·")
                                    Text(product.displayPrice)
                                }
                            }
                        }
                        .buttonStyle(.game(.primary, tint: .first, size: .large))
                        .disabled(isWorking || store.product == nil)
                    }

                    Button {
                        Task { await store.restore() }
                    } label: {
                        HStack(spacing: 8) {
                            if store.isRestoring {
                                ProgressView()
                            }
                            Text("Restore purchase")
                        }
                    }
                    .buttonStyle(.game(.quiet, size: .compact))
                    .disabled(isWorking)

                    Text("One-time gift. No subscription.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(24)
            }
            .navigationTitle("Support EST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(isWorking)
                }
            }
        }
        .task {
            await store.start()
        }
        .sheet(isPresented: $showThankYou) {
            SupportThankYouView(confetti: confetti) {
                Appearance.shared.theme = .dusk
            }
        }
    }

    private var perksPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supporter perks")
                .font(.headline)

            perkRow("checkmark.seal.fill", "A permanent supporter mark in EST")
            perkRow("paintpalette.fill", "The optional Dusk card colors")
            perkRow("sun.max.fill", "An optional warm background in Settings")
            perkRow("testtube.2", "Early TestFlight access when new builds are available")

            Text("TestFlight invites are handled manually and are always opt-in.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassPanel(cornerRadius: 20)
    }

    private var supporterMark: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [GameAccent.first.color, GameAccent.third.color, GameAccent.second.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "heart.fill")
                .font(.system(size: markGlyphSize, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: markSide, height: markSide)
        .shadow(color: GameAccent.first.color.opacity(0.28), radius: 16, y: 8)
        .accessibilityHidden(true)
    }

    private func reasonRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
    }

    private func perkRow(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
    }

}

private struct SupportThankYouView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var sealSize: CGFloat = 58
    @Environment(\.dismiss) private var dismiss
    var confetti: () -> AnyView
    var onUseFinish: () -> Void

    public var body: some View {
        ZStack {
            Appearance.shared.gameBackground
                .ignoresSafeArea()
            confetti()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: sealSize, weight: .bold))
                    .foregroundStyle(GameAccent.third.color)

                Text("Thank you")
                    .font(.largeTitle.weight(.bold))

                Text("You’re helping keep \(GameIdentity.current.name) free, open source, and independent.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text("Every mode stays free for everyone.")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Button {
                    onUseFinish()
                    dismiss()
                } label: {
                    Label("Try Dusk colors", systemImage: "paintpalette")
                }
                .buttonStyle(.game(.secondary, tint: .third, size: .large))

                Button("Done") { dismiss() }
                    .buttonStyle(.game(.primary, tint: .second, size: .large))
            }
            .padding(28)
            .frame(maxWidth: 440)
            .glassPanel(cornerRadius: 28)
            .padding(24)
        }
    }
}

#Preview {
    SupportView()
        .environment(SupportStore())
}
