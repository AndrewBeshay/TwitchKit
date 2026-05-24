import Foundation
import os

private let logger = Logger(subsystem: "com.twitchkit", category: "auth")

/// A Twitch OAuth scope.
public enum TwitchScope: String, CaseIterable, Sendable {
    // MARK: Twitch API and EventSub

    case analyticsReadExtensions = "analytics:read:extensions"
    case analyticsReadGames = "analytics:read:games"
    case bitsRead = "bits:read"
    case channelBot = "channel:bot"
    case channelManageAds = "channel:manage:ads"
    case channelReadAds = "channel:read:ads"
    case channelManageBroadcast = "channel:manage:broadcast"
    case channelReadCharity = "channel:read:charity"
    case channelManageClips = "channel:manage:clips"
    case channelEditCommercial = "channel:edit:commercial"
    case channelReadEditors = "channel:read:editors"
    case channelManageExtensions = "channel:manage:extensions"
    case channelReadGoals = "channel:read:goals"
    case channelReadGuestStar = "channel:read:guest_star"
    case channelManageGuestStar = "channel:manage:guest_star"
    case channelReadHypeTrain = "channel:read:hype_train"
    case channelManageModerators = "channel:manage:moderators"
    case channelReadPolls = "channel:read:polls"
    case channelManagePolls = "channel:manage:polls"
    case channelReadPredictions = "channel:read:predictions"
    case channelManagePredictions = "channel:manage:predictions"
    case channelManageRaids = "channel:manage:raids"
    case channelReadRedemptions = "channel:read:redemptions"
    case channelManageRedemptions = "channel:manage:redemptions"
    case channelManageSchedule = "channel:manage:schedule"
    case channelReadStreamKey = "channel:read:stream_key"
    case channelReadSubscriptions = "channel:read:subscriptions"
    case channelManageVideos = "channel:manage:videos"
    case channelReadVips = "channel:read:vips"
    case channelManageVips = "channel:manage:vips"
    case channelModerate = "channel:moderate"
    case clipsEdit = "clips:edit"
    case editorManageClips = "editor:manage:clips"
    case moderationRead = "moderation:read"
    case moderatorManageAnnouncements = "moderator:manage:announcements"
    case moderatorManageAutomod = "moderator:manage:automod"
    case moderatorReadAutomodSettings = "moderator:read:automod_settings"
    case moderatorManageAutomodSettings = "moderator:manage:automod_settings"
    case moderatorReadBannedUsers = "moderator:read:banned_users"
    case moderatorManageBannedUsers = "moderator:manage:banned_users"
    case moderatorReadBlockedTerms = "moderator:read:blocked_terms"
    case moderatorManageBlockedTerms = "moderator:manage:blocked_terms"
    case moderatorReadChatMessages = "moderator:read:chat_messages"
    case moderatorManageChatMessages = "moderator:manage:chat_messages"
    case moderatorReadChatSettings = "moderator:read:chat_settings"
    case moderatorManageChatSettings = "moderator:manage:chat_settings"
    case moderatorReadChatters = "moderator:read:chatters"
    case moderatorReadFollowers = "moderator:read:followers"
    case moderatorReadGuestStar = "moderator:read:guest_star"
    case moderatorManageGuestStar = "moderator:manage:guest_star"
    case moderatorReadModerators = "moderator:read:moderators"
    case moderatorReadShieldMode = "moderator:read:shield_mode"
    case moderatorManageShieldMode = "moderator:manage:shield_mode"
    case moderatorReadShoutouts = "moderator:read:shoutouts"
    case moderatorManageShoutouts = "moderator:manage:shoutouts"
    case moderatorReadSuspiciousUsers = "moderator:read:suspicious_users"
    case moderatorManageSuspiciousUsers = "moderator:manage:suspicious_users"
    case moderatorReadUnbanRequests = "moderator:read:unban_requests"
    case moderatorManageUnbanRequests = "moderator:manage:unban_requests"
    case moderatorReadVips = "moderator:read:vips"
    case moderatorReadWarnings = "moderator:read:warnings"
    case moderatorManageWarnings = "moderator:manage:warnings"
    case userBot = "user:bot"
    case userEdit = "user:edit"
    case userEditBroadcast = "user:edit:broadcast"
    case userReadBlockedUsers = "user:read:blocked_users"
    case userManageBlockedUsers = "user:manage:blocked_users"
    case userReadBroadcast = "user:read:broadcast"
    case userReadChat = "user:read:chat"
    case userManageChatColor = "user:manage:chat_color"
    case userReadEmail = "user:read:email"
    case userReadEmotes = "user:read:emotes"
    case userReadFollows = "user:read:follows"
    case userReadModeratedChannels = "user:read:moderated_channels"
    case userReadSubscriptions = "user:read:subscriptions"
    case userReadWhispers = "user:read:whispers"
    case userManageWhispers = "user:manage:whispers"
    case userWriteChat = "user:write:chat"

    // MARK: IRC Chat

    case chatEdit = "chat:edit"
    case chatRead = "chat:read"

    // MARK: PubSub-specific Chat

    case whispersRead = "whispers:read"
}

/// A token response returned by Twitch OAuth endpoints.
public struct OAuthToken: Decodable, Sendable, Equatable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int?
    public let scope: [String]?
    public let tokenType: String?

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresIn: Int? = nil,
        scope: [String]? = nil,
        tokenType: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.scope = scope
        self.tokenType = tokenType
    }
}

/// The initial response for Twitch's OAuth device code flow.
public struct DeviceCodeAuthorization: Decodable, Sendable, Equatable {
    public let deviceCode: String
    public let expiresIn: Int
    public let interval: Int
    public let userCode: String
    public let verificationUri: String

    public var verificationURL: URL? {
        URL(string: verificationUri)
    }
}

public actor TwitchAuth {
    private let clientId: String
    private let clientSecret: String?
    private let redirectUri: String
    private let tokenKeyPrefix: String
    private let accessTokenKey: String
    private let refreshTokenKey: String

    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?

    /// Redirect URI — Twitch requires the value to match one of the redirect URLs registered for the app.
    public static let redirectUri = "https://localhost"

    /// Every scope known to this package.
    public static let allScopeCases = TwitchScope.allCases

    /// Every scope known to this package as raw Twitch scope strings.
    public static let allScopes = allScopeCases.map(\.rawValue)

    /// A small starter set used by TwitchKit's current convenience APIs.
    public static let defaultScopeCases: [TwitchScope] = [
        .userReadEmail,
        .userReadChat,
        .userWriteChat,
        .moderatorReadFollowers,
        .channelReadSubscriptions,
        .channelManageBroadcast,
        .channelReadStreamKey,
    ]

    /// A small starter set used by TwitchKit's current convenience APIs as raw Twitch scope strings.
    public static let defaultScopes = defaultScopeCases.map(\.rawValue)

    @available(*, deprecated, renamed: "allScopes")
    public static let scopes = allScopes

    public init(
        clientId: String,
        clientSecret: String? = nil,
        redirectUri: String = TwitchAuth.redirectUri,
        tokenNamespace: String? = nil
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.redirectUri = redirectUri
        self.tokenKeyPrefix = "com.streamly.twitch.\(clientId).\(tokenNamespace ?? "default")"
        self.accessTokenKey = "\(self.tokenKeyPrefix).accessToken"
        self.refreshTokenKey = "\(self.tokenKeyPrefix).refreshToken"

        if let data = try? KeychainStore.load(key: accessTokenKey),
           let token = String(data: data, encoding: .utf8) {
            cachedAccessToken = token
            logger.info("Loaded access token from Keychain")
        }
        if let data = try? KeychainStore.load(key: refreshTokenKey),
           let token = String(data: data, encoding: .utf8) {
            cachedRefreshToken = token
            logger.info("Loaded refresh token from Keychain")
        }
    }

    // MARK: - Public

    public var isAuthenticated: Bool {
        cachedAccessToken != nil
    }

    public func accessToken() throws -> String {
        guard let token = cachedAccessToken else {
            throw HelixError.notAuthenticated
        }
        return token
    }

    /// Stores externally obtained tokens, useful when the host app or backend owns OAuth.
    public func setToken(_ token: OAuthToken) throws {
        try storeTokens(access: token.accessToken, refresh: token.refreshToken)
    }

    /// Builds an OAuth implicit grant URL for public mobile/client apps without refresh tokens.
    public func implicitGrantURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        implicitGrantURL(rawScopes: scopes.map(\.rawValue), state: state, forceVerify: forceVerify)
    }

    /// Builds an OAuth implicit grant URL with raw scope strings.
    public func implicitGrantURL(
        rawScopes: [String],
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(responseType: "token", scopes: rawScopes, state: state, forceVerify: forceVerify)
    }

    /// Builds an authorization code URL for server-backed apps that can protect a client secret.
    public func authorizationCodeURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationCodeURL(rawScopes: scopes.map(\.rawValue), state: state, forceVerify: forceVerify)
    }

    /// Builds an authorization code URL with raw scope strings.
    public func authorizationCodeURL(
        rawScopes: [String],
        state: String? = nil,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(responseType: "code", scopes: rawScopes, state: state, forceVerify: forceVerify)
    }

    /// Builds an OIDC implicit grant URL when the app also needs an ID token for sign-in.
    public func oidcImplicitGrantURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oidcImplicitGrantURL(rawScopes: scopes.map(\.rawValue), claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Builds an OIDC implicit grant URL with raw scope strings.
    public func oidcImplicitGrantURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(responseType: "token id_token", scopes: oidcScopes(rawScopes), state: state, forceVerify: forceVerify, nonce: nonce, claims: claims)
    }

    /// Builds an OIDC authorization code URL for server-backed sign-in plus Twitch API access.
    public func oidcAuthorizationCodeURL(
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases,
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        oidcAuthorizationCodeURL(rawScopes: scopes.map(\.rawValue), claims: claims, state: state, nonce: nonce, forceVerify: forceVerify)
    }

    /// Builds an OIDC authorization code URL with raw scope strings.
    public func oidcAuthorizationCodeURL(
        rawScopes: [String],
        claims: String? = nil,
        state: String? = nil,
        nonce: String,
        forceVerify: Bool = true
    ) -> URL {
        authorizationURL(responseType: "code", scopes: oidcScopes(rawScopes), state: state, forceVerify: forceVerify, nonce: nonce, claims: claims)
    }

    /// Backwards-compatible alias for authorization-code apps.
    @available(*, deprecated, renamed: "authorizationCodeURL")
    public func buildAuthURL() -> URL {
        authorizationCodeURL()
    }

    /// Exchanges an authorization code for tokens and stores them for future API requests.
    public func authenticate(withAuthorizationCode code: String) async throws {
        let token = try await exchangeAuthorizationCode(code)
        try storeTokens(access: token.accessToken, refresh: token.refreshToken)
    }

    @available(*, deprecated, renamed: "authenticate(withAuthorizationCode:)")
    public func handleAuthCode(_ code: String) async throws {
        try await authenticate(withAuthorizationCode: code)
    }

    /// Requests an app access token with the client credentials flow.
    public func requestAppAccessToken(scopes: [TwitchScope] = []) async throws -> OAuthToken {
        try await requestAppAccessToken(rawScopes: scopes.map(\.rawValue))
    }

    /// Requests an app access token with raw scope strings.
    public func requestAppAccessToken(rawScopes: [String]) async throws -> OAuthToken {
        guard let clientSecret else { throw HelixError.missingClientSecret }
        let fields = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "grant_type": "client_credentials",
            "scope": rawScopes.joined(separator: " "),
        ]
        return try await postTokenRequest(fields: fields)
    }

    /// Starts Twitch's device code flow for clients with limited text input.
    public func startDeviceCodeFlow(scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> DeviceCodeAuthorization {
        try await startDeviceCodeFlow(rawScopes: scopes.map(\.rawValue))
    }

    /// Starts Twitch's device code flow with raw scope strings.
    public func startDeviceCodeFlow(rawScopes: [String]) async throws -> DeviceCodeAuthorization {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/device")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded([
            "client_id": clientId,
            "scopes": rawScopes.joined(separator: " "),
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw HelixError.unauthorized
        }
        return try JSONDecoder.twitch().decode(DeviceCodeAuthorization.self, from: data)
    }

    /// Polls Twitch for device-code completion and stores the token on success.
    public func pollDeviceCode(
        _ authorization: DeviceCodeAuthorization,
        scopes: [TwitchScope] = TwitchAuth.defaultScopeCases
    ) async throws -> OAuthToken {
        try await pollDeviceCode(deviceCode: authorization.deviceCode, rawScopes: scopes.map(\.rawValue))
    }

    /// Polls Twitch for device-code completion using an explicit device code.
    public func pollDeviceCode(deviceCode: String, scopes: [TwitchScope] = TwitchAuth.defaultScopeCases) async throws -> OAuthToken {
        try await pollDeviceCode(deviceCode: deviceCode, rawScopes: scopes.map(\.rawValue))
    }

    /// Polls Twitch for device-code completion using raw scope strings.
    public func pollDeviceCode(deviceCode: String, rawScopes: [String]) async throws -> OAuthToken {
        let token = try await postTokenRequest(fields: [
            "client_id": clientId,
            "scope": rawScopes.joined(separator: " "),
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ])
        try storeTokens(access: token.accessToken, refresh: token.refreshToken)
        return token
    }

    @available(*, deprecated, renamed: "pollDeviceCode(deviceCode:scopes:)")
    public func pollDeviceCode(_ deviceCode: String, scopes: [String]) async throws -> OAuthToken {
        try await pollDeviceCode(deviceCode: deviceCode, rawScopes: scopes)
    }

    public func refreshIfNeeded() async throws {
        guard let refreshToken = cachedRefreshToken else {
            logger.warning("Token refresh requested but no refresh token available")
            throw HelixError.unauthorized
        }

        var fields = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId,
        ]
        if let clientSecret {
            fields["client_secret"] = clientSecret
        }

        do {
            let token = try await postTokenRequest(fields: fields)
            try storeTokens(access: token.accessToken, refresh: token.refreshToken)
            logger.info("Token refresh succeeded")
        } catch {
            logout()
            throw error
        }
    }

    public func validateToken() async throws {
        guard let token = cachedAccessToken else {
            logger.info("No token to validate")
            return
        }

        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/validate")!)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }

        if http.statusCode == 401 {
            logger.warning("Token validation returned 401; attempting refresh")
            try await refreshIfNeeded()
        }
    }

    public func logout() {
        cachedAccessToken = nil
        cachedRefreshToken = nil
        KeychainStore.delete(key: accessTokenKey)
        KeychainStore.delete(key: refreshTokenKey)
    }

    // MARK: - Private

    private func exchangeAuthorizationCode(_ code: String) async throws -> OAuthToken {
        guard let clientSecret else { throw HelixError.missingClientSecret }
        return try await postTokenRequest(fields: [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri,
        ])
    }

    private func postTokenRequest(fields: [String: String]) async throws -> OAuthToken {
        var request = URLRequest(url: URL(string: "https://id.twitch.tv/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncoded(fields)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw HelixError.unauthorized
        }
        return try JSONDecoder.twitch().decode(OAuthToken.self, from: data)
    }

    private func authorizationURL(
        responseType: String,
        scopes: [String],
        state: String?,
        forceVerify: Bool,
        nonce: String? = nil,
        claims: String? = nil
    ) -> URL {
        var queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: responseType),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "force_verify", value: forceVerify ? "true" : "false"),
        ]
        if let state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        if let nonce {
            queryItems.append(URLQueryItem(name: "nonce", value: nonce))
        }
        if let claims {
            queryItems.append(URLQueryItem(name: "claims", value: claims))
        }

        var components = URLComponents(string: "https://id.twitch.tv/oauth2/authorize")!
        components.queryItems = queryItems
        return components.url!
    }

    private func oidcScopes(_ scopes: [String]) -> [String] {
        scopes.contains("openid") ? scopes : ["openid"] + scopes
    }

    private func storeTokens(access: String, refresh: String?) throws {
        cachedAccessToken = access
        try KeychainStore.save(key: accessTokenKey, data: Data(access.utf8))
        if let refresh {
            cachedRefreshToken = refresh
            try KeychainStore.save(key: refreshTokenKey, data: Data(refresh.utf8))
        }
    }
}

private func formEncoded(_ fields: [String: String]) -> Data? {
    let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+="))
    return fields
        .filter { !$0.value.isEmpty }
        .map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
}
