import Foundation

extension HelixClient {
    /// Gets one page of a broadcaster's stream schedule.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - segmentIDs: Optional schedule segment IDs.
    ///   - startTime: Optional lower bound for returned segments.
    ///   - utcOffset: Optional offset such as `"-05:00"`.
    ///   - first: Optional page size. Twitch currently allows up to 25 for schedules.
    ///   - cursor: Optional cursor returned by a previous page.
    /// - Returns: A schedule page.
    /// - SeeAlso: [Get Channel Stream Schedule](https://dev.twitch.tv/docs/api/reference/#get-channel-stream-schedule)
    public func fetchChannelStreamSchedulePage(
        forBroadcasterID broadcasterId: String,
        segmentIDs: [String] = [],
        startTime: Date? = nil,
        utcOffset: String? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> ChannelStreamSchedulePage {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        queryItems += HelixQuery.items("id", values: segmentIDs)
        HelixQuery.append(startTime.map { URLQueryItem(name: "start_time", value: TwitchDateParser.string(from: $0)) }, to: &queryItems)
        HelixQuery.append(HelixQuery.item("utc_offset", utcOffset), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<ChannelStreamSchedule> = try await request(
            endpoint: "schedule",
            queryItems: queryItems
        )
        guard let schedule = response.data.first else { throw HelixError.notFound }
        return ChannelStreamSchedulePage(
            schedule: schedule,
            pagination: response.pagination,
            metadata: response.metadata
        )
    }

    /// Gets a broadcaster's schedule as an iCalendar string.
    ///
    /// - Parameter broadcasterId: The broadcaster's user ID.
    /// - Returns: Raw iCalendar text.
    /// - SeeAlso: [Get Channel iCalendar](https://dev.twitch.tv/docs/api/reference/#get-channel-icalendar)
    public func fetchChannelICalendar(forBroadcasterID broadcasterId: String) async throws -> String {
        let data = try await requestRawData(
            endpoint: "schedule/icalendar",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)]
        )
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Updates a broadcaster's stream schedule settings.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - settings: Schedule settings to update.
    /// - SeeAlso: [Update Channel Stream Schedule](https://dev.twitch.tv/docs/api/reference/#update-channel-stream-schedule)
    public func updateChannelStreamSchedule(
        forBroadcasterID broadcasterId: String,
        with settings: ChannelStreamScheduleSettingsUpdate
    ) async throws {
        try await requestNoContent(
            endpoint: "schedule/settings",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)],
            body: try JSONEncoder.twitch().encode(settings)
        )
    }

    /// Creates a stream schedule segment.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - segment: The segment to create.
    /// - Returns: The created schedule.
    /// - SeeAlso: [Create Channel Stream Schedule Segment](https://dev.twitch.tv/docs/api/reference/#create-channel-stream-schedule-segment)
    public func createChannelStreamScheduleSegment(
        forBroadcasterID broadcasterId: String,
        segment: ChannelStreamScheduleSegmentCreate
    ) async throws -> ChannelStreamSchedule {
        let response: HelixResponse<ChannelStreamSchedule> = try await request(
            endpoint: "schedule/segment",
            method: "POST",
            queryItems: [URLQueryItem(name: "broadcaster_id", value: broadcasterId)],
            body: try JSONEncoder.twitch().encode(segment)
        )
        guard let schedule = response.data.first else { throw HelixError.notFound }
        return schedule
    }

    /// Updates a stream schedule segment.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - segmentId: The schedule segment ID.
    ///   - update: Segment fields to update.
    /// - Returns: The updated schedule.
    /// - SeeAlso: [Update Channel Stream Schedule Segment](https://dev.twitch.tv/docs/api/reference/#update-channel-stream-schedule-segment)
    public func updateChannelStreamScheduleSegment(
        forBroadcasterID broadcasterId: String,
        segmentID segmentId: String,
        with update: ChannelStreamScheduleSegmentUpdate
    ) async throws -> ChannelStreamSchedule {
        let response: HelixResponse<ChannelStreamSchedule> = try await request(
            endpoint: "schedule/segment",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "id", value: segmentId)
            ],
            body: try JSONEncoder.twitch().encode(update)
        )
        guard let schedule = response.data.first else { throw HelixError.notFound }
        return schedule
    }

    /// Deletes a stream schedule segment.
    ///
    /// - Parameters:
    ///   - broadcasterId: The broadcaster's user ID.
    ///   - segmentId: The schedule segment ID.
    /// - SeeAlso: [Delete Channel Stream Schedule Segment](https://dev.twitch.tv/docs/api/reference/#delete-channel-stream-schedule-segment)
    public func deleteChannelStreamScheduleSegment(
        forBroadcasterID broadcasterId: String,
        segmentID segmentId: String
    ) async throws {
        try await requestNoContent(
            endpoint: "schedule/segment",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterId),
                URLQueryItem(name: "id", value: segmentId)
            ]
        )
    }

}

public struct ChannelStreamSchedulePage: Sendable, Equatable {
    public let schedule: ChannelStreamSchedule
    public let pagination: Pagination?
    public let metadata: HelixResponseMetadata?

    public var nextCursor: String? {
        pagination?.cursor
    }
}

public struct ChannelStreamSchedule: Decodable, Sendable, Equatable {
    public let segments: [ChannelStreamScheduleSegment]
    public let broadcasterId: String
    public let broadcasterName: String
    public let broadcasterLogin: String
    public let vacation: ChannelStreamScheduleVacation?
}

public struct ChannelStreamScheduleSegment: Decodable, Sendable, Equatable {
    public let id: String
    public let startTime: Date
    public let endTime: Date
    public let title: String
    public let canceledUntil: Date?
    public let category: Category?
    public let isRecurring: Bool

    public struct Category: Decodable, Sendable, Equatable {
        public let id: String
        public let name: String
    }
}

public struct ChannelStreamScheduleVacation: Codable, Sendable, Equatable {
    public let startTime: Date
    public let endTime: Date
}

public struct ChannelStreamScheduleSettingsUpdate: Encodable, Sendable, Equatable {
    public let isVacationEnabled: Bool?
    public let vacationStartTime: Date?
    public let vacationEndTime: Date?
    public let timezone: String?

    public init(
        isVacationEnabled: Bool? = nil,
        vacationStartTime: Date? = nil,
        vacationEndTime: Date? = nil,
        timezone: String? = nil
    ) {
        self.isVacationEnabled = isVacationEnabled
        self.vacationStartTime = vacationStartTime
        self.vacationEndTime = vacationEndTime
        self.timezone = timezone
    }
}

public struct ChannelStreamScheduleSegmentCreate: Encodable, Sendable, Equatable {
    public let startTime: Date
    public let timezone: String
    public let isRecurring: Bool
    public let duration: String?
    public let categoryId: String?
    public let title: String?

    public init(
        startTime: Date,
        timezone: String,
        isRecurring: Bool,
        duration: String? = nil,
        categoryId: String? = nil,
        title: String? = nil
    ) {
        self.startTime = startTime
        self.timezone = timezone
        self.isRecurring = isRecurring
        self.duration = duration
        self.categoryId = categoryId
        self.title = title
    }
}

public struct ChannelStreamScheduleSegmentUpdate: Encodable, Sendable, Equatable {
    public let startTime: Date?
    public let duration: String?
    public let categoryId: String?
    public let title: String?
    public let isCanceled: Bool?
    public let timezone: String?

    public init(
        startTime: Date? = nil,
        duration: String? = nil,
        categoryId: String? = nil,
        title: String? = nil,
        isCanceled: Bool? = nil,
        timezone: String? = nil
    ) {
        self.startTime = startTime
        self.duration = duration
        self.categoryId = categoryId
        self.title = title
        self.isCanceled = isCanceled
        self.timezone = timezone
    }
}
