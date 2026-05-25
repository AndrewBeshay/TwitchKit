import Foundation

extension HelixClient {
    public func fetchBroadcasterSubscriptionsPage(
        broadcasterID: String,
        userIDs: [String] = [],
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<TwitchSubscription> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<TwitchSubscription> = try await request(
            endpoint: "subscriptions",
            queryItems: queryItems
        )
        return response.page
    }

    public func broadcasterSubscriptions(
        broadcasterID: String,
        userIDs: [String] = [],
        pageSize: Int? = nil
    ) -> HelixPagedSequence<TwitchSubscription> {
        var queryItems = [URLQueryItem(name: "broadcaster_id", value: broadcasterID)]
        queryItems += HelixQuery.items("user_id", values: userIDs)
        return pagedRequest(endpoint: "subscriptions", queryItems: queryItems, pageSize: pageSize)
    }

    public func checkUserSubscription(broadcasterID: String, userID: String) async throws -> TwitchSubscription {
        let response: HelixResponse<TwitchSubscription> = try await request(
            endpoint: "subscriptions/user",
            queryItems: [
                URLQueryItem(name: "broadcaster_id", value: broadcasterID),
                URLQueryItem(name: "user_id", value: userID)
            ]
        )
        guard let subscription = response.data.first else { throw HelixError.notFound }
        return subscription
    }
}
