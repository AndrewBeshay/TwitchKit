import Foundation

extension HelixClient {
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
}
