import Foundation

extension HelixClient {
    /// Gets EventSub conduits for the authenticated client.
    public func fetchConduits() async throws -> [EventSubConduit] {
        let response: HelixResponse<EventSubConduit> = try await request(endpoint: "eventsub/conduits")
        return response.data
    }

    /// Creates an EventSub conduit.
    public func createConduit(shardCount: Int) async throws -> EventSubConduit {
        let response: HelixResponse<EventSubConduit> = try await request(
            endpoint: "eventsub/conduits",
            method: "POST",
            body: try JSONEncoder.twitch().encode(ConduitCreateRequest(shardCount: shardCount))
        )
        guard let conduit = response.data.first else { throw HelixError.notFound }
        return conduit
    }

    /// Updates an EventSub conduit's shard count.
    public func updateConduit(id: String, shardCount: Int) async throws -> EventSubConduit {
        let response: HelixResponse<EventSubConduit> = try await request(
            endpoint: "eventsub/conduits",
            method: "PATCH",
            body: try JSONEncoder.twitch().encode(ConduitUpdateRequest(id: id, shardCount: shardCount))
        )
        guard let conduit = response.data.first else { throw HelixError.notFound }
        return conduit
    }

    /// Deletes an EventSub conduit.
    public func deleteConduit(id: String) async throws {
        try await requestNoContent(
            endpoint: "eventsub/conduits",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: id)]
        )
    }

    /// Gets one page of EventSub conduit shards.
    public func fetchConduitShardsPage(
        conduitID: String,
        status: ConduitShardStatus? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<EventSubConduitShard> {
        var queryItems = [URLQueryItem(name: "conduit_id", value: conduitID)]
        HelixQuery.append(HelixQuery.item("status", status?.rawValue), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<EventSubConduitShard> = try await request(
            endpoint: "eventsub/conduits/shards",
            queryItems: queryItems
        )
        return response.page
    }

    /// Updates one or more EventSub conduit shards.
    public func updateConduitShards(
        conduitID: String,
        shards: [EventSubConduitShardUpdate]
    ) async throws -> [EventSubConduitShardUpdateResult] {
        let response: HelixResponse<EventSubConduitShardUpdateResult> = try await request(
            endpoint: "eventsub/conduits/shards",
            method: "PATCH",
            body: try JSONEncoder.twitch().encode(ConduitShardsUpdateRequest(
                conduitId: conduitID,
                shards: shards
            ))
        )
        return response.data
    }
}

private struct ConduitCreateRequest: Encodable {
    let shardCount: Int
}

private struct ConduitUpdateRequest: Encodable {
    let id: String
    let shardCount: Int
}

private struct ConduitShardsUpdateRequest: Encodable {
    let conduitId: String
    let shards: [EventSubConduitShardUpdate]
}

public struct EventSubConduit: Decodable, Sendable, Equatable {
    public let id: String
    public let shardCount: Int
}

public enum ConduitShardStatus: String, Sendable, Equatable {
    case enabled
    case webhookCallbackVerificationPending = "webhook_callback_verification_pending"
    case webhookCallbackVerificationFailed = "webhook_callback_verification_failed"
    case notificationFailuresExceeded = "notification_failures_exceeded"
    case websocketDisconnected = "websocket_disconnected"
    case websocketFailedPingPong = "websocket_failed_ping_pong"
    case websocketReceivedInboundTraffic = "websocket_received_inbound_traffic"
    case websocketConnectionUnused = "websocket_connection_unused"
}

public struct EventSubConduitShard: Decodable, Sendable, Equatable {
    public let id: String
    public let status: String
    public let transport: EventSubConduitShardTransport
}

public struct EventSubConduitShardUpdate: Encodable, Sendable, Equatable {
    public let id: String
    public let transport: EventSubConduitShardTransport

    public init(id: String, transport: EventSubConduitShardTransport) {
        self.id = id
        self.transport = transport
    }
}

public struct EventSubConduitShardUpdateResult: Decodable, Sendable, Equatable {
    public let id: String
    public let status: String
    public let transport: EventSubConduitShardTransport
}

public struct EventSubConduitShardTransport: Codable, Sendable, Equatable {
    public let method: EventSubTransportMethod
    public let callback: URL?
    public let secret: String?
    public let sessionId: String?

    public init(
        method: EventSubTransportMethod,
        callback: URL? = nil,
        secret: String? = nil,
        sessionID: String? = nil
    ) {
        self.method = method
        self.callback = callback
        self.secret = secret
        self.sessionId = sessionID
    }
}
