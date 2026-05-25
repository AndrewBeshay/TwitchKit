import Foundation

extension HelixClient {
    /// Creates an EventSub subscription for the given event type.
    ///
    /// - Parameters:
    ///   - type: Event type (e.g., `"channel.chat.message"`, `"channel.follow"`).
    ///   - version: Event version (e.g., `"1"`, `"2"`).
    ///   - condition: Event-specific condition fields (e.g., `broadcaster_user_id`, `user_id`).
    ///   - transport: The EventSub delivery transport.
    /// - Throws: `HelixError.badRequest` if the subscription fails.
    /// - SeeAlso: [Create EventSub Subscription](https://dev.twitch.tv/docs/api/reference/#create-eventsub-subscription)
    public func createEventSubSubscription(
        type: String,
        version: String,
        condition: [String: String],
        transport: EventSubSubscriptionTransport
    ) async throws {
        let payload = EventSubSubscriptionRequest(
            type: type,
            version: version,
            condition: condition,
            transport: transport
        )
        let bodyData = try JSONEncoder.twitch().encode(payload)

        try await requestAccepted(
            endpoint: "eventsub/subscriptions",
            method: "POST",
            body: bodyData,
            fallbackMessage: "EventSub subscription failed"
        )
    }

    /// Creates a WebSocket EventSub subscription for the given event type.
    ///
    /// The `sessionId` comes from the `session_welcome` message received after connecting
    /// to `wss://eventsub.wss.twitch.tv/ws`.
    ///
    /// Must be called within 10 seconds of receiving the welcome message.
    ///
    /// - Parameters:
    ///   - type: Event type (e.g., `"channel.chat.message"`, `"channel.follow"`).
    ///   - version: Event version (e.g., `"1"`, `"2"`).
    ///   - condition: Event-specific condition fields (e.g., `broadcaster_user_id`, `user_id`).
    ///   - sessionId: WebSocket session ID from the `session_welcome` message.
    /// - Throws: `HelixError.badRequest` if the subscription fails.
    /// - SeeAlso: [Create EventSub Subscription](https://dev.twitch.tv/docs/api/reference/#create-eventsub-subscription)
    public func createEventSubSubscription(
        type: String,
        version: String,
        condition: [String: String],
        sessionId: String
    ) async throws {
        try await createEventSubSubscription(
            type: type,
            version: version,
            condition: condition,
            transport: .websocket(sessionID: sessionId)
        )
    }
}

private struct EventSubSubscriptionRequest: Encodable {
    let type: String
    let version: String
    let condition: [String: String]
    let transport: EventSubSubscriptionTransport
}

/// Delivery transport used when creating an EventSub subscription.
///
/// Twitch supports webhook, WebSocket, and conduit transports for subscription creation.
public struct EventSubSubscriptionTransport: Encodable, Sendable, Equatable {
    let method: String
    let callback: URL?
    let secret: String?
    let sessionId: String?
    let conduitId: String?

    private init(
        method: String,
        callback: URL? = nil,
        secret: String? = nil,
        sessionId: String? = nil,
        conduitId: String? = nil
    ) {
        self.method = method
        self.callback = callback
        self.secret = secret
        self.sessionId = sessionId
        self.conduitId = conduitId
    }

    /// Delivers events to an HTTPS callback URL.
    public static func webhook(callback: URL, secret: String) -> Self {
        Self(method: "webhook", callback: callback, secret: secret)
    }

    /// Delivers events to an EventSub WebSocket session.
    public static func websocket(sessionID: String) -> Self {
        Self(method: "websocket", sessionId: sessionID)
    }

    /// Delivers events through an EventSub conduit.
    public static func conduit(conduitID: String) -> Self {
        Self(method: "conduit", conduitId: conduitID)
    }

    enum CodingKeys: String, CodingKey {
        case method
        case callback
        case secret
        case sessionId = "session_id"
        case conduitId = "conduit_id"
    }
}
