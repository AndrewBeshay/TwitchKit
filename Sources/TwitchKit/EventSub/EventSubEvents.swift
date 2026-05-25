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
    public let type: String
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
    public let status: String
    public let reward: Reward
    public let redeemedAt: Date

    public struct Reward: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let prompt: String
        public let cost: Int
    }
}
