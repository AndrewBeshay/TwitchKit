import Foundation

/// Filter values accepted by the Get Streams endpoint.
public enum TwitchStreamQueryType: String, Sendable, Equatable {
    /// Return all streams.
    case all

    /// Return live streams.
    case live
}

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

    /// The stream type. Typically `"live"` for active streams.
    public let type: String

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
}
