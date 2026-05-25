import Foundation

/// Top-level facade for TwitchKit. Holds auth, API client, and EventSub client.
/// Sendable — safe to pass across actor boundaries. NOT @Observable.
public final class TwitchClient: Sendable {
    public let clientId: String
    public let auth: TwitchAuth
    public let api: HelixClient
    public let eventSub: EventSubClient

    public init(
        clientId: String,
        clientSecret: String? = nil,
        tokenNamespace: String? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        isLive: @escaping @Sendable () async -> Bool = { false }
    ) {
        self.clientId = clientId
        let auth = TwitchAuth(
            clientId: clientId,
            clientSecret: clientSecret,
            tokenNamespace: tokenNamespace,
            httpClient: httpClient
        )
        let api = HelixClient(auth: auth, clientId: clientId, httpClient: httpClient)
        self.auth = auth
        self.api = api
        self.eventSub = EventSubClient(api: api, isLive: isLive)
    }
}
