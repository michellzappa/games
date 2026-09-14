import CryptoKit
import Foundation
import Security
import UIKit

/// The small, inspectable contract sent by EST when anonymous diagnostics are
/// enabled. It is an aggregate, never an event stream.
public struct ESTTelemetryBatch: Codable, Equatable, Sendable {
    public struct App: Codable, Equatable, Sendable {
        public let version: String
        public let build: String
        public let iOSMajor: Int
        public let deviceFamily: String

        public enum CodingKeys: String, CodingKey {
            case version, build
            case iOSMajor = "ios_major"
            case deviceFamily = "device_family"
        }
    }

    public let schema: Int
    public let product: String
    public let batchID: String
    /// HMAC-SHA256(device secret, ISO week). The secret never leaves the phone
    /// and the result changes every week, so it is not a stable install id.
    public let dedupeKey: String
    public let period: String
    public let cohort: String?
    public let app: App
    /// Coarse counts collected locally during this ISO week.
    public let activity: [String: Int]
    /// Whitelisted feature flags, never arbitrary UserDefaults keys.
    public let features: [String: Bool]

    public enum CodingKeys: String, CodingKey {
        case schema, product
        case batchID = "batch_id"
        case dedupeKey = "dedupe_key"
        case period, cohort, app, activity, features
    }
}

/// Public aggregate results returned by the EST telemetry Worker. Every
/// count or percentage may be withheld when the reporting group is too small.
public struct ESTCommunityStats: Decodable, Sendable {
    public struct Privacy: Decodable, Sendable {
        public let minimumGroupSize: Int

        public enum CodingKeys: String, CodingKey {
            case minimumGroupSize = "minimum_group_size"
        }
    }

    public struct WeeklyActive: Decodable, Identifiable, Sendable {
        public let period: String
        public let count: Int?
        public let inProgress: Bool
        public let gamesStarted: Int?
        public let gamesCompleted: Int?
        public let setsFound: Int?

        public var id: String { period }

        public enum CodingKeys: String, CodingKey {
            case period, count
            case inProgress = "in_progress"
            case gamesStarted = "games_started"
            case gamesCompleted = "games_completed"
            case setsFound = "sets_found"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            period = try container.decode(String.self, forKey: .period)
            count = try container.decodeIfPresent(Int.self, forKey: .count)
            inProgress = try container.decodeIfPresent(
                Bool.self, forKey: .inProgress) ?? false
            gamesStarted = try container.decodeIfPresent(
                Int.self, forKey: .gamesStarted)
            gamesCompleted = try container.decodeIfPresent(
                Int.self, forKey: .gamesCompleted)
            setsFound = try container.decodeIfPresent(
                Int.self, forKey: .setsFound)
        }
    }

    public struct CountedItem: Decodable, Identifiable, Sendable {
        public let name: String
        public let count: Int?

        public var id: String { name }
    }

    public struct AdoptionItem: Decodable, Identifiable, Sendable {
        public let name: String
        public let percent: Int?

        public var id: String { name }
    }

    public struct Activity: Decodable, Sendable {
        public let gamesStarted: Int?
        public let gamesCompleted: Int?
        public let setsFound: Int?

        public init(gamesStarted: Int?, gamesCompleted: Int?, setsFound: Int?) {
            self.gamesStarted = gamesStarted
            self.gamesCompleted = gamesCompleted
            self.setsFound = setsFound
        }

        public enum CodingKeys: String, CodingKey {
            case gamesStarted = "games_started"
            case gamesCompleted = "games_completed"
            case setsFound = "sets_found"
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            gamesStarted = try container.decodeIfPresent(
                Int.self, forKey: .gamesStarted)
            gamesCompleted = try container.decodeIfPresent(
                Int.self, forKey: .gamesCompleted)
            setsFound = try container.decodeIfPresent(
                Int.self, forKey: .setsFound)
        }
    }

    public struct Latest: Decodable, Sendable {
        public let period: String
        public let inProgress: Bool
        public let reportingDevices: Int?
        public let activity: Activity
        public let modes: [AdoptionItem]

        public enum CodingKeys: String, CodingKey {
            case period
            case inProgress = "in_progress"
            case reportingDevices = "reporting_devices"
            case activity, modes
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            period = try container.decode(String.self, forKey: .period)
            inProgress = try container.decodeIfPresent(
                Bool.self, forKey: .inProgress) ?? false
            reportingDevices = try container.decodeIfPresent(
                Int.self, forKey: .reportingDevices)
            activity = try container.decodeIfPresent(
                Activity.self, forKey: .activity)
                ?? Activity(gamesStarted: nil, gamesCompleted: nil, setsFound: nil)
            modes = try container.decodeIfPresent(
                [AdoptionItem].self, forKey: .modes) ?? []
        }
    }

    public let schema: Int
    public let generatedOn: String
    public let privacy: Privacy
    public let weeklyActive: [WeeklyActive]
    public let latest: Latest?

    public enum CodingKeys: String, CodingKey {
        case schema
        case generatedOn = "generated_on"
        case privacy
        case weeklyActive = "weekly_active"
        case latest
    }
}

public enum ESTTelemetry {
    public enum Event: String, CaseIterable {
        case launch = "launches"
        case gamesStarted = "games_started"
        case gamesCompleted = "games_completed"
        case setFound = "sets_found"
        case fullSoloStarted = "full_solo_started"
        case fullSoloCompleted = "full_solo_completed"
        case quickSoloStarted = "quick_solo_started"
        case quickSoloCompleted = "quick_solo_completed"
        case localDuelStarted = "local_duel_started"
        case localDuelCompleted = "local_duel_completed"
        case networkDuelStarted = "network_duel_started"
        case networkDuelCompleted = "network_duel_completed"
        case hintUsed = "hints_used"
        case tutorialViewed = "tutorial_viewed"
        case leaderboardViewed = "leaderboard_viewed"
    }

    private struct ActivityState: Codable {
        public let period: String
        public var counts: [String: Int]
    }

    private static var identity: GameIdentity { GameIdentity.current }
    public static var enabledKey: String { identity.defaultsKey("TelemetryEnabled") }
    public static var lastSubmittedPeriodKey: String { identity.defaultsKey("TelemetryLastSubmittedPeriod") }
    public static var endpointKey: String { identity.defaultsKey("TelemetryEndpoint") }
    private static var endpointInfoKey: String { identity.infoKey("TelemetryEndpoint") }
    private static var consentVersionKey: String { identity.defaultsKey("TelemetryConsentVersion") }
    private static let consentVersion = 2
    public static let schemaVersion = 1
    public static var product: String { identity.product }

    /// The first-party EST target reports to the dedicated EST Worker. Forks
    /// can replace this with the Info.plist or UserDefaults override.
    public static let defaultEndpoint = GameIdentity.defaultTelemetryEndpoint
    public static let sourceURL = URL(string: "https://github.com/michellzappa/games/blob/main/EST/Models/Telemetry.swift")!
    public static let privacyURL = URL(string: "https://github.com/michellzappa/games/blob/main/PRIVACY.md")!

    private static var activityKey: String { identity.defaultsKey("TelemetryActivity") }
    private static var installSecretService: String { identity.telemetryKeychainService }
    private static let installSecretAccount = "install-secret"

    /// Diagnostics are enabled by default on new installs. Existing installs
    /// keep the choice already stored on the device.
    public static var enabled: Bool {
        migrateConsentIfNeeded()
        return (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true
    }

    /// Mark the current default without overwriting an existing choice. This
    /// lets fresh installs start enabled while preserving an earlier opt-out.
    public static func migrateConsentIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: consentVersionKey) < consentVersion else {
            return
        }
        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(true, forKey: enabledKey)
        }
        defaults.set(consentVersion, forKey: consentVersionKey)
    }

    public static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled {
            deletePendingBatch()
            // Do not retain activity recorded before consent was withdrawn.
            UserDefaults.standard.removeObject(forKey: activityKey)
            // Keep the secret so toggling cannot create a new weekly identity.
        }
        NotificationCenter.default.post(name: .estTelemetryChanged, object: nil)
    }

    public static var endpoint: URL? {
        let infoEndpoint = (Bundle.main.object(
            forInfoDictionaryKey: endpointInfoKey
        ) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = UserDefaults.standard.string(forKey: endpointKey)
            ?? (infoEndpoint?.isEmpty == false ? infoEndpoint : nil)
            ?? defaultEndpoint
        guard let url = URL(string: raw),
              url.scheme == "https"
                || (url.scheme == "http"
                    && (url.host == "127.0.0.1" || url.host == "localhost"))
        else { return nil }
        return url
    }

    public static var communityEndpoint: URL? {
        guard let endpoint else { return nil }
        var components = URLComponents(
            url: endpoint,
            resolvingAgainstBaseURL: false
        )
        components?.path = "/v1/community"
        components?.queryItems = [URLQueryItem(name: "product", value: product)]
        components?.fragment = nil
        return components?.url
    }

    public static var pendingURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(identity.telemetryDirectory)
            .appendingPathComponent("pending.json")
    }

    public static func loadPendingBatch() -> ESTTelemetryBatch? {
        guard enabled,
              let data = try? Data(contentsOf: pendingURL)
        else { return nil }
        return try? JSONDecoder().decode(ESTTelemetryBatch.self, from: data)
    }

    public static func savePendingBatch(_ batch: ESTTelemetryBatch) {
        guard enabled else { return }
        let url = pendingURL
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(batch)
            let temporary = directory.appendingPathComponent(
                ".pending-\(UUID().uuidString).tmp")
            try data.write(to: temporary, options: .atomic)
            if FileManager.default.fileExists(atPath: url.path) {
                _ = try FileManager.default.replaceItemAt(
                    url, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: url)
            }
        } catch {
            // Diagnostics are strictly best effort. They must never affect play.
        }
    }

    public static func deletePendingBatch() {
        try? FileManager.default.removeItem(at: pendingURL)
    }

    public static func record(_ event: Event) {
        record(key: event.rawValue)
    }

    /// Counts one activity key. A game defines its own key enum and calls
    /// this; the Worker whitelists keys per product, so an unknown key is
    /// dropped there, never stored.
    public static func record(key: String) {
        guard enabled else { return }
        let period = currentPeriod()
        var state = currentActivity(for: period)
        let count = state.counts[key, default: 0]
        state.counts[key] = min(count + 1, 999_999)
        saveActivity(state)
    }

    public static func prepareCurrentPeriod() {
        guard enabled else { return }
        _ = currentActivity(for: currentPeriod())
    }

    public static func currentPeriod(_ date: Date = .now) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    /// The ISO week before `period`, including the year boundary.
    public static func previousPeriod(of period: String) -> String? {
        guard period.count == 8,
              let year = Int(period.prefix(4)),
              let week = Int(period.suffix(2))
        else { return nil }
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = calendar.firstWeekday
        guard let start = calendar.date(from: components),
              let previous = calendar.date(byAdding: .day, value: -7, to: start)
        else { return nil }
        return currentPeriod(previous)
    }

    public static func cohort(for period: String, lastSubmitted: String?) -> String {
        guard let lastSubmitted, !lastSubmitted.isEmpty else { return "new" }
        if lastSubmitted == period { return "returning" }
        return lastSubmitted == previousPeriod(of: period)
            ? "returning"
            : "reactivated"
    }

    public static func weekDedupeKey(period: String) -> String {
        let digest = HMAC<SHA256>.authenticationCode(
            for: Data(period.utf8),
            using: SymmetricKey(data: installSecret())
        )
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    public static func makeBatch(period: String = currentPeriod()) -> ESTTelemetryBatch {
        let state = currentActivity(for: period)
        let defaults = UserDefaults.standard
        let activity = state.counts
            .filter { Event(rawValue: $0.key) != nil && $0.value > 0 }

        return ESTTelemetryBatch(
            schema: schemaVersion,
            product: product,
            batchID: UUID().uuidString.lowercased(),
            dedupeKey: weekDedupeKey(period: period),
            period: period,
            cohort: cohort(
                for: period,
                lastSubmitted: defaults.string(forKey: lastSubmittedPeriodKey)
            ),
            app: .init(
                version: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "0",
                build: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleVersion"
                ) as? String ?? "0",
                iOSMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                deviceFamily: UIDevice.current.userInterfaceIdiom == .pad
                    ? "ipad"
                    : "iphone"
            ),
            activity: activity,
            features: [
                "tutorial_seen": defaults.bool(forKey: "hasSeenTutorial"),
                "quick_solo_used": activity[Event.quickSoloStarted.rawValue, default: 0] > 0,
                "local_duel_used": activity[Event.localDuelStarted.rawValue, default: 0] > 0,
                "network_duel_used": activity[Event.networkDuelStarted.rawValue, default: 0] > 0,
                "hints_used": activity[Event.hintUsed.rawValue, default: 0] > 0,
                "sound_effects_enabled": preference(
                    "soundEffectsEnabled", default: true),
                "haptics_enabled": preference("hapticsEnabled", default: true),
                "immersive_game_mode": preference(
                    "immersiveGameMode", default: true),
            ]
        )
    }

    private static func currentActivity(for period: String) -> ActivityState {
        guard let data = UserDefaults.standard.data(forKey: activityKey),
              let saved = try? JSONDecoder().decode(ActivityState.self, from: data),
              saved.period == period
        else {
            let fresh = ActivityState(period: period, counts: [:])
            saveActivity(fresh)
            return fresh
        }
        return saved
    }

    private static func saveActivity(_ state: ActivityState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: activityKey)
        }
    }

    private static func preference(_ key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func installSecret() -> Data {
        if let existing = readInstallSecret(), existing.count == 32 {
            return existing
        }

        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let secret = status == errSecSuccess
            ? Data(bytes)
            : Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        writeInstallSecret(secret)
        return secret
    }

    private static func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: installSecretService,
            kSecAttrAccount as String: installSecretAccount,
        ]
    }

    private static func readInstallSecret() -> Data? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess
        else { return nil }
        return result as? Data
    }

    private static func writeInstallSecret(_ secret: Data) {
        var attributes = keychainQuery()
        attributes[kSecValueData as String] = secret
        attributes[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecDuplicateItem else { return }
        SecItemUpdate(
            keychainQuery() as CFDictionary,
            [kSecValueData as String: secret] as CFDictionary
        )
    }
}

public enum ESTCommunityStatsClient {
    private enum FetchError: Error {
        case unavailable
        case invalidResponse
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    public static func fetch() async throws -> ESTCommunityStats {
        guard let endpoint = ESTTelemetry.communityEndpoint else {
            throw FetchError.unavailable
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else { throw FetchError.invalidResponse }
        return try JSONDecoder().decode(ESTCommunityStats.self, from: data)
    }
}

public extension Notification.Name {
    public static let estTelemetryChanged = Notification.Name("estTelemetryChanged")
}

/// Builds and delivers one aggregate record per ISO week. The record can be
/// refreshed after a completed game without becoming an event stream.
@MainActor
public final class TelemetryCoordinator {
    public static let shared = TelemetryCoordinator()

    private var task: Task<Void, Never>?

    public func start() {
        guard task == nil else { return }
        ESTTelemetry.prepareCurrentPeriod()
        ESTTelemetry.record(.launch)
        task = Task { [weak self] in
            guard let self else { return }
            await run()
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    public func preview() async -> ESTTelemetryBatch {
        ESTTelemetry.makeBatch()
    }

    /// Refreshes the current weekly aggregate after meaningful activity. The
    /// Worker upserts by the week-scoped dedupe key, so this never creates a
    /// second install identity or a per-game row.
    public func flushCurrentPeriod() async {
        guard ESTTelemetry.enabled else { return }

        if let pending = ESTTelemetry.loadPendingBatch() {
            guard await send(pending) else { return }
            ESTTelemetry.deletePendingBatch()
            UserDefaults.standard.set(
                pending.period,
                forKey: ESTTelemetry.lastSubmittedPeriodKey
            )
        }

        let period = ESTTelemetry.currentPeriod()
        let batch = ESTTelemetry.makeBatch(period: period)
        guard await send(batch) else {
            ESTTelemetry.savePendingBatch(batch)
            return
        }
        UserDefaults.standard.set(
            period,
            forKey: ESTTelemetry.lastSubmittedPeriodKey
        )
    }

    private func run() async {
        while !Task.isCancelled {
            await submitIfDue()
            try? await Task.sleep(for: .seconds(6 * 60 * 60))
        }
    }

    private func submitIfDue() async {
        guard ESTTelemetry.enabled else { return }

        if let pending = ESTTelemetry.loadPendingBatch() {
            if await send(pending) {
                ESTTelemetry.deletePendingBatch()
                UserDefaults.standard.set(
                    pending.period,
                    forKey: ESTTelemetry.lastSubmittedPeriodKey
                )
            }
            return
        }

        let period = ESTTelemetry.currentPeriod()
        guard UserDefaults.standard.string(
            forKey: ESTTelemetry.lastSubmittedPeriodKey) != period
        else { return }

        let batch = ESTTelemetry.makeBatch(period: period)
        guard await send(batch) else {
            ESTTelemetry.savePendingBatch(batch)
            return
        }
        UserDefaults.standard.set(
            period,
            forKey: ESTTelemetry.lastSubmittedPeriodKey
        )
    }

    private func send(_ batch: ESTTelemetryBatch) async -> Bool {
        guard ESTTelemetry.enabled,
              let endpoint = ESTTelemetry.endpoint,
              let body = try? JSONEncoder().encode(batch)
        else { return false }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            String(ESTTelemetry.schemaVersion),
            forHTTPHeaderField: GameIdentity.current.header("Telemetry-Schema")
        )
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
