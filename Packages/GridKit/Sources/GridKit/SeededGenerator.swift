import Foundation

/// A deterministic generator: the same seed gives the same board on every
/// device, so a level is a seed and a daily puzzle is a date. SplitMix64.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Seed recipes shared by every game, so a "daily" means the same day
/// everywhere and a level's seed never depends on the device.
public enum Seed {
    /// The UTC calendar day, as yyyymmdd, mixed with a per-game salt so two
    /// games never share a daily board.
    public static func daily(_ date: Date = .now, salt: String) -> UInt64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = UInt64(parts.year! * 10_000 + parts.month! * 100 + parts.day!)
        return mix(day, fnv(salt))
    }

    /// A level inside a pack. Stable across releases as long as the pack id
    /// and index do not change.
    public static func level(pack: String, index: Int) -> UInt64 {
        mix(fnv(pack), UInt64(index) &+ 1)
    }

    /// FNV-1a over UTF-8, so string seeds do not depend on `hashValue`,
    /// which changes per process.
    public static func fnv(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }

    private static func mix(_ a: UInt64, _ b: UInt64) -> UInt64 {
        var generator = SeededGenerator(seed: a ^ (b &* 0x9E37_79B9_7F4A_7C15))
        return generator.next()
    }
}
