import Foundation

/// Everything the shell needs to know about the game it is running inside.
/// A game installs its identity once at launch; telemetry, feedback, the
/// support purchase, and every persisted key read it from `current`.
///
/// Keys are derived from `product` so an existing install keeps its data:
/// EST's `product` is "est", which yields the `estTelemetryEnabled` key and
/// the `ESTTelemetryEndpoint` Info.plist key it has always used.
public struct GameIdentity: Sendable, Equatable {
    /// Display name, as the title screen and App Store show it: "EST".
    public let name: String
    /// Short lowercase slug. It is the `product` field on every wire payload,
    /// the prefix of every UserDefaults key, and the prefix of the Game
    /// Center and StoreKit ids: "est", "seep".
    public let product: String
    /// Reverse-DNS bundle id: "com.centaur-labs.est".
    public let bundleID: String
    /// StoreKit product for the optional patronage purchase, or nil when
    /// the game ships without one.
    public let supportProductID: String?

    public init(name: String, product: String, bundleID: String, supportProductID: String?) {
        precondition(!product.isEmpty && product == product.lowercased(),
                     "product must be a lowercase slug")
        self.name = name
        self.product = product
        self.bundleID = bundleID
        self.supportProductID = supportProductID
    }

    // MARK: Derived keys

    /// UserDefaults key: "estTelemetryEnabled".
    public func defaultsKey(_ suffix: String) -> String {
        product + suffix
    }

    /// Info.plist build setting: "ESTTelemetryEndpoint".
    public func infoKey(_ suffix: String) -> String {
        product.uppercased() + suffix
    }

    /// HTTP header: "X-EST-Telemetry-Schema".
    public func header(_ suffix: String) -> String {
        "X-" + product.uppercased() + "-" + suffix
    }

    /// Keychain service for the install secret: "com.centaur-labs.est.telemetry".
    public var telemetryKeychainService: String {
        bundleID + ".telemetry"
    }

    /// Application Support subpath for the pending batch: "EST/Telemetry".
    public var telemetryDirectory: String {
        product.uppercased() + "/Telemetry"
    }

    // MARK: Shared endpoints

    /// One Worker serves every game. Payloads carry `product`, so the
    /// Worker scopes storage and aggregates per game.
    public static let defaultTelemetryEndpoint = "https://est-telemetry.envisioning.workers.dev/v1/batches"
    public static let defaultFeedbackEndpoint = "https://est-telemetry.envisioning.workers.dev/v1/feedback"

    // MARK: Current

    /// The identity of the running game. Set once in the `App` initializer,
    /// before any shell code runs.
    public static var current: GameIdentity {
        get {
            guard let installed else {
                preconditionFailure("GameIdentity.install(_:) must run in the App initializer")
            }
            return installed
        }
    }

    public static func install(_ identity: GameIdentity) {
        installed = identity
    }

    nonisolated(unsafe) private static var installed: GameIdentity?
}
