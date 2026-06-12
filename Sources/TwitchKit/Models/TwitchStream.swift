import Foundation

/// A live Twitch stream returned by Helix.
///
/// - SeeAlso: [Get Streams](https://dev.twitch.tv/docs/api/reference/#get-streams)
public struct TwitchStream: Decodable, Sendable, Equatable {
    /// The stream ID.
    public let id: String

    /// The ID of the broadcaster.
    public let userId: String

    /// The broadcaster's login name.
    public let userLogin: String

    /// The broadcaster's display name.
    public let userName: String

    /// The ID of the game/category being streamed.
    public let gameId: String

    /// The name of the game/category being streamed.
    public let gameName: String

    /// The stream type. Typically `.live` for active streams.
    public let type: TwitchStreamType

    /// The stream title.
    public let title: String

    /// Tags applied to the stream.
    public let tags: [String]

    /// Current viewer count.
    public let viewerCount: Int

    /// When the stream started.
    public let startedAt: Date

    /// The stream language.
    public let language: String

    /// Template URL for the stream thumbnail.
    public let thumbnailUrl: String

    /// Whether the stream is marked mature.
    public let isMature: Bool

    private enum CodingKeys: String, CodingKey {
        case id, userId, userLogin, userName, gameId, gameName, type, title
        case tags, viewerCount, startedAt, language, thumbnailUrl, isMature
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        userLogin = try container.decode(String.self, forKey: .userLogin)
        userName = try container.decode(String.self, forKey: .userName)
        gameId = try container.decode(String.self, forKey: .gameId)
        gameName = try container.decode(String.self, forKey: .gameName)
        type = try container.decode(TwitchStreamType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        // Twitch sends `"tags": null` for streams with no tags set — tolerate
        // both null and an absent key, defaulting to an empty array.
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        viewerCount = try container.decode(Int.self, forKey: .viewerCount)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        language = try container.decode(String.self, forKey: .language)
        thumbnailUrl = try container.decode(String.self, forKey: .thumbnailUrl)
        isMature = try container.decode(Bool.self, forKey: .isMature)
    }
}
