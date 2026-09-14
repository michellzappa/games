import Foundation
import UIKit

/// The small JSON contract used by the in-app feedback form.
///
/// Feedback is intentionally separate from anonymous diagnostics: sending a
/// message does not require diagnostics consent and the message is not added
/// to the weekly telemetry batch.
public struct ESTFeedbackPayload: Codable, Equatable, Sendable {
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

        public init(version: String, build: String, iOSMajor: Int, deviceFamily: String) {
            self.version = version
            self.build = build
            self.iOSMajor = iOSMajor
            self.deviceFamily = deviceFamily
        }
    }

    public let schema: Int
    public let product: String
    public let message: String
    /// Optional. The player supplies this only to receive a reply, and it is
    /// the one field in EST that identifies a person, so it is never stored
    /// with diagnostics and never sent unless the player types it.
    public let replyEmail: String?
    public let app: App

    public enum CodingKeys: String, CodingKey {
        case schema, product, message, app
        case replyEmail = "reply_email"
    }

    public init(
        schema: Int = 1,
        product: String = GameIdentity.current.product,
        message: String,
        replyEmail: String? = nil,
        app: App
    ) {
        self.schema = schema
        self.product = product
        self.message = message
        self.replyEmail = replyEmail
        self.app = app
    }
}

public enum ESTFeedbackService {
    public enum FeedbackError: LocalizedError {
        case invalidMessage
        case invalidEmail
        case unavailable
        case deliveryFailed

        public var errorDescription: String? {
            switch self {
            case .invalidMessage:
                "Write a message before sending feedback."
            case .invalidEmail:
                "Check the email address, or leave it empty to send without a reply."
            case .unavailable, .deliveryFailed:
                "Feedback could not be sent right now. Please try again."
            }
        }
    }

    public static var endpointKey: String { GameIdentity.current.defaultsKey("FeedbackEndpoint") }
    public static var endpointInfoKey: String { GameIdentity.current.infoKey("FeedbackEndpoint") }
    public static let defaultEndpoint = GameIdentity.defaultFeedbackEndpoint
    public static let maxMessageLength = 5_000
    /// RFC 5321 caps an address at 254 characters.
    public static let maxEmailLength = 254
    private static let requestBodyLimit = 12_000

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

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

    public static func normalizedMessage(_ message: String) -> String {
        let normalized = message
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return String(
            normalized.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(maxMessageLength)
        )
    }

    /// Trim and validate a reply address. Returns nil when the field is empty,
    /// which is the normal case: the address is optional. Throws when the
    /// player typed something that is not an address, so the mistake surfaces
    /// here instead of silently losing the only way to answer them.
    public static func normalizedEmail(_ email: String) throws -> String? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= maxEmailLength,
              trimmed.range(
                of: #"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"#,
                options: .regularExpression
              ) != nil
        else { throw FeedbackError.invalidEmail }
        return trimmed
    }

    @MainActor
    public static func send(message: String, replyEmail: String = "") async throws {
        let message = normalizedMessage(message)
        guard !message.isEmpty else { throw FeedbackError.invalidMessage }
        let replyEmail = try normalizedEmail(replyEmail)
        guard let endpoint else { throw FeedbackError.unavailable }

        let payload = ESTFeedbackPayload(
            message: message,
            replyEmail: replyEmail,
            app: .init(
                version: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleShortVersionString"
                ) as? String ?? "unknown",
                build: Bundle.main.object(
                    forInfoDictionaryKey: "CFBundleVersion"
                ) as? String ?? "unknown",
                iOSMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                deviceFamily: UIDevice.current.userInterfaceIdiom == .pad
                    ? "ipad"
                    : "iphone"
            )
        )
        guard let body = try? JSONEncoder().encode(payload),
              body.count <= requestBodyLimit
        else { throw FeedbackError.invalidMessage }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: GameIdentity.current.header("Feedback-Schema"))
        request.httpBody = body

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode)
            else { throw FeedbackError.deliveryFailed }
        } catch let error as FeedbackError {
            throw error
        } catch {
            throw FeedbackError.deliveryFailed
        }
    }
}
