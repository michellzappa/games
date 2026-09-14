import SwiftUI

/// A small palette vocabulary for reusable game chrome. The tokens describe a
/// position in a game's palette rather than a particular card attribute, so
/// buttons and shared screens do not depend on EST's `Card.Tint` type.
enum GameAccent: CaseIterable {
    case first
    case second
    case third
    case danger

    /// The three identity positions, in palette order. `danger` is feedback,
    /// not identity.
    static let identity: [GameAccent] = [.first, .second, .third]

    var color: Color {
        Appearance.shared.theme.color(for: self)
    }

    var highlight: Color {
        Appearance.shared.theme.highlight(for: self)
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [highlight, color],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
