import Foundation

extension HelixClient {
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
}

private struct StreamKeyResponse: Decodable, Sendable {
    let streamKey: String
}
