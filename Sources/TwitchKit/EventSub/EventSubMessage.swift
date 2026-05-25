import Foundation

/// Events emitted from the EventSub WebSocket to consumers.
public enum EventSubEvent: Sendable {
    case chatMessage(ChatMessage)
    case channelUpdate(EventSubChannelUpdate)
    case follow(TwitchFollow)
    case subscription(TwitchSubscription)
    case streamOnline(EventSubStreamOnline)
    case streamOffline(EventSubStreamOffline)
    case raid(EventSubRaid)
    case cheer(EventSubCheer)
    case ban(EventSubBan)
    case unban(EventSubUnban)
    case moderatorAdd(EventSubModeratorChange)
    case moderatorRemove(EventSubModeratorChange)
    case channelPointsCustomRewardRedemptionAdd(EventSubChannelPointsCustomRewardRedemption)
    case channelPointsCustomRewardRedemptionUpdate(EventSubChannelPointsCustomRewardRedemption)
    case revocation(EventSubRevocation)
    case unknown(type: String, payload: Data)

    static func decode(type: String, payload data: Data, decoder: JSONDecoder = .twitch()) -> Self {
        switch type {
        case "channel.chat.message":
            if let msg = try? decoder.decode(ChatMessage.self, from: data) {
                return .chatMessage(msg)
            }
        case "channel.update":
            if let event = try? decoder.decode(EventSubChannelUpdate.self, from: data) {
                return .channelUpdate(event)
            }
        case "channel.follow":
            if let follow = try? decoder.decode(TwitchFollow.self, from: data) {
                return .follow(follow)
            }
        case "channel.subscribe":
            if let sub = try? decoder.decode(TwitchSubscription.self, from: data) {
                return .subscription(sub)
            }
        case "stream.online":
            if let event = try? decoder.decode(EventSubStreamOnline.self, from: data) {
                return .streamOnline(event)
            }
        case "stream.offline":
            if let event = try? decoder.decode(EventSubStreamOffline.self, from: data) {
                return .streamOffline(event)
            }
        case "channel.raid":
            if let event = try? decoder.decode(EventSubRaid.self, from: data) {
                return .raid(event)
            }
        case "channel.cheer":
            if let event = try? decoder.decode(EventSubCheer.self, from: data) {
                return .cheer(event)
            }
        case "channel.ban":
            if let event = try? decoder.decode(EventSubBan.self, from: data) {
                return .ban(event)
            }
        case "channel.unban":
            if let event = try? decoder.decode(EventSubUnban.self, from: data) {
                return .unban(event)
            }
        case "channel.moderator.add":
            if let event = try? decoder.decode(EventSubModeratorChange.self, from: data) {
                return .moderatorAdd(event)
            }
        case "channel.moderator.remove":
            if let event = try? decoder.decode(EventSubModeratorChange.self, from: data) {
                return .moderatorRemove(event)
            }
        case "channel.channel_points_custom_reward_redemption.add":
            if let event = try? decoder.decode(EventSubChannelPointsCustomRewardRedemption.self, from: data) {
                return .channelPointsCustomRewardRedemptionAdd(event)
            }
        case "channel.channel_points_custom_reward_redemption.update":
            if let event = try? decoder.decode(EventSubChannelPointsCustomRewardRedemption.self, from: data) {
                return .channelPointsCustomRewardRedemptionUpdate(event)
            }
        default:
            break
        }
        return .unknown(type: type, payload: data)
    }
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
        Chat.message(broadcasterID: broadcasterID, userID: userID)
    }

    public static func makeChannelFollow(broadcasterID: String, moderatorID: String) -> Self {
        Channel.follow(broadcasterID: broadcasterID, moderatorID: moderatorID)
    }

    public static func makeChannelSubscribe(broadcasterID: String) -> Self {
        Channel.subscribe(broadcasterID: broadcasterID)
    }

    public enum Chat {
        public static func message(broadcasterID: String, userID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.chat.message",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID, "user_id": userID]
            )
        }
    }

    public enum Channel {
        public static func update(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.update",
                version: "2",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func follow(broadcasterID: String, moderatorID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.follow",
                version: "2",
                condition: ["broadcaster_user_id": broadcasterID, "moderator_user_id": moderatorID]
            )
        }

        public static func subscribe(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.subscribe",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func raid(toBroadcasterID broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.raid",
                version: "1",
                condition: ["to_broadcaster_user_id": broadcasterID]
            )
        }

        public static func raid(fromBroadcasterID broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.raid",
                version: "1",
                condition: ["from_broadcaster_user_id": broadcasterID]
            )
        }

        public static func cheer(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.cheer",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }
    }

    public enum Stream {
        public static func online(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "stream.online",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func offline(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "stream.offline",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }
    }

    public enum Moderation {
        public static func ban(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.ban",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func unban(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.unban",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func moderatorAdd(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.moderator.add",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }

        public static func moderatorRemove(broadcasterID: String) -> EventSubSubscription {
            EventSubSubscription(
                type: "channel.moderator.remove",
                version: "1",
                condition: ["broadcaster_user_id": broadcasterID]
            )
        }
    }

    public enum ChannelPoints {
        public static func customRewardRedemptionAdd(
            broadcasterID: String,
            rewardID: String? = nil
        ) -> EventSubSubscription {
            customRewardRedemption(
                type: "channel.channel_points_custom_reward_redemption.add",
                broadcasterID: broadcasterID,
                rewardID: rewardID
            )
        }

        public static func customRewardRedemptionUpdate(
            broadcasterID: String,
            rewardID: String? = nil
        ) -> EventSubSubscription {
            customRewardRedemption(
                type: "channel.channel_points_custom_reward_redemption.update",
                broadcasterID: broadcasterID,
                rewardID: rewardID
            )
        }

        private static func customRewardRedemption(
            type: String,
            broadcasterID: String,
            rewardID: String?
        ) -> EventSubSubscription {
            var condition = ["broadcaster_user_id": broadcasterID]
            condition["reward_id"] = rewardID
            return EventSubSubscription(type: type, version: "1", condition: condition)
        }
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
