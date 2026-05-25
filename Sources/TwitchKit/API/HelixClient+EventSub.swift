import Foundation

extension HelixClient {
    /// Creates an EventSub subscription for the given event type.
    ///
    /// Subscribes to Twitch events via WebSocket transport. The `sessionId`
    /// comes from the `session_welcome` message received after connecting
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
        let payload = EventSubSubscriptionRequest(
            type: type,
            version: version,
            condition: condition,
            transport: EventSubTransport(method: "websocket", sessionId: sessionId)
        )
        let bodyData = try JSONEncoder.twitch().encode(payload)

        try await requestAccepted(
            endpoint: "eventsub/subscriptions",
            method: "POST",
            body: bodyData,
            fallbackMessage: "EventSub subscription failed"
        )
    }
}

private struct EventSubSubscriptionRequest: Encodable {
    let type: String
    let version: String
    let condition: [String: String]
    let transport: EventSubTransport
}

private struct EventSubTransport: Encodable {
    let method: String
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case method
        case sessionId = "session_id"
    }
}
