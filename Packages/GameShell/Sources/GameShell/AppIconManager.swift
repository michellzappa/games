import UIKit

/// Keeps the Home Screen icon in step with the in-app appearance theme.
/// Alternate icons are pre-rendered assets; iOS cannot recolor the primary
/// icon at runtime.
public enum AppIconManager {
    public static func update(for theme: Appearance.Theme) {
        let alternateIconName: String? = switch theme {
        case .primary: nil
        case .orchard: "AppIconOrchard"
        case .dusk: "AppIconDusk"
        }

        Task { @MainActor in
            let application = UIApplication.shared
            guard application.supportsAlternateIcons,
                  application.alternateIconName != alternateIconName else { return }
            application.setAlternateIconName(alternateIconName) { error in
                if let error {
                    print("EST could not update the app icon: \(error.localizedDescription)")
                }
            }
        }
    }
}
