import Foundation
import os

private let logger = Logger(subsystem: "com.twitchkit", category: "helix")

public struct HelixClient: Sendable {
    private let auth: TwitchAuth
    private let clientId: String

    private static let baseURL = "https://api.twitch.tv/helix/"

    public init(auth: TwitchAuth, clientId: String) {
        self.auth = auth
        self.clientId = clientId
    }

    // MARK: - Generic Request

    func request<T: Decodable & Sendable>(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> HelixResponse<T> {
        var components = URLComponents(string: Self.baseURL + endpoint)!
        components.queryItems = queryItems

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body

        let token = try await auth.accessToken()
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(clientId, forHTTPHeaderField: "Client-Id")
        if body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let httpResponse = response as! HTTPURLResponse

            // Auto-refresh on 401 and retry once
            if httpResponse.statusCode == 401 {
                logger.warning("Helix \(endpoint) returned 401 — refreshing token and retrying")
                try await auth.refreshIfNeeded()
                let newToken = try await auth.accessToken()
                urlRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await URLSession.shared.data(for: urlRequest)
                let retryHttp = retryResponse as! HTTPURLResponse
                return try handleResponse(data: retryData, statusCode: retryHttp.statusCode)
            }

            return try handleResponse(data: data, statusCode: httpResponse.statusCode)
        } catch let error as HelixError {
            throw error
        } catch {
            throw HelixError.networkError(error.localizedDescription)
        }
    }

    private func handleResponse<T: Decodable & Sendable>(data: Data, statusCode: Int) throws -> HelixResponse<T> {
        switch statusCode {
        case 200, 202:
            do {
                return try JSONDecoder.twitch().decode(HelixResponse<T>.self, from: data)
            } catch {
                let rawJSON = String(data: data.prefix(500), encoding: .utf8) ?? "non-utf8"
                logger.error("Helix decode failed for \(String(describing: T.self)): \(error) — JSON: \(rawJSON)")
                throw HelixError.decodingFailed(error.localizedDescription)
            }
        case 400:
            let msg = (try? JSONDecoder.twitch().decode(TwitchErrorResponse.self, from: data))?.message ?? "Bad request"
            throw HelixError.badRequest(msg)
        case 401:
            throw HelixError.unauthorized
        case 403:
            let msg = (try? JSONDecoder.twitch().decode(TwitchErrorResponse.self, from: data))?.message ?? "Forbidden"
            throw HelixError.forbidden(msg)
        case 404:
            throw HelixError.notFound
        case 409:
            let msg = (try? JSONDecoder.twitch().decode(TwitchErrorResponse.self, from: data))?.message ?? "Conflict"
            throw HelixError.conflict(msg)
        case 422:
            let msg = (try? JSONDecoder.twitch().decode(TwitchErrorResponse.self, from: data))?.message ?? "Unprocessable"
            throw HelixError.unprocessable(msg)
        case 429:
            throw HelixError.rateLimited(retryAfter: 60)
        default:
            throw HelixError.serverError(status: statusCode)
        }
    }

    // MARK: - Users

    /// Gets the authenticated user's profile.
    ///
    /// Called with no query parameters to get the user associated with the access token.
    /// Requires `user:read:email` scope for the `email` field.
    ///
    /// - Returns: The authenticated user's profile.
    /// - Throws: `HelixError.notFound` if no user data returned.
    /// - SeeAlso: [Get Users](https://dev.twitch.tv/docs/api/reference/#get-users)
    public func fetchUser() async throws -> TwitchUser {
        let response: HelixResponse<TwitchUser> = try await request(endpoint: "users")
        guard let user = response.data.first else { throw HelixError.notFound }
        return user
    }

    @available(*, deprecated, renamed: "fetchUser")
    public func getUser() async throws -> TwitchUser {
        try await fetchUser()
    }

    // MARK: - Streams

    /// Gets the stream key for the specified broadcaster.
    ///
    /// The stream key is used in the RTMP URL to authenticate the stream.
    /// Requires `channel:read:stream_key` scope.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: The stream key string.
    /// - SeeAlso: [Get Stream Key](https://dev.twitch.tv/docs/api/reference/#get-stream-key)
    public func fetchStreamKey(forBroadcasterID broadcasterId: String) async throws -> String {
        let response: HelixResponse<StreamKeyResponse> = try await request(
            endpoint: "streams/key",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        guard let key = response.data.first?.streamKey else { throw HelixError.notFound }
        return key
    }

    @available(*, deprecated, renamed: "fetchStreamKey(forBroadcasterID:)")
    public func getStreamKey(broadcasterId: String) async throws -> String {
        try await fetchStreamKey(forBroadcasterID: broadcasterId)
    }

    // MARK: - Channels

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

    @available(*, deprecated, renamed: "fetchChannelInfo(forBroadcasterID:)")
    public func getChannelInfo(broadcasterId: String) async throws -> TwitchChannel {
        try await fetchChannelInfo(forBroadcasterID: broadcasterId)
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
    ///   - title: Stream title. May not be empty. Pass `nil` to leave unchanged.
    ///   - gameId: Game/category ID. Use `"0"` or `""` to unset. Pass `nil` to leave unchanged.
    ///   - broadcasterLanguage: ISO 639-1 language code (e.g., `"en"`). Use `"other"` for unsupported languages.
    ///   - delay: Broadcast delay in seconds (0-900). Partners only.
    ///   - tags: Channel tags (max 10, max 25 chars each, no spaces/special chars). Pass `[]` to clear all tags.
    ///   - contentClassificationLabels: Content classification labels to enable/disable.
    ///   - isBrandedContent: Whether the channel has branded content.
    ///
    /// - Throws: `HelixError.badRequest` if no fields specified, title is empty, or tags are invalid.
    ///   `HelixError.unauthorized` if scope is missing or broadcaster_id doesn't match token.
    ///   `HelixError.forbidden` for age/region-restricted CCL changes.
    ///
    /// - SeeAlso: [Modify Channel Information](https://dev.twitch.tv/docs/api/reference/#modify-channel-information)
    public func updateChannelInfo(
        broadcasterId: String,
        title: String? = nil,
        gameId: String? = nil,
        broadcasterLanguage: String? = nil,
        delay: Int? = nil,
        tags: [String]? = nil,
        contentClassificationLabels: [ContentClassificationLabel]? = nil,
        isBrandedContent: Bool? = nil
    ) async throws {
        let requestBody = UpdateChannelInfoRequest(
            title: title,
            gameId: gameId,
            broadcasterLanguage: broadcasterLanguage,
            delay: delay,
            tags: tags,
            contentClassificationLabels: contentClassificationLabels,
            isBrandedContent: isBrandedContent
        )
        let bodyData = try JSONEncoder.twitch().encode(requestBody)

        // PATCH /channels returns 204 No Content — handle directly, not via generic request
        var components = URLComponents(string: Self.baseURL + "channels")!
        components.queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "PATCH"
        urlRequest.httpBody = bodyData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await auth.accessToken()
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(clientId, forHTTPHeaderField: "Client-Id")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let http = response as! HTTPURLResponse

        switch http.statusCode {
        case 204:
            return // Success — no content
        case 400:
            let msg = (try? JSONDecoder.twitch().decode(TwitchErrorResponse.self, from: data))?.message ?? "Bad request"
            throw HelixError.badRequest(msg)
        case 401:
            throw HelixError.unauthorized
        case 403:
            let msg = (try? JSONDecoder.twitch().decode(TwitchErrorResponse.self, from: data))?.message ?? "Forbidden"
            throw HelixError.forbidden(msg)
        case 409:
            throw HelixError.conflict("Branded content flag changed too frequently")
        default:
            throw HelixError.serverError(status: http.statusCode)
        }
    }

    // MARK: - Emotes

    /// Gets the list of global emotes (Twitch-created, usable in any chat).
    ///
    /// Global emotes include built-in emotes like Kappa, PogChamp, etc.
    /// Use `imageURL()` on each emote to construct CDN URLs for rendering.
    ///
    /// - Returns: Array of global emotes with format, scale, and template info.
    /// - SeeAlso: [Get Global Emotes](https://dev.twitch.tv/docs/api/reference/#get-global-emotes)
    public func fetchGlobalEmotes() async throws -> [TwitchEmote] {
        let response: HelixResponse<TwitchEmote> = try await request(endpoint: "chat/emotes/global")
        return response.data
    }

    @available(*, deprecated, renamed: "fetchGlobalEmotes")
    public func getGlobalEmotes() async throws -> [TwitchEmote] {
        try await fetchGlobalEmotes()
    }

    /// Gets the broadcaster's custom emotes (subscriber, Bits tier, follower emotes).
    ///
    /// Channel emotes include `tier` (subscription tier), `emoteType` (subscriptions/bitstier/follower),
    /// and `emoteSetId`. Follower emotes can only be used in the channel's own chat.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: Array of channel-specific emotes. Empty if none exist.
    /// - SeeAlso: [Get Channel Emotes](https://dev.twitch.tv/docs/api/reference/#get-channel-emotes)
    public func fetchChannelEmotes(forBroadcasterID broadcasterId: String) async throws -> [TwitchEmote] {
        let response: HelixResponse<TwitchEmote> = try await request(
            endpoint: "chat/emotes",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data
    }

    @available(*, deprecated, renamed: "fetchChannelEmotes(forBroadcasterID:)")
    public func getChannelEmotes(broadcasterId: String) async throws -> [TwitchEmote] {
        try await fetchChannelEmotes(forBroadcasterID: broadcasterId)
    }

    // MARK: - Badges

    /// Gets Twitch's global chat badges (e.g., staff, turbo, premium).
    ///
    /// Each badge set contains multiple versions with images at 1x/2x/4x resolutions.
    /// To render a badge from a chat message, match `ChatBadge.setId` + `ChatBadge.id`
    /// against the badge sets and versions returned here.
    ///
    /// - Returns: Array of global badge sets with version images.
    /// - SeeAlso: [Get Global Chat Badges](https://dev.twitch.tv/docs/api/reference/#get-global-chat-badges)
    public func fetchGlobalBadges() async throws -> [TwitchBadgeSet] {
        let response: HelixResponse<TwitchBadgeSet> = try await request(endpoint: "chat/badges/global")
        return response.data
    }

    @available(*, deprecated, renamed: "fetchGlobalBadges")
    public func getGlobalBadges() async throws -> [TwitchBadgeSet] {
        try await fetchGlobalBadges()
    }

    /// Gets the broadcaster's custom chat badges (e.g., subscriber tenure badges).
    ///
    /// Channel badges override global badges with the same `setId`.
    /// When rendering, check channel badges first, fall back to global.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: Array of channel-specific badge sets.
    /// - SeeAlso: [Get Channel Chat Badges](https://dev.twitch.tv/docs/api/reference/#get-channel-chat-badges)
    public func fetchChannelBadges(forBroadcasterID broadcasterId: String) async throws -> [TwitchBadgeSet] {
        let response: HelixResponse<TwitchBadgeSet> = try await request(
            endpoint: "chat/badges",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return response.data
    }

    @available(*, deprecated, renamed: "fetchChannelBadges(forBroadcasterID:)")
    public func getChannelBadges(broadcasterId: String) async throws -> [TwitchBadgeSet] {
        try await fetchChannelBadges(forBroadcasterID: broadcasterId)
    }

    // MARK: - Chat Messages

    /// Sends a chat message to a channel.
    ///
    /// The `senderId` must match the authenticated user's ID. Optionally reply
    /// to an existing message by providing `replyParentMessageId`.
    ///
    /// The response indicates whether the message was sent successfully.
    /// Messages can be dropped by AutoMod, slow mode, follower-only mode, etc.
    ///
    /// - Parameters:
    ///   - broadcasterId: The channel to send the message to.
    ///   - senderId: The authenticated user's ID (must match access token).
    ///   - message: The chat message text.
    ///   - replyParentMessageId: Optional message ID to reply to (creates a thread).
    /// - Returns: The result including `messageId`, `isSent`, and optional `dropReason`.
    /// - Throws: `HelixError.forbidden` if the user is banned or lacks permissions.
    /// - SeeAlso: [Send Chat Message](https://dev.twitch.tv/docs/api/reference/#send-chat-message)
    public func sendChatMessage(
        broadcasterId: String,
        senderId: String,
        message: String,
        replyParentMessageId: String? = nil
    ) async throws -> SendChatMessageResponse {
        var body: [String: String] = [
            "broadcaster_id": broadcasterId,
            "sender_id": senderId,
            "message": message,
        ]
        if let replyId = replyParentMessageId {
            body["reply_parent_message_id"] = replyId
        }

        let bodyData = try JSONEncoder.twitch().encode(body)
        let response: HelixResponse<SendChatMessageResponse> = try await request(
            endpoint: "chat/messages",
            method: "POST",
            body: bodyData
        )
        guard let result = response.data.first else { throw HelixError.notFound }
        return result
    }

    // MARK: - EventSub

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
    /// - Throws: `HelixError.badRequest` if the subscription fails (wrong conditions, duplicate, etc.).
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

        // Custom URLRequest — EventSub response shape differs from standard Helix
        let components = URLComponents(string: Self.baseURL + "eventsub/subscriptions")!
        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = bodyData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await auth.accessToken()
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(clientId, forHTTPHeaderField: "Client-Id")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let http = response as! HTTPURLResponse

        guard http.statusCode == 202 else {
            if let errorResponse = try? JSONDecoder.twitch().decode(TwitchErrorResponse.self, from: data) {
                logger.error("EventSub subscribe failed for \(type): \(errorResponse.message)")
                throw HelixError.badRequest(errorResponse.message)
            }
            logger.error("EventSub subscribe failed for \(type): HTTP \(http.statusCode)")
            throw HelixError.serverError(status: http.statusCode)
        }
    }
}

// MARK: - Internal Types

// MARK: - Internal Response Types

private struct StreamKeyResponse: Decodable, Sendable {
    let streamKey: String
}

private struct EmptyResponse: Decodable, Sendable {}

/// Response from the Send Chat Message endpoint.
///
/// Indicates whether the message was successfully sent or dropped (e.g., by AutoMod).
///
/// - SeeAlso: [Send Chat Message](https://dev.twitch.tv/docs/api/reference/#send-chat-message)
public struct SendChatMessageResponse: Decodable, Sendable {
    /// The ID of the sent message (empty string if not sent).
    public let messageId: String

    /// Whether the message was successfully sent to chat.
    public let isSent: Bool

    /// Reason the message was dropped, if `isSent` is `false`.
    /// Contains a `code` (e.g., `"automod_held"`) and human-readable `message`.
    public let dropReason: DropReason?

    /// Details about why a chat message was not sent.
    public struct DropReason: Decodable, Sendable {
        /// Machine-readable error code (e.g., `"automod_held"`, `"msg_banned"`, `"msg_ratelimit"`).
        public let code: String

        /// Human-readable explanation (e.g., `"Your message has been held for review by Automod."`).
        public let message: String
    }
}

// MARK: - Public Request Types

/// A content classification label to enable or disable on a channel.
///
/// Used with `updateChannelInfo(contentClassificationLabels:)`.
///
/// Possible label IDs:
/// - `DebatedSocialIssuesAndPolitics`
/// - `DrugsIntoxication`
/// - `SexualThemes`
/// - `ViolentGraphic`
/// - `Gambling`
/// - `ProfanityVulgarity`
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

private struct UpdateChannelInfoRequest: Encodable {
    let title: String?
    let gameId: String?
    let broadcasterLanguage: String?
    let delay: Int?
    let tags: [String]?
    let contentClassificationLabels: [ContentClassificationLabel]?
    let isBrandedContent: Bool?
}

extension ContentClassificationLabel: Encodable {}

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
