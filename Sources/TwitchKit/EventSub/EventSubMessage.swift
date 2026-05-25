import Foundation

/// Events emitted from the EventSub WebSocket to consumers.
public enum EventSubEvent: Sendable {
    case chatMessage(ChatMessage)
    case follow(TwitchFollow)
    case subscription(TwitchSubscription)
    case revocation(EventSubRevocation)
    case unknown(type: String, payload: Data)
}

/// A typed EventSub subscription request that can be re-created after reconnecting.
public struct EventSubSubscription: Sendable, Hashable {
    public let type: String
    public let version: String
    public let condition: [String: String]

    public init(type: String, version: String, condition: [String: String]) {
        self.type = type
        self.version = version
        self.condition = condition
    }

    public static func makeChannelChatMessage(broadcasterID: String, userID: String) -> Self {
        Self(
            type: "channel.chat.message",
            version: "1",
            condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
        )
    }

    public static func makeChannelFollow(broadcasterID: String, moderatorID: String) -> Self {
        Self(
            type: "channel.follow",
            version: "2",
            condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
        )
    }

    public static func makeChannelSubscribe(broadcasterID: String) -> Self {
        Self(
            type: "channel.subscribe",
            version: "1",
            condition: ["broadcaster_user_id": broadcasterID]
        )
    }
}

/// An EventSub subscription revocation notification.
public struct EventSubRevocation: Codable, Sendable, Equatable {
    public let id: String
    public let status: String
    public let type: String
    public let version: String
    public let condition: [String: String]
}

/// Raw WebSocket message envelope from Twitch EventSub.
struct EventSubEnvelope: Decodable {
    let metadata: Metadata
    let payload: Payload

    struct Metadata: Decodable {
        let messageId: String
        let messageType: String
        let messageTimestamp: Date
        let subscriptionType: String?
    }

    struct Payload: Decodable {
        // session_welcome
        let session: SessionInfo?

        // notification — raw event data decoded separately per type
        let event: AnyCodable?
        let subscription: EventSubRevocation?

        struct SessionInfo: Decodable {
            let id: String
            let status: String
            let keepaliveTimeoutSeconds: Int?
            let reconnectUrl: String?
            let connectedAt: Date?
        }
    }
}

/// Type-erased Codable wrapper for raw JSON event payloads.
/// Used to capture the event payload before we know its concrete type.
struct AnyCodable: Decodable, Sendable {
    let rawData: Data

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Re-encode to capture the raw JSON bytes
        if let dict = try? container.decode([String: CodableValue].self) {
            rawData = try JSONEncoder().encode(dict)
        } else {
            rawData = Data()
        }
    }
}

/// Simple recursive JSON value type for re-encoding.
enum CodableValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([CodableValue])
    case object([String: CodableValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Double.self) { self = .number(v) }
        else if container.decodeNil() { self = .null }
        else if let v = try? container.decode([CodableValue].self) { self = .array(v) }
        else if let v = try? container.decode([String: CodableValue].self) { self = .object(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}
