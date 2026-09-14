import GameShell

extension GameIdentity {
    /// EST's identity. The values match what shipped in 1.0.0, so every
    /// derived key stays byte-for-byte the same on existing installs.
    static let est = GameIdentity(
        name: "EST",
        product: "est",
        bundleID: "com.centaur-labs.est",
        supportProductID: "est.support"
    )
}
