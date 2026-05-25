import Foundation

public struct EventSubChannelUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let title: String
    public let language: String
    public let categoryId: String
    public let categoryName: String
    public let contentClassificationLabels: [String]
}

public struct EventSubStreamOnline: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let type: TwitchStreamType
    public let startedAt: Date
}

public struct EventSubStreamOffline: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct EventSubRaid: Codable, Sendable, Equatable {
    public let fromBroadcasterUserId: String
    public let fromBroadcasterUserLogin: String
    public let fromBroadcasterUserName: String
    public let toBroadcasterUserId: String
    public let toBroadcasterUserLogin: String
    public let toBroadcasterUserName: String
    public let viewers: Int
}

public struct EventSubCheer: Codable, Sendable, Equatable {
    public let isAnonymous: Bool
    public let userId: String?
    public let userLogin: String?
    public let userName: String?
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let message: String
    public let bits: Int
}

public struct EventSubBan: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String
    public let moderatorUserLogin: String
    public let moderatorUserName: String
    public let reason: String
    public let bannedAt: Date
    public let endsAt: Date?
    public let isPermanent: Bool
}

public struct EventSubUnban: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String
    public let moderatorUserLogin: String
    public let moderatorUserName: String
}

public struct EventSubModeratorChange: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct EventSubChannelPointsCustomRewardRedemption: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let userInput: String
    public let status: ChannelPointsRedemptionStatus
    public let reward: Reward
    public let redeemedAt: Date

    public struct Reward: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let prompt: String
        public let cost: Int
    }
}

public struct EventSubChatClear: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct EventSubChatClearUserMessages: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let targetUserId: String
    public let targetUserLogin: String
    public let targetUserName: String
}

public struct EventSubChatMessageDelete: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let targetUserId: String
    public let targetUserLogin: String
    public let targetUserName: String
    public let messageId: String
}

public struct EventSubChatSettingsUpdate: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let emoteMode: Bool
    public let followerMode: Bool
    public let followerModeDurationMinutes: Int?
    public let slowMode: Bool
    public let slowModeWaitTimeSeconds: Int?
    public let subscriberMode: Bool
    public let uniqueChatMode: Bool
}

public struct EventSubSubscriptionGift: Codable, Sendable, Equatable {
    public let userId: String?
    public let userLogin: String?
    public let userName: String?
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let total: Int
    public let tier: SubscriptionTier
    public let cumulativeTotal: Int?
    public let isAnonymous: Bool
}

public struct EventSubSubscriptionMessage: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let tier: SubscriptionTier
    public let message: ChatMessage.ChatMessageBody
    public let cumulativeMonths: Int
    public let durationMonths: Int
    public let streakMonths: Int?
}

public struct EventSubSubscriptionEnd: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let tier: SubscriptionTier
    public let isGift: Bool
}

public struct EventSubUnbanRequest: Codable, Sendable, Equatable {
    public let id: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let text: String?
}

public struct EventSubVIPChange: Codable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
}

public struct EventSubShieldMode: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String
    public let moderatorUserLogin: String
    public let moderatorUserName: String
    public let startedAt: Date?
    public let endedAt: Date?
}

public struct EventSubShoutout: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String?
    public let moderatorUserLogin: String?
    public let moderatorUserName: String?
    public let toBroadcasterUserId: String?
    public let toBroadcasterUserLogin: String?
    public let toBroadcasterUserName: String?
    public let fromBroadcasterUserId: String?
    public let fromBroadcasterUserLogin: String?
    public let fromBroadcasterUserName: String?
    public let viewerCount: Int?
    public let startedAt: Date?
}

public struct EventSubWarning: Codable, Sendable, Equatable {
    public let broadcasterUserId: String
    public let broadcasterUserLogin: String
    public let broadcasterUserName: String
    public let moderatorUserId: String?
    public let moderatorUserLogin: String?
    public let moderatorUserName: String?
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let reason: String?
}
