import Foundation

/// A currently-known Twitch EventSub event whose payload is preserved as raw JSON.
///
/// TwitchKit returns this type when Twitch emits a subscription type the SDK recognizes,
/// but does not yet expose as a dedicated field-level model. This keeps future modeling
/// additive while still separating known Twitch events from genuinely unknown future types.
public struct EventSubKnownEvent: Sendable, Equatable {
    /// The known EventSub subscription type.
    public let type: EventSubKnownEventType

    /// The original JSON payload bytes for the event.
    public let payload: Data
}

/// EventSub notification types currently published by Twitch.
public enum EventSubKnownEventType: String, Sendable, Equatable, CaseIterable {
    case automodMessageHold = "automod.message.hold"
    case automodMessageUpdate = "automod.message.update"
    case automodSettingsUpdate = "automod.settings.update"
    case automodTermsUpdate = "automod.terms.update"
    case channelBitsUse = "channel.bits.use"
    case channelUpdate = "channel.update"
    case channelFollow = "channel.follow"
    case channelAdBreakBegin = "channel.ad_break.begin"
    case channelChatClear = "channel.chat.clear"
    case channelChatClearUserMessages = "channel.chat.clear_user_messages"
    case channelChatMessage = "channel.chat.message"
    case channelChatMessageDelete = "channel.chat.message_delete"
    case channelChatNotification = "channel.chat.notification"
    case channelChatSettingsUpdate = "channel.chat_settings.update"
    case channelChatUserMessageHold = "channel.chat.user_message_hold"
    case channelChatUserMessageUpdate = "channel.chat.user_message_update"
    case channelSharedChatBegin = "channel.shared_chat.begin"
    case channelSharedChatUpdate = "channel.shared_chat.update"
    case channelSharedChatEnd = "channel.shared_chat.end"
    case channelSubscribe = "channel.subscribe"
    case channelSubscriptionEnd = "channel.subscription.end"
    case channelSubscriptionGift = "channel.subscription.gift"
    case channelSubscriptionMessage = "channel.subscription.message"
    case channelCheer = "channel.cheer"
    case channelRaid = "channel.raid"
    case channelBan = "channel.ban"
    case channelUnban = "channel.unban"
    case channelUnbanRequestCreate = "channel.unban_request.create"
    case channelUnbanRequestResolve = "channel.unban_request.resolve"
    case channelModerate = "channel.moderate"
    case channelModeratorAdd = "channel.moderator.add"
    case channelModeratorRemove = "channel.moderator.remove"
    case channelGuestStarSessionBegin = "channel.guest_star_session.begin"
    case channelGuestStarSessionEnd = "channel.guest_star_session.end"
    case channelGuestStarGuestUpdate = "channel.guest_star_guest.update"
    case channelGuestStarSettingsUpdate = "channel.guest_star_settings.update"
    case channelPointsAutomaticRewardRedemptionAdd = "channel.channel_points_automatic_reward_redemption.add"
    case channelPointsCustomRewardAdd = "channel.channel_points_custom_reward.add"
    case channelPointsCustomRewardUpdate = "channel.channel_points_custom_reward.update"
    case channelPointsCustomRewardRemove = "channel.channel_points_custom_reward.remove"
    case channelPointsCustomRewardRedemptionAdd = "channel.channel_points_custom_reward_redemption.add"
    case channelPointsCustomRewardRedemptionUpdate = "channel.channel_points_custom_reward_redemption.update"
    case channelCustomPowerUpRedemptionAdd = "channel.custom_power_up_redemption.add"
    case channelPollBegin = "channel.poll.begin"
    case channelPollProgress = "channel.poll.progress"
    case channelPollEnd = "channel.poll.end"
    case channelPredictionBegin = "channel.prediction.begin"
    case channelPredictionProgress = "channel.prediction.progress"
    case channelPredictionLock = "channel.prediction.lock"
    case channelPredictionEnd = "channel.prediction.end"
    case channelSuspiciousUserMessage = "channel.suspicious_user.message"
    case channelSuspiciousUserUpdate = "channel.suspicious_user.update"
    case channelVIPAdd = "channel.vip.add"
    case channelVIPRemove = "channel.vip.remove"
    case channelWarningAcknowledge = "channel.warning.acknowledge"
    case channelWarningSend = "channel.warning.send"
    case channelCharityCampaignDonate = "channel.charity_campaign.donate"
    case channelCharityCampaignStart = "channel.charity_campaign.start"
    case channelCharityCampaignProgress = "channel.charity_campaign.progress"
    case channelCharityCampaignStop = "channel.charity_campaign.stop"
    case conduitShardDisabled = "conduit.shard.disabled"
    case dropEntitlementGrant = "drop.entitlement.grant"
    case extensionBitsTransactionCreate = "extension.bits_transaction.create"
    case channelGoalBegin = "channel.goal.begin"
    case channelGoalProgress = "channel.goal.progress"
    case channelGoalEnd = "channel.goal.end"
    case channelHypeTrainBegin = "channel.hype_train.begin"
    case channelHypeTrainProgress = "channel.hype_train.progress"
    case channelHypeTrainEnd = "channel.hype_train.end"
    case channelShieldModeBegin = "channel.shield_mode.begin"
    case channelShieldModeEnd = "channel.shield_mode.end"
    case channelShoutoutCreate = "channel.shoutout.create"
    case channelShoutoutReceive = "channel.shoutout.receive"
    case streamOnline = "stream.online"
    case streamOffline = "stream.offline"
    case userAuthorizationGrant = "user.authorization.grant"
    case userAuthorizationRevoke = "user.authorization.revoke"
    case userUpdate = "user.update"
    case userWhisperMessage = "user.whisper.message"
}

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
