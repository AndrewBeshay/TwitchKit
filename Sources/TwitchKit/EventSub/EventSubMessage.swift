import Foundation

/// Events emitted from the EventSub WebSocket to consumers.
public enum EventSubEvent: Sendable {
    case chatMessage(ChatMessage)
    case channelUpdate(EventSubChannelUpdate)
    case follow(TwitchFollow)
    case subscription(TwitchSubscription)
    case streamOnline(EventSubStreamOnline)
    case streamOffline(EventSubStreamOffline)
    case automodMessageHold(EventSubAutoModMessage)
    case automodMessageUpdate(EventSubAutoModMessage)
    case automodSettingsUpdate(EventSubAutoModSettingsUpdate)
    case automodTermsUpdate(EventSubAutoModTermsUpdate)
    case bitsUse(EventSubBitsUse)
    case adBreakBegin(EventSubAdBreakBegin)
    case raid(EventSubRaid)
    case cheer(EventSubCheer)
    case ban(EventSubBan)
    case unban(EventSubUnban)
    case moderatorAdd(EventSubModeratorChange)
    case moderatorRemove(EventSubModeratorChange)
    case channelPointsCustomRewardRedemptionAdd(EventSubChannelPointsCustomRewardRedemption)
    case channelPointsCustomRewardRedemptionUpdate(EventSubChannelPointsCustomRewardRedemption)
    case channelPointsCustomRewardAdd(EventSubChannelPointsCustomReward)
    case channelPointsCustomRewardUpdate(EventSubChannelPointsCustomReward)
    case channelPointsCustomRewardRemove(EventSubChannelPointsCustomReward)
    case channelPointsAutomaticRewardRedemptionAdd(EventSubChannelPointsAutomaticRewardRedemption)
    case chatClear(EventSubChatClear)
    case chatClearUserMessages(EventSubChatClearUserMessages)
    case chatMessageDelete(EventSubChatMessageDelete)
    case chatNotification(EventSubChatNotification)
    case chatUserMessageHold(EventSubChatUserMessageModeration)
    case chatUserMessageUpdate(EventSubChatUserMessageModeration)
    case chatSettingsUpdate(EventSubChatSettingsUpdate)
    case sharedChatBegin(EventSubSharedChatSession)
    case sharedChatUpdate(EventSubSharedChatSession)
    case sharedChatEnd(EventSubSharedChatSession)
    case moderate(EventSubModerate)
    case guestStarSessionBegin(EventSubGuestStarSession)
    case guestStarSessionEnd(EventSubGuestStarSession)
    case guestStarGuestUpdate(EventSubGuestStarGuestUpdate)
    case guestStarSettingsUpdate(EventSubGuestStarSettingsUpdate)
    case subscriptionEnd(EventSubSubscriptionEnd)
    case subscriptionGift(EventSubSubscriptionGift)
    case subscriptionMessage(EventSubSubscriptionMessage)
    case pollBegin(EventSubPoll)
    case pollProgress(EventSubPoll)
    case pollEnd(EventSubPoll)
    case predictionBegin(EventSubPrediction)
    case predictionProgress(EventSubPrediction)
    case predictionLock(EventSubPrediction)
    case predictionEnd(EventSubPrediction)
    case goalBegin(EventSubGoal)
    case goalProgress(EventSubGoal)
    case goalEnd(EventSubGoal)
    case hypeTrainBegin(EventSubHypeTrain)
    case hypeTrainProgress(EventSubHypeTrain)
    case hypeTrainEnd(EventSubHypeTrain)
    case charityCampaignDonate(EventSubCharityDonation)
    case charityCampaignStart(EventSubCharityCampaign)
    case charityCampaignProgress(EventSubCharityCampaign)
    case charityCampaignStop(EventSubCharityCampaign)
    case customPowerUpRedemptionAdd(EventSubCustomPowerUpRedemption)
    case suspiciousUserMessage(EventSubSuspiciousUserMessage)
    case suspiciousUserUpdate(EventSubSuspiciousUserUpdate)
    case unbanRequestCreate(EventSubUnbanRequest)
    case unbanRequestResolve(EventSubUnbanRequest)
    case vipAdd(EventSubVIPChange)
    case vipRemove(EventSubVIPChange)
    case shieldModeBegin(EventSubShieldMode)
    case shieldModeEnd(EventSubShieldMode)
    case shoutoutCreate(EventSubShoutout)
    case shoutoutReceive(EventSubShoutout)
    case warningAcknowledge(EventSubWarning)
    case warningSend(EventSubWarning)
    case conduitShardDisabled(EventSubConduitShardDisabled)
    case dropEntitlementGrant(EventSubDropEntitlementGrant)
    case extensionBitsTransactionCreate(EventSubExtensionBitsTransaction)
    case userAuthorizationGrant(EventSubUserAuthorization)
    case userAuthorizationRevoke(EventSubUserAuthorization)
    case userUpdate(EventSubUserUpdate)
    case userWhisperMessage(EventSubWhisperMessage)
    case revocation(EventSubRevocation)
    case known(EventSubKnownEvent)
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
        case "automod.message.hold":
            if let event = try? decoder.decode(EventSubAutoModMessage.self, from: data) {
                return .automodMessageHold(event)
            }
        case "automod.message.update":
            if let event = try? decoder.decode(EventSubAutoModMessage.self, from: data) {
                return .automodMessageUpdate(event)
            }
        case "automod.settings.update":
            if let event = try? decoder.decode(EventSubAutoModSettingsUpdate.self, from: data) {
                return .automodSettingsUpdate(event)
            }
        case "automod.terms.update":
            if let event = try? decoder.decode(EventSubAutoModTermsUpdate.self, from: data) {
                return .automodTermsUpdate(event)
            }
        case "channel.bits.use":
            if let event = try? decoder.decode(EventSubBitsUse.self, from: data) {
                return .bitsUse(event)
            }
        case "channel.ad_break.begin":
            if let event = try? decoder.decode(EventSubAdBreakBegin.self, from: data) {
                return .adBreakBegin(event)
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
        case "channel.channel_points_custom_reward.add":
            if let event = try? decoder.decode(EventSubChannelPointsCustomReward.self, from: data) {
                return .channelPointsCustomRewardAdd(event)
            }
        case "channel.channel_points_custom_reward.update":
            if let event = try? decoder.decode(EventSubChannelPointsCustomReward.self, from: data) {
                return .channelPointsCustomRewardUpdate(event)
            }
        case "channel.channel_points_custom_reward.remove":
            if let event = try? decoder.decode(EventSubChannelPointsCustomReward.self, from: data) {
                return .channelPointsCustomRewardRemove(event)
            }
        case "channel.channel_points_automatic_reward_redemption.add":
            if let event = try? decoder.decode(EventSubChannelPointsAutomaticRewardRedemption.self, from: data) {
                return .channelPointsAutomaticRewardRedemptionAdd(event)
            }
        case "channel.chat.clear":
            if let event = try? decoder.decode(EventSubChatClear.self, from: data) {
                return .chatClear(event)
            }
        case "channel.chat.clear_user_messages":
            if let event = try? decoder.decode(EventSubChatClearUserMessages.self, from: data) {
                return .chatClearUserMessages(event)
            }
        case "channel.chat.message_delete":
            if let event = try? decoder.decode(EventSubChatMessageDelete.self, from: data) {
                return .chatMessageDelete(event)
            }
        case "channel.chat.notification":
            if let event = try? decoder.decode(EventSubChatNotification.self, from: data) {
                return .chatNotification(event)
            }
        case "channel.chat.user_message_hold":
            if let event = try? decoder.decode(EventSubChatUserMessageModeration.self, from: data) {
                return .chatUserMessageHold(event)
            }
        case "channel.chat.user_message_update":
            if let event = try? decoder.decode(EventSubChatUserMessageModeration.self, from: data) {
                return .chatUserMessageUpdate(event)
            }
        case "channel.chat_settings.update":
            if let event = try? decoder.decode(EventSubChatSettingsUpdate.self, from: data) {
                return .chatSettingsUpdate(event)
            }
        case "channel.shared_chat.begin":
            if let event = try? decoder.decode(EventSubSharedChatSession.self, from: data) {
                return .sharedChatBegin(event)
            }
        case "channel.shared_chat.update":
            if let event = try? decoder.decode(EventSubSharedChatSession.self, from: data) {
                return .sharedChatUpdate(event)
            }
        case "channel.shared_chat.end":
            if let event = try? decoder.decode(EventSubSharedChatSession.self, from: data) {
                return .sharedChatEnd(event)
            }
        case "channel.moderate":
            if let event = try? decoder.decode(EventSubModerate.self, from: data) {
                return .moderate(event)
            }
        case "channel.guest_star_session.begin":
            if let event = try? decoder.decode(EventSubGuestStarSession.self, from: data) {
                return .guestStarSessionBegin(event)
            }
        case "channel.guest_star_session.end":
            if let event = try? decoder.decode(EventSubGuestStarSession.self, from: data) {
                return .guestStarSessionEnd(event)
            }
        case "channel.guest_star_guest.update":
            if let event = try? decoder.decode(EventSubGuestStarGuestUpdate.self, from: data) {
                return .guestStarGuestUpdate(event)
            }
        case "channel.guest_star_settings.update":
            if let event = try? decoder.decode(EventSubGuestStarSettingsUpdate.self, from: data) {
                return .guestStarSettingsUpdate(event)
            }
        case "channel.subscription.end":
            if let event = try? decoder.decode(EventSubSubscriptionEnd.self, from: data) {
                return .subscriptionEnd(event)
            }
        case "channel.subscription.gift":
            if let event = try? decoder.decode(EventSubSubscriptionGift.self, from: data) {
                return .subscriptionGift(event)
            }
        case "channel.subscription.message":
            if let event = try? decoder.decode(EventSubSubscriptionMessage.self, from: data) {
                return .subscriptionMessage(event)
            }
        case "channel.poll.begin":
            if let event = try? decoder.decode(EventSubPoll.self, from: data) {
                return .pollBegin(event)
            }
        case "channel.poll.progress":
            if let event = try? decoder.decode(EventSubPoll.self, from: data) {
                return .pollProgress(event)
            }
        case "channel.poll.end":
            if let event = try? decoder.decode(EventSubPoll.self, from: data) {
                return .pollEnd(event)
            }
        case "channel.prediction.begin":
            if let event = try? decoder.decode(EventSubPrediction.self, from: data) {
                return .predictionBegin(event)
            }
        case "channel.prediction.progress":
            if let event = try? decoder.decode(EventSubPrediction.self, from: data) {
                return .predictionProgress(event)
            }
        case "channel.prediction.lock":
            if let event = try? decoder.decode(EventSubPrediction.self, from: data) {
                return .predictionLock(event)
            }
        case "channel.prediction.end":
            if let event = try? decoder.decode(EventSubPrediction.self, from: data) {
                return .predictionEnd(event)
            }
        case "channel.goal.begin":
            if let event = try? decoder.decode(EventSubGoal.self, from: data) {
                return .goalBegin(event)
            }
        case "channel.goal.progress":
            if let event = try? decoder.decode(EventSubGoal.self, from: data) {
                return .goalProgress(event)
            }
        case "channel.goal.end":
            if let event = try? decoder.decode(EventSubGoal.self, from: data) {
                return .goalEnd(event)
            }
        case "channel.hype_train.begin":
            if let event = try? decoder.decode(EventSubHypeTrain.self, from: data) {
                return .hypeTrainBegin(event)
            }
        case "channel.hype_train.progress":
            if let event = try? decoder.decode(EventSubHypeTrain.self, from: data) {
                return .hypeTrainProgress(event)
            }
        case "channel.hype_train.end":
            if let event = try? decoder.decode(EventSubHypeTrain.self, from: data) {
                return .hypeTrainEnd(event)
            }
        case "channel.charity_campaign.donate":
            if let event = try? decoder.decode(EventSubCharityDonation.self, from: data) {
                return .charityCampaignDonate(event)
            }
        case "channel.charity_campaign.start":
            if let event = try? decoder.decode(EventSubCharityCampaign.self, from: data) {
                return .charityCampaignStart(event)
            }
        case "channel.charity_campaign.progress":
            if let event = try? decoder.decode(EventSubCharityCampaign.self, from: data) {
                return .charityCampaignProgress(event)
            }
        case "channel.charity_campaign.stop":
            if let event = try? decoder.decode(EventSubCharityCampaign.self, from: data) {
                return .charityCampaignStop(event)
            }
        case "channel.custom_power_up_redemption.add":
            if let event = try? decoder.decode(EventSubCustomPowerUpRedemption.self, from: data) {
                return .customPowerUpRedemptionAdd(event)
            }
        case "channel.suspicious_user.message":
            if let event = try? decoder.decode(EventSubSuspiciousUserMessage.self, from: data) {
                return .suspiciousUserMessage(event)
            }
        case "channel.suspicious_user.update":
            if let event = try? decoder.decode(EventSubSuspiciousUserUpdate.self, from: data) {
                return .suspiciousUserUpdate(event)
            }
        case "channel.unban_request.create":
            if let event = try? decoder.decode(EventSubUnbanRequest.self, from: data) {
                return .unbanRequestCreate(event)
            }
        case "channel.unban_request.resolve":
            if let event = try? decoder.decode(EventSubUnbanRequest.self, from: data) {
                return .unbanRequestResolve(event)
            }
        case "channel.vip.add":
            if let event = try? decoder.decode(EventSubVIPChange.self, from: data) {
                return .vipAdd(event)
            }
        case "channel.vip.remove":
            if let event = try? decoder.decode(EventSubVIPChange.self, from: data) {
                return .vipRemove(event)
            }
        case "channel.shield_mode.begin":
            if let event = try? decoder.decode(EventSubShieldMode.self, from: data) {
                return .shieldModeBegin(event)
            }
        case "channel.shield_mode.end":
            if let event = try? decoder.decode(EventSubShieldMode.self, from: data) {
                return .shieldModeEnd(event)
            }
        case "channel.shoutout.create":
            if let event = try? decoder.decode(EventSubShoutout.self, from: data) {
                return .shoutoutCreate(event)
            }
        case "channel.shoutout.receive":
            if let event = try? decoder.decode(EventSubShoutout.self, from: data) {
                return .shoutoutReceive(event)
            }
        case "channel.warning.acknowledge":
            if let event = try? decoder.decode(EventSubWarning.self, from: data) {
                return .warningAcknowledge(event)
            }
        case "channel.warning.send":
            if let event = try? decoder.decode(EventSubWarning.self, from: data) {
                return .warningSend(event)
            }
        case "conduit.shard.disabled":
            if let event = try? decoder.decode(EventSubConduitShardDisabled.self, from: data) {
                return .conduitShardDisabled(event)
            }
        case "drop.entitlement.grant":
            if let event = try? decoder.decode(EventSubDropEntitlementGrant.self, from: data) {
                return .dropEntitlementGrant(event)
            }
        case "extension.bits_transaction.create":
            if let event = try? decoder.decode(EventSubExtensionBitsTransaction.self, from: data) {
                return .extensionBitsTransactionCreate(event)
            }
        case "user.authorization.grant":
            if let event = try? decoder.decode(EventSubUserAuthorization.self, from: data) {
                return .userAuthorizationGrant(event)
            }
        case "user.authorization.revoke":
            if let event = try? decoder.decode(EventSubUserAuthorization.self, from: data) {
                return .userAuthorizationRevoke(event)
            }
        case "user.update":
            if let event = try? decoder.decode(EventSubUserUpdate.self, from: data) {
                return .userUpdate(event)
            }
        case "user.whisper.message":
            if let event = try? decoder.decode(EventSubWhisperMessage.self, from: data) {
                return .userWhisperMessage(event)
            }
        default:
            break
        }
        if let knownType = EventSubKnownEventType(rawValue: type) {
            return .known(EventSubKnownEvent(type: knownType, payload: data))
        }
        return .unknown(type: type, payload: data)
    }
}

/// An EventSub subscription revocation notification.
public struct EventSubRevocation: Codable, Sendable, Equatable {
    public let id: String
    public let status: EventSubSubscriptionStatus
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
