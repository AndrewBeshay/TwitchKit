import Foundation

extension HelixClient {
    /// Gets one page of users connected to a broadcaster's chat.
    public func fetchChattersPage(
        broadcasterID: String,
        moderatorID: String,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchChatter> {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "moderator_id", value: moderatorID),
        ]
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchChatter> = try await request(
            endpoint: "chat/chatters",
            queryItems: queryItems
        )
        return response.page
    }

    /// Returns an async sequence of users connected to a broadcaster's chat.
    public func chatters(
        broadcasterID: String,
        moderatorID: String,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchChatter> {
        pagedRequest(
            endpoint: "chat/chatters",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            pageSize: pageSize
        )
    }

    /// Gets emotes for one or more emote set IDs.
    public func fetchEmoteSets(ids: [String]) async throws -> [TwitchEmote] {
        guard !ids.isEmpty else {
            throw HelixError.badRequest(TwitchAPIError.fallback(status: 400, message: "At least one emote set ID is required"))
        }

        let response: HelixResponse<TwitchEmote> = try await request(
            endpoint: "chat/emotes/set",
            queryItems: HelixQuery.items("emote_set_id", values: ids)
        )
        return response.data
    }

    /// Gets one page of emotes available to a user.
    public func fetchUserEmotesPage(
        userID: String,
        broadcasterID: String? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchEmote> {
        var queryItems = [URLQueryItem(name: "user_id", value: userID)]
        HelixQuery.append(HelixQuery.item("broadcaster_id", broadcasterID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("after", cursor), to: &queryItems)

        let response: HelixResponse<TwitchEmote> = try await request(endpoint: "chat/emotes/user", queryItems: queryItems)
        return response.page
    }

    /// Gets a broadcaster's chat settings.
    public func fetchChatSettings(
        broadcasterID: String,
        moderatorID: String? = nil
    ) async throws -> ChatSettings {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        HelixQuery.append(HelixQuery.item("moderator_id", moderatorID), to: &queryItems)

        let response: HelixResponse<ChatSettings> = try await request(endpoint: "chat/settings", queryItems: queryItems)
        guard let settings = response.data.first else { throw HelixError.notFound }
        return settings
    }

    /// Updates a broadcaster's chat settings.
    public func updateChatSettings(
        broadcasterID: String,
        moderatorID: String,
        with update: ChatSettingsUpdate
    ) async throws -> ChatSettings {
        let response: HelixResponse<ChatSettings> = try await request(
            endpoint: "chat/settings",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            body: try JSONEncoder.twitch().encode(update)
        )
        guard let settings = response.data.first else { throw HelixError.notFound }
        return settings
    }

    /// Gets the active shared chat session for a channel.
    public func fetchSharedChatSession(broadcasterID: String) async throws -> SharedChatSession? {
        let response: HelixResponse<SharedChatSession> = try await request(
            endpoint: "shared_chat/session",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        return response.data.first
    }

    /// Sends a chat announcement.
    public func sendChatAnnouncement(
        broadcasterID: String,
        moderatorID: String,
        message: String,
        color: ChatAnnouncementColor? = nil
    ) async throws {
        try await requestNoContent(
            endpoint: "chat/announcements",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ],
            body: try JSONEncoder.twitch().encode(ChatAnnouncementRequest(message: message, color: color?.rawValue))
        )
    }

    /// Sends a shoutout from one broadcaster to another.
    public func sendShoutout(
        fromBroadcasterID broadcasterID: String,
        toBroadcasterID targetBroadcasterID: String,
        moderatorID: String
    ) async throws {
        try await requestNoContent(
            endpoint: "chat/shoutouts",
            method: "POST",
            queryItems: [
                URLQueryItem(name: "from_broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "to_broadcaster_id", value: targetBroadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ]
        )
    }

    /// Gets the currently pinned chat message for a broadcaster.
    public func fetchPinnedChatMessage(broadcasterID: String, moderatorID: String) async throws -> PinnedChatMessage? {
        let response: HelixResponse<PinnedChatMessage> = try await request(
            endpoint: "chat/pins",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
            ]
        )
        return response.data.first
    }

    /// Pins a chat message.
    public func pinChatMessage(
        broadcasterID: String,
        moderatorID: String,
        messageID: String,
        durationSeconds: Int? = nil
    ) async throws {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "moderator_id", value: moderatorID),
            URLQueryItem(name: "message_id", value: messageID),
        ]
        HelixQuery.append(HelixQuery.item("duration_seconds", durationSeconds.map(String.init)), to: &queryItems)
        try await requestNoContent(endpoint: "chat/pins", method: "PUT", queryItems: queryItems)
    }

    /// Updates the duration of a pinned chat message.
    public func updatePinnedChatMessage(
        broadcasterID: String,
        moderatorID: String,
        messageID: String,
        durationSeconds: Int? = nil
    ) async throws {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "moderator_id", value: moderatorID),
            URLQueryItem(name: "message_id", value: messageID),
        ]
        HelixQuery.append(HelixQuery.item("duration_seconds", durationSeconds.map(String.init)), to: &queryItems)
        try await requestNoContent(endpoint: "chat/pins", method: "PATCH", queryItems: queryItems)
    }

    /// Unpins a chat message.
    public func unpinChatMessage(broadcasterID: String, moderatorID: String, messageID: String) async throws {
        try await requestNoContent(
            endpoint: "chat/pins",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "moderator_id", value: moderatorID),
                URLQueryItem(name: "message_id", value: messageID),
            ]
        )
    }

    /// Gets chat colors for one or more users.
    public func fetchUserChatColors(userIDs: [String]) async throws -> [UserChatColor] {
        guard !userIDs.isEmpty else {
            throw HelixError.badRequest(TwitchAPIError.fallback(status: 400, message: "At least one user ID is required"))
        }
        let response: HelixResponse<UserChatColor> = try await request(
            endpoint: "chat/color",
            queryItems: HelixQuery.items("user_id", values: userIDs)
        )
        return response.data
    }

    /// Updates the chat color for a user.
    public func updateUserChatColor(userID: String, color: String) async throws {
        try await requestNoContent(
            endpoint: "chat/color",
            method: "PUT",
            queryItems: [
                URLQueryItem(name: "user_id", value: userID),
                URLQueryItem(name: "color", value: color),
            ]
        )
    }
}

private struct ChatAnnouncementRequest: Encodable {
    let message: String
    let color: String?
}

/// A user connected to a broadcaster's chat session.
public struct TwitchChatter: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
}

/// Chat settings for a broadcaster.
public struct ChatSettings: Decodable, Sendable, Equatable {
    public let broadcasterId: String
    public let emoteMode: Bool
    public let followerMode: Bool
    public let followerModeDuration: Int?
    public let nonModeratorChatDelay: Bool?
    public let nonModeratorChatDelayDuration: Int?
    public let slowMode: Bool
    public let slowModeWaitTime: Int?
    public let subscriberMode: Bool
    public let uniqueChatMode: Bool
}

/// Request body for updating chat settings.
public struct ChatSettingsUpdate: Encodable, Sendable, Equatable {
    public let emoteMode: Bool?
    public let followerMode: Bool?
    public let followerModeDuration: Int?
    public let nonModeratorChatDelay: Bool?
    public let nonModeratorChatDelayDuration: Int?
    public let slowMode: Bool?
    public let slowModeWaitTime: Int?
    public let subscriberMode: Bool?
    public let uniqueChatMode: Bool?

    public init(
        emoteMode: Bool? = nil,
        followerMode: Bool? = nil,
        followerModeDuration: Int? = nil,
        nonModeratorChatDelay: Bool? = nil,
        nonModeratorChatDelayDuration: Int? = nil,
        slowMode: Bool? = nil,
        slowModeWaitTime: Int? = nil,
        subscriberMode: Bool? = nil,
        uniqueChatMode: Bool? = nil
    ) {
        self.emoteMode = emoteMode
        self.followerMode = followerMode
        self.followerModeDuration = followerModeDuration
        self.nonModeratorChatDelay = nonModeratorChatDelay
        self.nonModeratorChatDelayDuration = nonModeratorChatDelayDuration
        self.slowMode = slowMode
        self.slowModeWaitTime = slowModeWaitTime
        self.subscriberMode = subscriberMode
        self.uniqueChatMode = uniqueChatMode
    }
}

/// A chat announcement color.
public enum ChatAnnouncementColor: String, Sendable, Equatable {
    case blue
    case green
    case orange
    case purple
    case primary
}

/// A shared chat session.
public struct SharedChatSession: Decodable, Sendable, Equatable {
    public let sessionId: String
    public let hostBroadcasterId: String
    public let participants: [Participant]
    public let createdAt: Date
    public let updatedAt: Date

    public struct Participant: Decodable, Sendable, Equatable {
        public let broadcasterId: String
    }
}

/// A pinned chat message.
public struct PinnedChatMessage: Decodable, Sendable, Equatable {
    public let messageId: String
    public let broadcasterId: String
    public let senderUserId: String
    public let senderUserLogin: String
    public let senderUserName: String
    public let pinnedByUserId: String
    public let pinnedByUserLogin: String
    public let pinnedByUserName: String
    public let message: ChatMessage.ChatMessageBody
    public let startsAt: Date
    public let endsAt: Date?
    public let updatedAt: Date
}

/// The chat color for a user.
public struct UserChatColor: Decodable, Sendable, Equatable {
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let color: String
}
