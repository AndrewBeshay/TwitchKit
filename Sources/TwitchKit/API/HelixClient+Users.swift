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

    /// Gets users by Twitch user IDs and/or login names.
    ///
    /// Twitch supports up to 100 combined `id` and `login` query parameters.
    ///
    /// - Parameters:
    ///   - ids: User IDs to fetch.
    ///   - logins: User login names to fetch.
    /// - Returns: Matching users. Twitch omits users that do not exist.
    /// - SeeAlso: [Get Users](https://dev.twitch.tv/docs/api/reference/#get-users)
    public func fetchUsers(ids: [String] = [], logins: [String] = []) async throws -> [TwitchUser] {
        let requestedCount = ids.count + logins.count
        guard requestedCount > 0 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "At least one user ID or login is required")
            )
        }
        guard requestedCount <= 100 else {
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "A maximum of 100 user IDs and logins may be requested")
            )
        }

        let queryItems = HelixQuery.items("id", values: ids) + HelixQuery.items("login", values: logins)
        let response: HelixResponse<TwitchUser> = try await request(endpoint: "users", queryItems: queryItems)
        return response.data
    }

    /// Gets one user by Twitch user ID.
    ///
    /// - Parameter id: The user ID to fetch.
    /// - Returns: The matching user.
    /// - Throws: `HelixError.notFound` if Twitch returns no matching user.
    /// - SeeAlso: [Get Users](https://dev.twitch.tv/docs/api/reference/#get-users)
    public func fetchUser(id: String) async throws -> TwitchUser {
        let users = try await fetchUsers(ids: [id])
        guard let user = users.first else { throw HelixError.notFound }
        return user
    }

    /// Gets one user by Twitch login name.
    ///
    /// - Parameter login: The user login to fetch.
    /// - Returns: The matching user.
    /// - Throws: `HelixError.notFound` if Twitch returns no matching user.
    /// - SeeAlso: [Get Users](https://dev.twitch.tv/docs/api/reference/#get-users)
    public func fetchUser(login: String) async throws -> TwitchUser {
        let users = try await fetchUsers(logins: [login])
        guard let user = users.first else { throw HelixError.notFound }
        return user
    }
}
