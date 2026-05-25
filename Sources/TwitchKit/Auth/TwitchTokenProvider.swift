import Foundation
import os

private let tokenProviderLogger = Logger(subsystem: "com.twitchkit", category: "token-provider")

/// Provides access tokens for authenticated Twitch API requests.
public protocol TwitchAccessTokenProvider: Sendable {
    /// Returns a usable access token or throws if no token is available.
    func accessToken() async throws -> String

    /// Refreshes the current token when a refresh token is available.
    func refreshIfNeeded() async throws
}

/// Loads, stores, validates, and refreshes OAuth tokens.
public actor TwitchTokenProvider: TwitchAccessTokenProvider {
    private let oauthClient: TwitchOAuthClient
    private let tokenStore: any TwitchTokenStore

    private var cachedToken: OAuthToken?
    private var hasLoadedStoredToken = false

    public init(oauthClient: TwitchOAuthClient, tokenStore: any TwitchTokenStore) {
        self.oauthClient = oauthClient
        self.tokenStore = tokenStore
    }

    /// Returns whether a token is available locally.
    public func isAuthenticated() async -> Bool {
        (try? await currentToken()) != nil
    }

    /// Returns the current token, loading it from storage if necessary.
    public func token() async throws -> OAuthToken {
        guard let token = try await currentToken() else {
            throw HelixError.notAuthenticated
        }
        return token
    }

    public func accessToken() async throws -> String {
        try await token().accessToken
    }

    /// Stores an externally obtained token.
    public func setToken(_ token: OAuthToken) async throws {
        cachedToken = token
        hasLoadedStoredToken = true
        try await tokenStore.saveToken(token)
    }

    public func refreshIfNeeded() async throws {
        let token = try await token()
        guard let refreshToken = token.refreshToken else {
            tokenProviderLogger.warning("Token refresh requested but no refresh token is available")
            throw HelixError.unauthorized
        }

        do {
            let refreshedToken = try await oauthClient.refreshAccessToken(refreshToken: refreshToken)
            try await setToken(refreshedToken)
            tokenProviderLogger.info("Token refresh succeeded")
        } catch {
            try await logout()
            throw error
        }
    }

    /// Validates the current token and refreshes it if Twitch reports it as invalid.
    public func validateToken() async throws {
        guard let token = try await currentToken() else {
            tokenProviderLogger.info("No token to validate")
            return
        }

        let isValid = try await oauthClient.validateAccessToken(token.accessToken)
        if !isValid {
            tokenProviderLogger.warning("Token validation failed; attempting refresh")
            try await refreshIfNeeded()
        }
    }

    /// Deletes the current token from memory and storage.
    public func logout() async throws {
        cachedToken = nil
        hasLoadedStoredToken = true
        try await tokenStore.deleteToken()
    }

    private func currentToken() async throws -> OAuthToken? {
        if let cachedToken {
            return cachedToken
        }

        guard !hasLoadedStoredToken else {
            return nil
        }

        let storedToken = try await tokenStore.loadToken()
        cachedToken = storedToken
        hasLoadedStoredToken = true
        return storedToken
    }
}
