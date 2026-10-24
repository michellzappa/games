import SwiftUI

/// The outer margin of every game screen. Games hide the status bar, so the
/// chrome reaches the screen corners. Large rounded displays (iPad, the open
/// iPhone Duo) need a wider margin to keep the corner buttons off the curve.
private struct GameScreenPadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content.padding(horizontalSizeClass == .regular ? 28 : 16)
    }
}

extension View {
    func gameScreenPadding() -> some View {
        modifier(GameScreenPadding())
    }
}
