import SwiftUI
import UIKit
import Observation

/// Builds a color that resolves at draw time, so it follows the active
/// appearance. A plain `Color(red:green:blue:)` is fixed and stays light in
/// dark mode.
private func dynamicColor(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
}

/// User-facing look settings, persisted in UserDefaults. Identity colors
/// flow through the active theme by palette position (`GameAccent`), and
/// `Card.Tint.color` delegates there, so a theme change restyles cards,
/// confetti, the title, and the progress bar at once.
@Observable
final class Appearance {
    static let shared = Appearance()

    enum AccessibilitySetting: Int, CaseIterable {
        case automatic, on, off

        var name: String {
            switch self {
            case .automatic: "Auto"
            case .on: "On"
            case .off: "Off"
            }
        }

        func resolved(using systemValue: Bool) -> Bool {
            switch self {
            case .automatic: systemValue
            case .on: true
            case .off: false
            }
        }
    }

    /// Light and dark mode. `system` follows the device; the other two
    /// override it for EST alone.
    enum ColorSchemeSetting: Int, CaseIterable {
        case system, light, dark

        var name: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    enum FillStyle: Int, CaseIterable {
        case shaded, pinstriped

        var name: String {
            switch self {
            case .shaded: "Shaded"
            case .pinstriped: "Pinstriped"
            }
        }
    }

    enum Theme: Int, CaseIterable {
        case primary, orchard, dusk

        var name: String {
            switch self {
            case .primary: "Primary"
            case .orchard: "Orchard"
            case .dusk: "Dusk"
            }
        }

        /// Identity colors by palette position. A game maps its own identity
        /// system onto these three positions (EST: red, blue, yellow).
        func color(for accent: GameAccent) -> Color {
            switch (self, accent) {
            case (.primary, .first): Color(red: 0.87, green: 0.32, blue: 0.28)
            case (.primary, .second): Color(red: 0.24, green: 0.43, blue: 0.92)
            case (.primary, .third): Color(red: 0.94, green: 0.66, blue: 0.20)
            case (.orchard, .first): Color(red: 0.55, green: 0.33, blue: 0.83)
            case (.orchard, .second): Color(red: 0.13, green: 0.62, blue: 0.39)
            case (.orchard, .third): Color(red: 0.93, green: 0.47, blue: 0.15)
            case (.dusk, .first): Color(red: 0.87, green: 0.33, blue: 0.46)
            case (.dusk, .second): Color(red: 0.12, green: 0.55, blue: 0.58)
            case (.dusk, .third): Color(red: 0.82, green: 0.60, blue: 0.16)
            case (_, .danger): errorColor
            }
        }

        /// Lighter sibling used as the top of a solid-fill gradient.
        func highlight(for accent: GameAccent) -> Color {
            switch (self, accent) {
            case (.primary, .first): Color(red: 0.96, green: 0.47, blue: 0.41)
            case (.primary, .second): Color(red: 0.44, green: 0.60, blue: 0.98)
            case (.primary, .third): Color(red: 0.99, green: 0.79, blue: 0.38)
            case (.orchard, .first): Color(red: 0.68, green: 0.48, blue: 0.93)
            case (.orchard, .second): Color(red: 0.30, green: 0.76, blue: 0.53)
            case (.orchard, .third): Color(red: 0.98, green: 0.62, blue: 0.31)
            case (.dusk, .first): Color(red: 0.96, green: 0.50, blue: 0.61)
            case (.dusk, .second): Color(red: 0.29, green: 0.70, blue: 0.73)
            case (.dusk, .third): Color(red: 0.93, green: 0.74, blue: 0.34)
            case (_, .danger): errorColor.opacity(0.72)
            }
        }

        /// Soft semantic accents are for feedback, never for card identity.
        /// They stay readable beside the themed card tints without using the
        /// saturated system `Color.green`/`Color.red` defaults.
        var successColor: Color {
            switch self {
            case .primary: Color(red: 0.28, green: 0.64, blue: 0.40)
            case .orchard: Color(red: 0.30, green: 0.66, blue: 0.45)
            case .dusk: Color(red: 0.34, green: 0.70, blue: 0.64)
            }
        }

        /// The fourth player's identity accent. It is deliberately separate
        /// from `successColor`: that color is reserved for game feedback,
        /// while this one must remain distinct from the three card tints.
        var fourthPlayerColor: Color {
            switch self {
            case .primary: Color(red: 0.61, green: 0.34, blue: 0.78)
            case .orchard: Color(red: 0.82, green: 0.28, blue: 0.48)
            case .dusk: Color(red: 0.61, green: 0.38, blue: 0.80)
            }
        }

        var errorColor: Color {
            switch self {
            case .primary: Color(red: 0.78, green: 0.36, blue: 0.34)
            case .orchard: Color(red: 0.78, green: 0.39, blue: 0.43)
            case .dusk: Color(red: 0.80, green: 0.40, blue: 0.49)
            }
        }

        /// Dusk is the supporter-only finish. It adds a warm paper-and-metal
        /// feel without changing card identity or giving its owner a gameplay
        /// advantage.
        var cardSurface: Color {
            switch self {
            case .dusk: dynamicColor(
                light: UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1),
                dark: UIColor(red: 0.20, green: 0.18, blue: 0.15, alpha: 1)
            )
            default: Color(.secondarySystemGroupedBackground)
            }
        }

        var cardBorder: Color {
            switch self {
            case .dusk: dynamicColor(
                light: UIColor(red: 0.68, green: 0.47, blue: 0.16, alpha: 0.55),
                dark: UIColor(red: 0.85, green: 0.66, blue: 0.30, alpha: 0.55)
            )
            default: Color.primary.opacity(0.12)
            }
        }

        /// The dashed outline of an empty pile slot. Same hue as `cardBorder`,
        /// drawn stronger because no card sits under it.
        var cardSlotBorder: Color {
            switch self {
            case .dusk: dynamicColor(
                light: UIColor(red: 0.68, green: 0.47, blue: 0.16, alpha: 0.75),
                dark: UIColor(red: 0.85, green: 0.66, blue: 0.30, alpha: 0.75)
            )
            default: Color.primary.opacity(0.22)
            }
        }
    }

    var colorSchemeSetting: ColorSchemeSetting {
        didSet {
            UserDefaults.standard.set(colorSchemeSetting.rawValue, forKey: "appearance.colorScheme")
        }
    }

    var fillStyle: FillStyle {
        didSet { UserDefaults.standard.set(fillStyle.rawValue, forKey: "appearance.fillStyle") }
    }

    var warmBackgroundEnabled: Bool {
        didSet { UserDefaults.standard.set(warmBackgroundEnabled, forKey: "appearance.warmBackground") }
    }

    var reduceMotion: AccessibilitySetting {
        didSet { UserDefaults.standard.set(reduceMotion.rawValue, forKey: "appearance.reduceMotion") }
    }

    var highContrast: AccessibilitySetting {
        didSet { UserDefaults.standard.set(highContrast.rawValue, forKey: "appearance.highContrast") }
    }

    var colorBlindAssist: AccessibilitySetting {
        didSet { UserDefaults.standard.set(colorBlindAssist.rawValue, forKey: "appearance.colorBlindAssist") }
    }

    var theme: Theme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "appearance.theme")
            AppIconManager.update(for: theme)
        }
    }

    /// Player identity follows the card palette so a theme changes both in
    /// lockstep. The fourth slot uses the theme's implicit fourth player hue.
    func playerColor(for slot: Int) -> Color {
        switch slot {
        case 0: GameAccent.first.color
        case 1: GameAccent.second.color
        case 2: GameAccent.third.color
        default: theme.fourthPlayerColor
        }
    }

    /// Use these for UI feedback, not for card or player identity.
    var successColor: Color { theme.successColor }
    var errorColor: Color { theme.errorColor }

    /// Themes change the card palette, not the surrounding app surface. The
    /// warm surface is a separate, explicitly chosen supporter cosmetic.
    var gameBackground: Color {
        warmBackgroundEnabled
            ? dynamicColor(
                light: UIColor(red: 0.93, green: 0.91, blue: 0.85, alpha: 1),
                dark: UIColor(red: 0.15, green: 0.13, blue: 0.11, alpha: 1)
            )
            : Color(.systemGroupedBackground)
    }

    /// Themes never force light or dark. Only this setting does, and `system`
    /// leaves the device in charge.
    var preferredColorScheme: ColorScheme? {
        colorSchemeSetting.colorScheme
    }

    private init() {
        // Raw value 0 is `system`, so an install that never chose a mode
        // keeps following the device.
        colorSchemeSetting = ColorSchemeSetting(
            rawValue: UserDefaults.standard.integer(forKey: "appearance.colorScheme")
        ) ?? .system
        // New installs get pinstriped. An explicit choice still wins, so a
        // player who picked shaded keeps it.
        let storedFill = UserDefaults.standard.object(forKey: "appearance.fillStyle") as? Int
        fillStyle = storedFill.flatMap(FillStyle.init(rawValue:)) ?? .pinstriped
        warmBackgroundEnabled = UserDefaults.standard.bool(forKey: "appearance.warmBackground")
        reduceMotion = AccessibilitySetting(
            rawValue: UserDefaults.standard.integer(forKey: "appearance.reduceMotion")
        ) ?? .automatic
        highContrast = AccessibilitySetting(
            rawValue: UserDefaults.standard.integer(forKey: "appearance.highContrast")
        ) ?? .automatic
        colorBlindAssist = AccessibilitySetting(
            rawValue: UserDefaults.standard.integer(forKey: "appearance.colorBlindAssist")
        ) ?? .automatic
        // Raw value 3 was the previous Supporter theme. Carry that choice
        // forward as Dusk when upgrading to the supporter-only Dusk finish.
        theme = switch UserDefaults.standard.integer(forKey: "appearance.theme") {
        case 1: .orchard
        case 2, 3: .dusk
        default: .primary
        }
    }
}

private struct ESTReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ESTHighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ESTColorBlindAssistKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var estReduceMotion: Bool {
        get { self[ESTReduceMotionKey.self] }
        set { self[ESTReduceMotionKey.self] = newValue }
    }

    var estHighContrast: Bool {
        get { self[ESTHighContrastKey.self] }
        set { self[ESTHighContrastKey.self] = newValue }
    }

    var estColorBlindAssist: Bool {
        get { self[ESTColorBlindAssistKey.self] }
        set { self[ESTColorBlindAssistKey.self] = newValue }
    }
}
