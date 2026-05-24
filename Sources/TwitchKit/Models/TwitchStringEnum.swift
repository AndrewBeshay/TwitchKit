import Foundation

/// A chat message type with forward-compatible support for values Twitch may add later.
public enum ChatMessageType: Codable, Sendable, Equatable {
    case text
    case channelPointsHighlighted
    case channelPointsSubOnly
    case userIntro
    case powerUpsMessageEffect
    case powerUpsGigantifiedEmote
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .text: "text"
        case .channelPointsHighlighted: "channel_points_highlighted"
        case .channelPointsSubOnly: "channel_points_sub_only"
        case .userIntro: "user_intro"
        case .powerUpsMessageEffect: "power_ups_message_effect"
        case .powerUpsGigantifiedEmote: "power_ups_gigantified_emote"
        case .unknown(let value): value
        }
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "text": .text
        case "channel_points_highlighted": .channelPointsHighlighted
        case "channel_points_sub_only": .channelPointsSubOnly
        case "user_intro": .userIntro
        case "power_ups_message_effect": .powerUpsMessageEffect
        case "power_ups_gigantified_emote": .powerUpsGigantifiedEmote
        default: .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A fragment type within an EventSub chat message.
public enum ChatFragmentType: Codable, Sendable, Equatable {
    case text
    case cheermote
    case emote
    case mention
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .text: "text"
        case .cheermote: "cheermote"
        case .emote: "emote"
        case .mention: "mention"
        case .unknown(let value): value
        }
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "text": .text
        case "cheermote": .cheermote
        case "emote": .emote
        case "mention": .mention
        default: .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A Twitch subscription tier.
public enum SubscriptionTier: Codable, Sendable, Equatable {
    case tier1
    case tier2
    case tier3
    case prime
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .tier1: "1000"
        case .tier2: "2000"
        case .tier3: "3000"
        case .prime: "Prime"
        case .unknown(let value): value
        }
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "1000": .tier1
        case "2000": .tier2
        case "3000": .tier3
        case "Prime": .prime
        default: .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A Twitch badge click action with forward-compatible support for new values.
public enum BadgeClickAction: Codable, Sendable, Equatable {
    case none
    case subscribeToChannel
    case visitURL
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .none: "none"
        case .subscribeToChannel: "subscribe_to_channel"
        case .visitURL: "visit_url"
        case .unknown(let value): value
        }
    }

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "none": .none
        case "subscribe_to_channel": .subscribeToChannel
        case "visit_url": .visitURL
        default: .unknown(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
