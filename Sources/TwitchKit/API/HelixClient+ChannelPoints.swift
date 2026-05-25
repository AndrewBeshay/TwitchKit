import Foundation

extension HelixClient {
    public func fetchCustomRewards(
        broadcasterID: String,
        ids: [String] = [],
        onlyManageableRewards: Bool? = nil
    ) async throws -> [CustomReward] {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("id", values: ids)
        HelixQuery.append(onlyManageableRewards.map { URLQueryItem(name: "only_manageable_rewards", value: String($0)) }, to: &queryItems)

        let response: HelixResponse<CustomReward> = try await request(
            endpoint: "channel_points/custom_rewards",
            queryItems: queryItems
        )
        return response.data
    }

    public func createCustomReward(broadcasterID: String, request create: CustomRewardCreateRequest) async throws -> CustomReward {
        let response: HelixResponse<CustomReward> = try await request(
            endpoint: "channel_points/custom_rewards",
            method: "POST",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)],
            body: try JSONEncoder.twitch().encode(create)
        )
        guard let reward = response.data.first else { throw HelixError.notFound }
        return reward
    }

    public func updateCustomReward(
        broadcasterID: String,
        rewardID: String,
        with update: CustomRewardUpdateRequest
    ) async throws -> CustomReward {
        let response: HelixResponse<CustomReward> = try await request(
            endpoint: "channel_points/custom_rewards",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "id", value: rewardID)
            ],
            body: try JSONEncoder.twitch().encode(update)
        )
        guard let reward = response.data.first else { throw HelixError.notFound }
        return reward
    }

    public func deleteCustomReward(broadcasterID: String, rewardID: String) async throws {
        try await requestNoContent(
            endpoint: "channel_points/custom_rewards",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "id", value: rewardID)
            ]
        )
    }

    public func fetchCustomRewardRedemptionsPage(
        broadcasterID: String,
        rewardID: String,
        ids: [String] = [],
        status: ChannelPointsRedemptionStatus? = nil,
        sort: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<CustomRewardRedemption> {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "reward_id", value: rewardID)
        ]
        queryItems += HelixQuery.items("id", values: ids)
        HelixQuery.append(HelixQuery.item("status", status?.rawValue), to: &queryItems)
        HelixQuery.append(HelixQuery.item("sort", sort), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<CustomRewardRedemption> = try await request(
            endpoint: "channel_points/custom_rewards/redemptions",
            queryItems: queryItems
        )
        return response.page
    }

    public func updateCustomRewardRedemptionStatus(
        broadcasterID: String,
        rewardID: String,
        redemptionIDs: [String],
        status: ChannelPointsRedemptionStatus
    ) async throws -> [CustomRewardRedemption] {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "reward_id", value: rewardID)
        ]
        queryItems += HelixQuery.items("id", values: redemptionIDs)

        let response: HelixResponse<CustomRewardRedemption> = try await request(
            endpoint: "channel_points/custom_rewards/redemptions",
            method: "PATCH",
            queryItems: queryItems,
            body: try JSONEncoder.twitch().encode(["status": status.rawValue])
        )
        return response.data
    }
}

public struct CustomReward: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let id: String
    public let title: String
    public let prompt: String
    public let cost: Int
    public let image: CustomRewardImage?
    public let defaultImage: CustomRewardImage
    public let backgroundColor: String
    public let isEnabled: Bool
    public let isUserInputRequired: Bool
    public let maxPerStreamSetting: CustomRewardLimitSetting
    public let maxPerUserPerStreamSetting: CustomRewardLimitSetting
    public let globalCooldownSetting: CustomRewardCooldownSetting
    public let isPaused: Bool
    public let isInStock: Bool
    public let shouldRedemptionsSkipRequestQueue: Bool
    public let redemptionsRedeemedCurrentStream: Int?
    public let cooldownExpiresAt: Date?
}

public struct CustomRewardImage: Decodable, Sendable, Equatable {
    public let url1X: String
    public let url2X: String
    public let url4X: String

    enum CodingKeys: String, CodingKey {
        case url1X = "url_1x"
        case url2X = "url_2x"
        case url4X = "url_4x"
    }
}

public struct CustomRewardLimitSetting: Codable, Sendable, Equatable {
    public let isEnabled: Bool
    public let value: Int?
}

public struct CustomRewardCooldownSetting: Codable, Sendable, Equatable {
    public let isEnabled: Bool
    public let globalCooldownSeconds: Int?
}

public struct CustomRewardCreateRequest: Encodable, Sendable, Equatable {
    public let title: String
    public let cost: Int
    public let prompt: String?
    public let isEnabled: Bool?
    public let backgroundColor: String?
    public let isUserInputRequired: Bool?
    public let isMaxPerStreamEnabled: Bool?
    public let maxPerStream: Int?
    public let isMaxPerUserPerStreamEnabled: Bool?
    public let maxPerUserPerStream: Int?
    public let isGlobalCooldownEnabled: Bool?
    public let globalCooldownSeconds: Int?
    public let shouldRedemptionsSkipRequestQueue: Bool?

    public init(
        title: String,
        cost: Int,
        prompt: String? = nil,
        isEnabled: Bool? = nil,
        backgroundColor: String? = nil,
        isUserInputRequired: Bool? = nil,
        isMaxPerStreamEnabled: Bool? = nil,
        maxPerStream: Int? = nil,
        isMaxPerUserPerStreamEnabled: Bool? = nil,
        maxPerUserPerStream: Int? = nil,
        isGlobalCooldownEnabled: Bool? = nil,
        globalCooldownSeconds: Int? = nil,
        shouldRedemptionsSkipRequestQueue: Bool? = nil
    ) {
        self.title = title
        self.cost = cost
        self.prompt = prompt
        self.isEnabled = isEnabled
        self.backgroundColor = backgroundColor
        self.isUserInputRequired = isUserInputRequired
        self.isMaxPerStreamEnabled = isMaxPerStreamEnabled
        self.maxPerStream = maxPerStream
        self.isMaxPerUserPerStreamEnabled = isMaxPerUserPerStreamEnabled
        self.maxPerUserPerStream = maxPerUserPerStream
        self.isGlobalCooldownEnabled = isGlobalCooldownEnabled
        self.globalCooldownSeconds = globalCooldownSeconds
        self.shouldRedemptionsSkipRequestQueue = shouldRedemptionsSkipRequestQueue
    }
}

public struct CustomRewardUpdateRequest: Encodable, Sendable, Equatable {
    public let title: String?
    public let cost: Int?
    public let prompt: String?
    public let isEnabled: Bool?
    public let backgroundColor: String?
    public let isUserInputRequired: Bool?
    public let isMaxPerStreamEnabled: Bool?
    public let maxPerStream: Int?
    public let isMaxPerUserPerStreamEnabled: Bool?
    public let maxPerUserPerStream: Int?
    public let isGlobalCooldownEnabled: Bool?
    public let globalCooldownSeconds: Int?
    public let isPaused: Bool?
    public let shouldRedemptionsSkipRequestQueue: Bool?

    public init(
        title: String? = nil,
        cost: Int? = nil,
        prompt: String? = nil,
        isEnabled: Bool? = nil,
        backgroundColor: String? = nil,
        isUserInputRequired: Bool? = nil,
        isMaxPerStreamEnabled: Bool? = nil,
        maxPerStream: Int? = nil,
        isMaxPerUserPerStreamEnabled: Bool? = nil,
        maxPerUserPerStream: Int? = nil,
        isGlobalCooldownEnabled: Bool? = nil,
        globalCooldownSeconds: Int? = nil,
        isPaused: Bool? = nil,
        shouldRedemptionsSkipRequestQueue: Bool? = nil
    ) {
        self.title = title
        self.cost = cost
        self.prompt = prompt
        self.isEnabled = isEnabled
        self.backgroundColor = backgroundColor
        self.isUserInputRequired = isUserInputRequired
        self.isMaxPerStreamEnabled = isMaxPerStreamEnabled
        self.maxPerStream = maxPerStream
        self.isMaxPerUserPerStreamEnabled = isMaxPerUserPerStreamEnabled
        self.maxPerUserPerStream = maxPerUserPerStream
        self.isGlobalCooldownEnabled = isGlobalCooldownEnabled
        self.globalCooldownSeconds = globalCooldownSeconds
        self.isPaused = isPaused
        self.shouldRedemptionsSkipRequestQueue = shouldRedemptionsSkipRequestQueue
    }
}

public struct CustomRewardRedemption: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let broadcasterLogin: String
    public let broadcasterName: String
    public let id: String
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let userInput: String
    public let status: ChannelPointsRedemptionStatus
    public let redeemedAt: Date
    public let reward: RedemptionReward

    public struct RedemptionReward: Decodable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let prompt: String
        public let cost: Int
    }
}
