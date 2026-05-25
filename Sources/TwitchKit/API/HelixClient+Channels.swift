import Foundation

extension HelixClient {
    /// Gets information about the specified channel.
    ///
    /// Returns the channel's title, game, language, tags, delay, content classification labels,
    /// and branded content status. The `delay` field requires a user access token and partner status.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: The channel information.
    /// - SeeAlso: [Get Channel Information](https://dev.twitch.tv/docs/api/reference/#get-channel-information)
    public func fetchChannelInfo(forBroadcasterID broadcasterId: String) async throws -> TwitchChannel {
        let response: HelixResponse<TwitchChannel> = try await request(
            endpoint: "channels",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        guard let channel = response.data.first else { throw HelixError.notFound }
        return channel
    }
    /// Updates a channel's properties.
    ///
    /// All fields are optional, but at least one must be specified.
    /// Returns 204 No Content on success.
    ///
    /// Requires `channel:manage:broadcast` scope. The `broadcasterId` must match
    /// the authenticated user's ID.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID (must match the authenticated user).
    ///   - update: The channel fields to modify.
    ///
    /// - Throws: `HelixError.badRequest` if no fields specified, title is empty, or tags are invalid.
    ///   `HelixError.unauthorized` if scope is missing or broadcaster_id doesn't match token.
    ///   `HelixError.forbidden` for age/region-restricted CCL changes.
    ///
    /// - SeeAlso: [Modify Channel Information](https://dev.twitch.tv/docs/api/reference/#modify-channel-information)
    public func updateChannelInfo(forBroadcasterID broadcasterId: String, with update: ChannelInfoUpdate) async throws {
        let bodyData = try JSONEncoder.twitch().encode(update)

        try await requestNoContent(
            endpoint: "channels",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)],
            body: bodyData
        )
    }
    /// Gets one page of users who follow the specified broadcaster.
    ///
    /// Requires `moderator:read:followers` scope.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - userId: Optional user ID to check whether a specific user follows the broadcaster.
    ///   - first: Optional page size. Twitch currently allows up to 100.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A page of followers and the next pagination cursor, if any.
    /// - SeeAlso: [Get Channel Followers](https://dev.twitch.tv/docs/api/reference/#get-channel-followers)
    public func fetchChannelFollowersPage(
        forBroadcasterID broadcasterId: String,
        userID userId: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchFollow> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        HelixQuery.append(HelixQuery.item("user_id", userId), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchFollow> = try await request(
            endpoint: "channels/followers",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of users who follow the specified broadcaster.
    ///
    /// Requires `moderator:read:followers` scope.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - userId: Optional user ID to check whether a specific user follows the broadcaster.
    ///   - pageSize: Optional page size. Twitch currently allows up to 100.
    /// - Returns: A lazy async sequence that requests the next page as needed.
    /// - SeeAlso: [Get Channel Followers](https://dev.twitch.tv/docs/api/reference/#get-channel-followers)
    public func channelFollowers(
        forBroadcasterID broadcasterId: String,
        userID userId: String? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchFollow> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        HelixQuery.append(HelixQuery.item("user_id", userId), to: &queryItems)

        return pagedRequest(
            endpoint: "channels/followers",
            queryItems: queryItems,
            pageSize: pageSize
        )
    }
}

/// A content classification label to enable or disable on a channel.
///
/// Used with `updateChannelInfo(contentClassificationLabels:)`.
public struct ContentClassificationLabel: Sendable {
    /// The label ID (e.g., `"Gambling"`, `"SexualThemes"`).
    public let id: String

    /// `true` to enable the label, `false` to remove it.
    public let isEnabled: Bool

    public init(id: String, isEnabled: Bool) {
        self.id = id
        self.isEnabled = isEnabled
    }
}

extension ContentClassificationLabel: Encodable, Equatable {}

/// Request body for modifying channel information.
public struct ChannelInfoUpdate: Encodable, Sendable, Equatable {
    public let title: String?
    public let gameId: String?
    public let broadcasterLanguage: String?
    public let delay: Int?
    public let tags: [String]?
    public let contentClassificationLabels: [ContentClassificationLabel]?
    public let isBrandedContent: Bool?

    public init(
        title: String? = nil,
        gameId: String? = nil,
        broadcasterLanguage: String? = nil,
        delay: Int? = nil,
        tags: [String]? = nil,
        contentClassificationLabels: [ContentClassificationLabel]? = nil,
        isBrandedContent: Bool? = nil
    ) {
        self.title = title
        self.gameId = gameId
        self.broadcasterLanguage = broadcasterLanguage
        self.delay = delay
        self.tags = tags
        self.contentClassificationLabels = contentClassificationLabels
        self.isBrandedContent = isBrandedContent
    }

    enum CodingKeys: String, CodingKey {
        case title
        case gameId
        case broadcasterLanguage
        case delay
        case tags
        case contentClassificationLabels
        case isBrandedContent
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(gameId, forKey: .gameId)
        try container.encodeIfPresent(broadcasterLanguage, forKey: .broadcasterLanguage)
        try container.encodeIfPresent(delay, forKey: .delay)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encodeIfPresent(contentClassificationLabels, forKey: .contentClassificationLabels)
        try container.encodeIfPresent(isBrandedContent, forKey: .isBrandedContent)
    }
}
