import Foundation

extension HelixClient {
    /// Gets one page of Drops entitlements for an organization/game/user filter.
    public func fetchDropsEntitlementsPage(
        ids: [String] = [],
        userID: String? = nil,
        gameID: String? = nil,
        fulfillmentStatus: DropsEntitlementFulfillmentStatus? = nil,
        first: Int? = nil,
        after cursor: String? = nil
    ) async throws -> HelixPage<DropsEntitlement> {
        var queryItems = HelixQuery.items("id", values: ids)
        HelixQuery.append(HelixQuery.item("user_id", userID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("game_id", gameID), to: &queryItems)
        HelixQuery.append(HelixQuery.item("fulfillment_status", fulfillmentStatus?.rawValue), to: &queryItems)
        try HelixQuery.appendPagination(to: &queryItems, first: first, after: cursor)

        let response: HelixResponse<DropsEntitlement> = try await request(
            endpoint: "entitlements/drops",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
        return response.page
    }

    /// Updates Drops entitlement fulfillment status.
    public func updateDropsEntitlements(
        entitlementIDs: [String],
        fulfillmentStatus: DropsEntitlementFulfillmentStatus
    ) async throws -> [DropsEntitlementUpdateResult] {
        let response: HelixResponse<DropsEntitlementUpdateResult> = try await request(
            endpoint: "entitlements/drops",
            method: "PATCH",
            body: try JSONEncoder.twitch().encode(DropsEntitlementUpdateRequest(
                entitlementIds: entitlementIDs,
                fulfillmentStatus: fulfillmentStatus.rawValue
            ))
        )
        return response.data
    }
}

private struct DropsEntitlementUpdateRequest: Encodable {
    let entitlementIds: [String]
    let fulfillmentStatus: String
}

public enum DropsEntitlementFulfillmentStatus: String, Sendable, Equatable {
    case claimed = "CLAIMED"
    case fulfilled = "FULFILLED"
}

public struct DropsEntitlement: Decodable, Sendable, Equatable {
    public let id: String
    public let benefitId: String
    public let timestamp: Date
    public let userId: String
    public let gameId: String
    public let fulfillmentStatus: String
    public let lastUpdated: Date
}

public struct DropsEntitlementUpdateResult: Decodable, Sendable, Equatable {
    public let status: String
    public let ids: [String]
}
