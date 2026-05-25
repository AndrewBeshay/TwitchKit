import Foundation

extension HelixClient {
    public func createClip(broadcasterID: String, hasDelay: Bool? = nil) async throws -> ClipCreate {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        HelixQuery.append(hasDelay.map { URLQueryItem(name: "has_delay", value: String($0)) }, to: &queryItems)

        let response: HelixResponse<ClipCreate> = try await request(
            endpoint: "clips",
            method: "POST",
            queryItems: queryItems
        )
        guard let clip = response.data.first else { throw HelixError.notFound }
        return clip
    }

    public func createClipFromVOD(
        broadcasterID: String,
        editorID: String,
        vodID: String,
        vodOffset: Int,
        title: String,
        duration: Double? = nil
    ) async throws -> ClipCreate {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "editor_id", value: editorID),
            URLQueryItem(name: "vod_id", value: vodID),
            URLQueryItem(name: "vod_offset", value: String(vodOffset)),
            URLQueryItem(name: "title", value: title)
        ]
        HelixQuery.append(duration.map { URLQueryItem(name: "duration", value: String($0)) }, to: &queryItems)

        let response: HelixResponse<ClipCreate> = try await request(
            endpoint: "videos/clips",
            method: "POST",
            queryItems: queryItems
        )
        guard let clip = response.data.first else { throw HelixError.notFound }
        return clip
    }

    public func fetchClipsPage(
        broadcasterID: String? = nil,
        gameID: String? = nil,
        ids: [String] = [],
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        first: Int? = nil,
        after cursor: String? = nil,
        before previousCursor: String? = nil
    ) async throws -> HelixPage<TwitchClip> {
        var queryItems: [URLQueryItem] = []
        HelixQuery.append(HelixQuery.item("broadcaster_id", broadcasterID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("game_id", gameID), to: &queryItems)
        queryItems += HelixQuery.items("id", values: ids)
        HelixQuery.append(startedAt.map { URLQueryItem(name: "started_at", value: Self.mediaISO8601String(from: $0)) }, to: &queryItems)
        HelixQuery.append(endedAt.map { URLQueryItem(name: "ended_at", value: Self.mediaISO8601String(from: $0)) }, to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor, before: previousCursor)

        let response: HelixResponse<TwitchClip> = try await request(endpoint: "clips", queryItems: queryItems)
        return response.page
    }

    public func fetchClipDownloads(broadcasterID: String, editorID: String, clipIDs: [String]) async throws -> [ClipDownload] {
        var queryItems = [
            URLQueryItem(name: "broadcaster_id", value: broadcasterID),
            URLQueryItem(name: "editor_id", value: editorID)
        ]
        queryItems += HelixQuery.items("clip_id", values: clipIDs)

        let response: HelixResponse<ClipDownload> = try await request(
            endpoint: "clips/downloads",
            queryItems: queryItems
        )
        return response.data
    }

    public func fetchVideosPage(
        ids: [String] = [],
        userID: String? = nil,
        gameID: String? = nil,
        language: String? = nil,
        period: String? = nil,
        sort: String? = nil,
        type: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil,
        before previousCursor: String? = nil
    ) async throws -> HelixPage<TwitchVideo> {
        var queryItems = HelixQuery.items("id", values: ids)
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("game_id", gameID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("language", language), to: &queryItems)
        HelixQuery.append(HelixQuery.item("period", period), to: &queryItems)
        HelixQuery.append(HelixQuery.item("sort", sort), to: &queryItems)
        HelixQuery.append(HelixQuery.item("type", type), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor, before: previousCursor)

        let response: HelixResponse<TwitchVideo> = try await request(endpoint: "videos", queryItems: queryItems)
        return response.page
    }

    public func deleteVideos(ids: [String]) async throws -> [String] {
        let response: HelixResponse<DeletedVideo> = try await request(
            endpoint: "videos",
            method: "DELETE",
            queryItems: HelixQuery.items("id", values: ids)
        )
        return response.data.map(\.id)
    }

    private static func mediaISO8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

public struct ClipCreate: Decodable, Sendable, Equatable {
    public let id: String
    public let editUrl: String
}

public struct TwitchClip: Decodable, Sendable, Equatable {
    public let id: String
    public let url: String
    public let embedUrl: String
    public let broadcasterId: String
    public let broadcasterName: String
    public let creatorId: String
    public let creatorName: String
    public let videoId: String
    public let gameId: String
    public let language: String
    public let title: String
    public let viewCount: Int
    public let createdAt: Date
    public let thumbnailUrl: String
    public let duration: Double
    public let vodOffset: Int?
    public let isFeatured: Bool?
}

public struct ClipDownload: Decodable, Sendable, Equatable {
    public let clipId: String
    public let landscapeDownloadUrl: String?
    public let portraitDownloadUrl: String?
}

public struct TwitchVideo: Decodable, Sendable, Equatable {
    public let id: String
    public let streamId: String?
    public let userId: String
    public let userLogin: String
    public let userName: String
    public let title: String
    public let description: String
    public let createdAt: Date
    public let publishedAt: Date
    public let url: String
    public let thumbnailUrl: String
    public let viewable: String
    public let viewCount: Int
    public let language: String
    public let type: String
    public let duration: String
    public let mutedSegments: [MutedVideoSegment]?
}

public struct MutedVideoSegment: Decodable, Sendable, Equatable {
    public let duration: Int
    public let offset: Int
}

private struct DeletedVideo: Decodable, Sendable {
    let id: String
}
