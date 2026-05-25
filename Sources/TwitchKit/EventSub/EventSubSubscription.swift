import Foundation

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
