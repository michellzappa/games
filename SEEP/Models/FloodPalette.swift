import GameShell
import SwiftUI

/// The six flood colors, per theme. The first three are the identity
/// accents so SEEP recolors with the theme like every game in the library;
/// the other three are fixed per theme and chosen to stay apart from them
/// under color-blind simulation.
enum FloodPalette {
    static func color(_ index: Int) -> Color {
        switch index {
        case 0: GameAccent.first.color
        case 1: GameAccent.second.color
        case 2: GameAccent.third.color
        default: extra(index - 3)
        }
    }

    static func name(_ index: Int) -> String {
        switch Appearance.shared.theme {
        case .primary: ["red", "blue", "yellow", "purple", "green", "gray"][index]
        case .orchard: ["purple", "green", "orange", "pink", "blue", "gray"][index]
        case .dusk: ["pink", "teal", "gold", "purple", "green", "gray"][index]
        }
    }

    /// A glyph per color for color-blind assist, drawn over the cell.
    static let symbols = ["circle.fill", "square.fill", "triangle.fill", "diamond.fill", "star.fill", "hexagon.fill"]

    private static func extra(_ index: Int) -> Color {
        switch (Appearance.shared.theme, index) {
        case (.primary, 0): Color(red: 0.61, green: 0.34, blue: 0.78)
        case (.primary, 1): Color(red: 0.24, green: 0.66, blue: 0.42)
        case (.orchard, 0): Color(red: 0.82, green: 0.28, blue: 0.48)
        case (.orchard, 1): Color(red: 0.22, green: 0.48, blue: 0.86)
        case (.dusk, 0): Color(red: 0.61, green: 0.38, blue: 0.80)
        case (.dusk, 1): Color(red: 0.33, green: 0.62, blue: 0.40)
        default: Color(red: 0.55, green: 0.56, blue: 0.60)
        }
    }
}
