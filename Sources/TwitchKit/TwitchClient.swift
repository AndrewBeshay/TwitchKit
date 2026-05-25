import Foundation

/// Top-level TwitchKit facade.
///
/// `TwitchClient` wires together OAuth/token storage, Helix HTTP APIs, and EventSub WebSocket APIs.
public final class TwitchClient: Sendable {
    /// Twitch application client ID used for Helix and OAuth requests.
    public let clientId: String

    /// OAuth and token-management helper.
    public let auth: TwitchAuth

    /// Helix HTTP API client.
    public let api: HelixClient

    /// EventSub WebSocket client.
    public let eventSub: EventSubClient

    /// Creates a TwitchKit client with shared auth, Helix, and EventSub components.
    ///
    /// - Parameters:
    ///   - clientId: Twitch application client ID.
    ///   - clientSecret: Optional Twitch application client secret for flows that require it.
    ///   - tokenNamespace: Optional namespace for the default keychain token store.
    ///   - tokenStore: Optional custom token store. Use this when a host app owns persistence.
    ///   - httpClient: HTTP transport used for OAuth and Helix requests.
    ///   - requestConfiguration: Request-level behavior for Helix HTTP calls.
    ///   - retryPolicy: Automatic retry behavior for Helix HTTP calls.
    ///   - responseMetadataHandler: Optional callback invoked with metadata from successful Helix responses.
    ///   - isLive: Returns whether the channel is live, used to tune EventSub reconnect behavior.
    public init(
        clientId: String,
        clientSecret: String? = nil,
        tokenNamespace: String? = nil,
        tokenStore: (any TwitchTokenStore)? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        requestConfiguration: HelixRequestConfiguration = .default,
        retryPolicy: HelixRetryPolicy = .default,
        responseMetadataHandler: (@Sendable (HelixResponseMetadata) -> Void)? = nil,
        isLive: @escaping @Sendable () async -> Bool = { false }
    ) {
        self.clientId = clientId
        let oauthClient = TwitchOAuthClient(clientId: clientId, clientSecret: clientSecret, httpClient: httpClient)
        let auth = if let tokenStore {
            TwitchAuth(oauthClient: oauthClient, tokenStore: tokenStore)
        } else {
            TwitchAuth(
                clientId: clientId,
                clientSecret: clientSecret,
                tokenNamespace: tokenNamespace,
                httpClient: httpClient
            )
        }
        let api = HelixClient(
            auth: auth,
            clientId: clientId,
            httpClient: httpClient,
            requestConfiguration: requestConfiguration,
            retryPolicy: retryPolicy,
            responseMetadataHandler: responseMetadataHandler
        )
        self.auth = auth
        self.api = api
        self.eventSub = EventSubClient(api: api, isLive: isLive)
    }
}
