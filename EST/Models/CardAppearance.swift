import GameShell
import Foundation
import Observation

/// Card-only look settings. `Appearance` in the shell owns theme, motion and
/// contrast; the fill style is a SET concept, so it lives here.
@Observable
final class CardAppearance {
    static let shared = CardAppearance()

    enum FillStyle: Int, CaseIterable {
        case shaded, pinstriped

        var name: String {
            switch self {
            case .shaded: "Shaded"
            case .pinstriped: "Pinstriped"
            }
        }
    }

    var fillStyle: FillStyle {
        didSet { UserDefaults.standard.set(fillStyle.rawValue, forKey: "appearance.fillStyle") }
    }

    private init() {
        // New installs get pinstriped. An explicit choice still wins, so a
        // player who picked shaded keeps it.
        let storedFill = UserDefaults.standard.object(forKey: "appearance.fillStyle") as? Int
        fillStyle = storedFill.flatMap(FillStyle.init(rawValue:)) ?? .pinstriped
    }
}
