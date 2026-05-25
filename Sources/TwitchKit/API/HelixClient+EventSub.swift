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

/// A mutually exclusive filter for listing EventSub subscriptions.
public enum EventSubSubscriptionFilter: Sendable, Equatable {
    case status(EventSubSubscriptionStatus)
    case type(String)
    case userID(String)
    case subscriptionID(String)
    case conduitID(String)

    var queryItem: URLQueryItem {
        switch self {
        case .status(let status):
            URLQueryItem(name: "status", value: status.rawValue)
        case .type(let type):
            URLQueryItem(name: "type", value: type)
        case .userID(let userID):
            URLQueryItem(name: "user_id", value: userID)
        case .subscriptionID(let subscriptionID):
            URLQueryItem(name: "subscription_id", value: subscriptionID)
        case .conduitID(let conduitID):
            URLQueryItem(name: "conduit_id", value: conduitID)
        }
    }
}

/// A page of EventSub subscriptions plus account-level cost metadata.
public struct EventSubSubscriptionsPage: Sendable, Equatable {
    public let data: [EventSubSubscriptionRecord]
    public let pagination: Pagination?
    public let total: Int?
    public let totalCost: Int?
    public let maxTotalCost: Int?

    public init(
        data: [EventSubSubscriptionRecord],
        pagination: Pagination? = nil,
        total: Int? = nil,
        totalCost: Int? = nil,
        maxTotalCost: Int? = nil
    ) {
        self.data = data
        self.pagination = pagination
        self.total = total
        self.totalCost = totalCost
        self.maxTotalCost = maxTotalCost
    }

    public var nextCursor: String? {
        pagination?.cursor
    }
}

/// An EventSub subscription returned by Twitch.
public struct EventSubSubscriptionRecord: Decodable, Sendable, Equatable {
    public let id: String
    public let status: EventSubSubscriptionStatus
    public let type: String
    public let version: String
    public let condition: [String: String]
    public let createdAt: Date
    public let transport: Transport
    public let cost: Int

    public struct Transport: Decodable, Sendable, Equatable {
        public let method: String
        public let callback: URL?
        public let sessionId: String?
        public let connectedAt: Date?
        public let disconnectedAt: Date?
        public let conduitId: String?
    }
}

/// EventSub subscription status returned by Twitch.
public enum EventSubSubscriptionStatus: Sendable, Equatable {
    case enabled
    case webhookCallbackVerificationPending
    case webhookCallbackVerificationFailed
    case notificationFailuresExceeded
    case authorizationRevoked
    case moderatorRemoved
    case userRemoved
    case chatUserBanned
    case versionRemoved
    case betaMaintenance
    case websocketDisconnected
    case websocketFailedPingPong
    case websocketReceivedInboundTraffic
    case websocketConnectionUnused
    case websocketInternalError
    case websocketNetworkTimeout
    case websocketNetworkError
    case websocketFailedToReconnect
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .enabled: "enabled"
        case .webhookCallbackVerificationPending: "webhook_callback_verification_pending"
        case .webhookCallbackVerificationFailed: "webhook_callback_verification_failed"
        case .notificationFailuresExceeded: "notification_failures_exceeded"
        case .authorizationRevoked: "authorization_revoked"
        case .moderatorRemoved: "moderator_removed"
        case .userRemoved: "user_removed"
        case .chatUserBanned: "chat_user_banned"
        case .versionRemoved: "version_removed"
        case .betaMaintenance: "beta_maintenance"
        case .websocketDisconnected: "websocket_disconnected"
        case .websocketFailedPingPong: "websocket_failed_ping_pong"
        case .websocketReceivedInboundTraffic: "websocket_received_inbound_traffic"
        case .websocketConnectionUnused: "websocket_connection_unused"
        case .websocketInternalError: "websocket_internal_error"
        case .websocketNetworkTimeout: "websocket_network_timeout"
        case .websocketNetworkError: "websocket_network_error"
        case .websocketFailedToReconnect: "websocket_failed_to_reconnect"
        case .unknown(let value): value
        }
    }
}

extension EventSubSubscriptionStatus: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "enabled": self = .enabled
        case "webhook_callback_verification_pending": self = .webhookCallbackVerificationPending
        case "webhook_callback_verification_failed": self = .webhookCallbackVerificationFailed
        case "notification_failures_exceeded": self = .notificationFailuresExceeded
        case "authorization_revoked": self = .authorizationRevoked
        case "moderator_removed": self = .moderatorRemoved
        case "user_removed": self = .userRemoved
        case "chat_user_banned": self = .chatUserBanned
        case "version_removed": self = .versionRemoved
        case "beta_maintenance": self = .betaMaintenance
        case "websocket_disconnected": self = .websocketDisconnected
        case "websocket_failed_ping_pong": self = .websocketFailedPingPong
        case "websocket_received_inbound_traffic": self = .websocketReceivedInboundTraffic
        case "websocket_connection_unused": self = .websocketConnectionUnused
        case "websocket_internal_error": self = .websocketInternalError
        case "websocket_network_timeout": self = .websocketNetworkTimeout
        case "websocket_network_error": self = .websocketNetworkError
        case "websocket_failed_to_reconnect": self = .websocketFailedToReconnect
        default: self = .unknown(value)
        }
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
