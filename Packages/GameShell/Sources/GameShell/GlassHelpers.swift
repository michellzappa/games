import SwiftUI

/// Liquid Glass surfaces on iOS 26, graceful material/color fallbacks below.
/// Deployment target is 17.0, so everything goes through availability checks.
public extension View {
    @ViewBuilder
    public func glassPanel(cornerRadius: CGFloat = 24) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }

    /// A panel that must stay readable over confetti and the live board.
    /// Glass alone lets the board show through the text, so this lays an
    /// opaque scrim under it. Use it for end cards, `glassPanel` elsewhere.
    @ViewBuilder
    public func glassCard(cornerRadius: CGFloat = 24) -> some View {
        self.glassPanel(cornerRadius: cornerRadius)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.85))
            )
    }

    /// Tinted, press-responsive glass for the buzz buttons.
    @ViewBuilder
    public func glassButtonSurface(tint: Color, opacity: Double, cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.tint(tint.opacity(opacity)).interactive(),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(opacity))
            )
        }
    }
}
