import SwiftUI

/// EST's one button vocabulary. Every control the player taps outside a Form
/// uses this style, so the game reads as a game and not as a settings screen.
///
/// The style guide, in three rules:
///
/// 1. **One primary per screen.** The filled, glowing button is the action the
///    screen exists for. Everything else is secondary or quiet.
/// 2. **Tints come from the game palette**, never from the system accent. The
///    first three accents follow EST's card palette, while a future game can
///    map the same tokens to its own visual identity.
/// 3. **A row is one size.** Buttons stretch to equal widths, so no row ever
///    tapers or wraps its label.
///
/// Do not use `.bordered` or `.borderedProminent` in the game UI. Settings is
/// a Form and keeps native list rows on purpose.
public struct GameButtonStyle: ButtonStyle {
    public enum Role {
        /// The action the screen wants. Filled with the tint gradient, lit
        /// with a glow of its own color.
        case primary
        /// A real alternative on the same screen. Glass surface, tinted label.
        case secondary
        /// Exits, back steps, and asides. No surface, no glow.
        case quiet
    }

    public enum Size {
        case large, medium, compact
        /// A fixed square for a lone glyph, and a label-width button for
        /// asides. Neither stretches to fill its row.
        case icon, inline

        public var height: CGFloat {
            switch self {
            case .large: 58
            case .medium: 50
            case .compact: 46
            case .icon: 46
            case .inline: 38
            }
        }

        /// Semantic text styles scale with the user's preferred text size.
        /// The previous point-size fonts kept the game controls fixed at
        /// every Dynamic Type setting, which made Larger Text ineffective.
        public var font: Font {
            switch self {
            case .large: .system(.title3, design: .rounded, weight: .bold)
            case .medium, .icon: .system(.body, design: .rounded, weight: .bold)
            case .compact: .system(.subheadline, design: .rounded, weight: .bold)
            case .inline: .system(.footnote, design: .rounded, weight: .bold)
            }
        }
    }

    public var role: Role = .secondary
    public var tint: GameAccent = .second
    public var size: Size = .medium

    public func makeBody(configuration: Configuration) -> some View {
        Surface(configuration: configuration, role: role, tint: tint, size: size)
    }

    /// A ButtonStyle cannot read the environment, so the body lives in a view
    /// that can: a disabled button has to look disabled.
    private struct Surface: View {
        public let configuration: Configuration
        public let role: Role
        public let tint: GameAccent
        public let size: Size

        @Environment(\.isEnabled) private var isEnabled
        @AppStorage("hapticsEnabled") private var hapticsEnabled = true
        @ScaledMetric(relativeTo: .body) private var horizontalPadding: CGFloat = 14
        @ScaledMetric(relativeTo: .body) private var verticalPadding: CGFloat = 8

        private var cornerRadius: CGFloat { size.height * 0.32 }
        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        }

        public var body: some View {
            let pressed = configuration.isPressed
            configuration.label
                .font(size.font)
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, size == .icon ? 0 : horizontalPadding)
                .padding(.vertical, verticalPadding)
                .modifier(SizeModifier(size: size))
                .background(background)
                .overlay {
                    if role != .primary {
                        shape.strokeBorder(
                            tint.color.opacity(role == .secondary ? 0.40 : 0.16),
                            lineWidth: 1.5
                        )
                    }
                }
                .contentShape(shape)
                .shadow(
                    color: role == .primary ? tint.color.opacity(pressed ? 0.25 : 0.5) : .clear,
                    radius: pressed ? 5 : 12,
                    y: pressed ? 2 : 5
                )
                .scaleEffect(pressed ? 0.96 : 1)
                .opacity(isEnabled ? 1 : 0.35)
                .animation(.spring(duration: 0.22), value: pressed)
                .sensoryFeedback(
                    trigger: FeedbackTrigger(value: pressed, enabled: hapticsEnabled)
                ) { oldValue, newValue in
                    guard newValue.enabled, !oldValue.value, newValue.value else { return nil }
                    return .impact(flexibility: .soft, intensity: 0.4)
                }
        }

        @ViewBuilder
        private var background: some View {
            switch role {
            case .primary:
                shape.fill(tint.gradient)
            case .secondary:
                Color.clear.glassPanel(cornerRadius: cornerRadius)
            case .quiet:
                shape.fill(tint.color.opacity(0.08))
            }
        }

        private var labelColor: Color {
            switch role {
            case .primary: .white
            case .secondary: tint.color
            case .quiet: .secondary
            }
        }
    }

    /// Every size but `.icon` stretches, so buttons in a row end up equal.
    /// The height is a minimum instead of a fixed frame: at larger Dynamic
    /// Type sizes the semantic label gets enough vertical room to stay
    /// legible rather than being clipped.
    private struct SizeModifier: ViewModifier {
        public let size: Size

        public func body(content: Content) -> some View {
            switch size {
            case .icon:
                content.frame(minWidth: size.height, minHeight: size.height)
            case .inline:
                content.frame(minHeight: size.height)
            default:
                content.frame(maxWidth: .infinity).frame(minHeight: size.height)
            }
        }
    }
}

public extension ButtonStyle where Self == GameButtonStyle {
    public static func game(
        _ role: GameButtonStyle.Role = .secondary,
        tint: GameAccent = .second,
        size: GameButtonStyle.Size = .medium
    ) -> GameButtonStyle {
        GameButtonStyle(role: role, tint: tint, size: size)
    }
}

/// The one persistent escape hatch inside a game. Keeping this as a shared
/// control makes the action and its hit target identical across game modes;
/// each screen owns the confirmation behavior around it.
public struct GameExitButton: View {
    public let action: () -> Void
    public var accessibilityLabel = "End game"

    public init(accessibilityLabel: String = "End game", action: @escaping () -> Void) {
        self.action = action
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
        }
        .buttonStyle(.game(.quiet, tint: .first, size: .icon))
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Turns the card symbols to face another player on a shared device. Every
/// tap is a quarter turn, on every screen: half a turn moves only triangles
/// and the three-symbol arrangement, so it reads as almost nothing. Paired
/// with `GameExitButton` in the opposite corner of the same chrome row.
public struct GameFlipButton: View {
    public static let step = Angle.degrees(90)
    public let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise.circle.fill")
        }
        .buttonStyle(.game(.quiet, tint: .second, size: .icon))
        .accessibilityLabel("Turn the table")
        .accessibilityHint("Rotates the cards a quarter turn")
    }
}

#Preview {
    VStack(spacing: 12) {
        Button("Solo 81") {}
            .buttonStyle(.game(.primary, tint: .second, size: .large))
        HStack(spacing: 12) {
            Button("Quick 27") {}
                .buttonStyle(.game(.secondary, tint: .third, size: .large))
            Button("Duel") {}
                .buttonStyle(.game(.secondary, tint: .first, size: .large))
        }
        HStack(spacing: 12) {
            Button("Rules") {}
                .buttonStyle(.game(.quiet, size: .compact))
            Button("Leaderboard") {}
                .buttonStyle(.game(.quiet, size: .compact))
            Button {} label: { Image(systemName: "gearshape") }
                .buttonStyle(.game(.quiet, size: .icon))
        }
        Button("Disabled") {}
            .buttonStyle(.game(.primary, size: .medium))
            .disabled(true)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
