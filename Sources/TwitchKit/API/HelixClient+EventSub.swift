import Foundation

extension HelixClient {
    /// Gets one page of EventSub subscriptions created by the authenticated client.
    ///
    /// Twitch allows at most one filter at a time. Use `filter` to select one of the supported
    /// filter query parameters, or pass `nil` to list all subscriptions.
    ///
    /// - Parameters:
    ///   - filter: Optional mutually exclusive filter.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A page containing subscription records and cost totals.
    /// - SeeAlso: [Get EventSub Subscriptions](https://dev.twitch.tv/docs/api/reference/#get-eventsub-subscriptions)
    public func fetchEventSubSubscriptionsPage(
        filter: EventSubSubscriptionFilter? = nil,
        after cursor: String? = nil
    ) async throws -> EventSubSubscriptionsPage {
        try filter?.validate()

        var queryItems: [URLQueryItem] = []
        HelixQuery.append(filter?.queryItem, to: &queryItems)
        HelixQuery.append(HelixQuery.item("after", cursor), to: &queryItems)

        let response: HelixResponse<EventSubSubscriptionRecord> = try await request(
            endpoint: "eventsub/subscriptions",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return EventSubSubscriptionsPage(
            data: response.data,
            pagination: response.pagination,
            total: response.total,
            totalCost: response.totalCost,
            maxTotalCost: response.maxTotalCost
        )
    }

    /// Returns an async sequence of EventSub subscriptions created by the authenticated client.
    ///
    /// - Parameter filter: Optional mutually exclusive filter.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get EventSub Subscriptions](https://dev.twitch.tv/docs/api/reference/#get-eventsub-subscriptions)
    public func eventSubSubscriptions(
        filter: EventSubSubscriptionFilter? = nil
    ) -> HelixPagedSequence<EventSubSubscriptionRecord> {
        HelixPagedSequence { cursor in
            let page = try await fetchEventSubSubscriptionsPage(filter: filter, after: cursor)
            return HelixPage(data: page.data, pagination: page.pagination, total: page.total)
        }
    }

    /// Deletes an EventSub subscription.
    ///
    /// - Parameter id: The subscription ID returned by Twitch.
    /// - SeeAlso: [Delete EventSub Subscription](https://dev.twitch.tv/docs/api/reference/#delete-eventsub-subscription)
    public func deleteEventSubSubscription(id: String) async throws {
        guard !id.isEmpty else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "EventSub subscription ID is required")
            )
        }

        try await requestNoContent(
            endpoint: "eventsub/subscriptions",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: id)]
        )
    }

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
        try transport.validate()
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
        guard !sessionId.isEmpty else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "EventSub WebSocket session ID is required")
            )
        }

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
