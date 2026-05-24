import Foundation

/// A new subscription event from EventSub `channel.subscribe` v1.
///
/// Fired when a user subscribes to the channel (first-time or resub).
/// Requires `channel:read:subscriptions` scope.
///
/// - SeeAlso: [channel.subscribe EventSub](https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/#channelsubscribe)
public struct TwitchSubscription: Codable, Sendable, Equatable {
    /// ID of the subscribing user.
    public let userId: String

    /// Login name of the subscribing user.
    public let userLogin: String?

    /// Display name of the subscribing user.
    public let userName: String

    /// Subscription tier: `"1000"` (Tier 1), `"2000"` (Tier 2), `"3000"` (Tier 3).
    public let tier: String

    /// Whether this subscription was gifted by another user.
    public let isGift: Bool
}
