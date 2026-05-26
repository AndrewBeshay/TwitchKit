import Foundation

extension HelixClient {
    /// Starts a commercial on the specified channel.
    public func startCommercial(broadcasterID: String, length: Int) async throws -> CommercialStart {
        let response: HelixResponse<CommercialStart> = try await request(
            endpoint: "channels/commercial",
            method: "POST",
            body: try JSONEncoder.twitch().encode(StartCommercialRequest(
                broadcasterId: broadcasterID,
                length: length
            ))
        )
        guard let commercial = response.data.first else { throw HelixError.notFound }
        return commercial
    }

    /// Gets ad schedule information for a broadcaster.
    public func fetchAdSchedule(broadcasterID: String) async throws -> AdSchedule {
        let response: HelixResponse<AdSchedule> = try await request(
            endpoint: "channels/ads",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        guard let schedule = response.data.first else { throw HelixError.notFound }
        return schedule
    }

    /// Snoozes the broadcaster's next scheduled ad.
    public func snoozeNextAd(broadcasterID: String) async throws -> AdSnooze {
        let response: HelixResponse<AdSnooze> = try await request(
            endpoint: "channels/ads/schedule/snooze",
            method: "POST",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        )
        guard let snooze = response.data.first else { throw HelixError.notFound }
        return snooze
    }
}

private struct StartCommercialRequest: Encodable {
    let broadcasterId: String
    let length: Int
}

public struct CommercialStart: Decodable, Sendable, Equatable {
    public let length: Int
    public let message: String
    public let retryAfter: Int
}

public struct AdSchedule: Decodable, Sendable, Equatable {
    public let snoozeCount: Int?
    public let snoozeRefreshAt: Date?
    public let nextAdAt: Date?
    public let duration: Int?
    public let lastAdAt: Date?
    public let prerollFreeTime: Int?
}

public struct AdSnooze: Decodable, Sendable, Equatable {
    public let snoozeCount: Int
    public let snoozeRefreshAt: Date
    public let nextAdAt: Date
}
