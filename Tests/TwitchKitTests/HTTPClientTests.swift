import Foundation
import XCTest
@testable import TwitchKit

final class HTTPClientTests: XCTestCase {
    func test_fetchUserSendsAuthorizationAndClientHeaders() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        _ = try await api.fetchUser()

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/users")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Client-Id"), "client-id")
    }

    func test_fetchUserRefreshesTokenAndRetriesOnceAfterUnauthorized() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 401, body: #"{"data":[]}"#),
            .json(statusCode: 200, body: #"{"access_token":"refreshed-token","refresh_token":"next-refresh","expires_in":3600,"token_type":"bearer"}"#),
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "1",
                  "login": "twitchdev",
                  "display_name": "TwitchDev",
                  "profile_image_url": "https://example.com/profile.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """),
        ])
        let auth = makeAuth(clientSecret: "secret", httpClient: transport)
        try await auth.setToken(OAuthToken(accessToken: "expired-token", refreshToken: "refresh-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        _ = try await api.fetchUser()

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer expired-token")
        XCTAssertEqual(requests[1].url?.absoluteString, "https://id.twitch.tv/oauth2/token")
        XCTAssertEqual(String(data: requests[1].httpBody ?? Data(), encoding: .utf8)?.contains("grant_type=refresh_token"), true)
        XCTAssertEqual(requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-token")
    }

    func test_authorizationCodeExchangeUsesInjectedHTTPClient() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"access_token":"access-token","refresh_token":"refresh-token","expires_in":3600,"token_type":"bearer"}"#)
        ])
        let auth = makeAuth(clientSecret: "secret", httpClient: transport)

        try await auth.authenticate(withAuthorizationCode: "auth-code")

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(request.url?.absoluteString, "https://id.twitch.tv/oauth2/token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(body?.contains("grant_type=authorization_code"), true)
        XCTAssertEqual(body?.contains("code=auth-code"), true)
        XCTAssertEqual(body?.contains("client_secret=secret"), true)
    }

    func test_nonHTTPResponseThrowsInvalidResponseInsteadOfCrashing() async throws {
        let transport = MockHTTPClient(responses: [
            .nonHTTP(body: Data())
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected invalid response")
        } catch let error as HelixError {
            guard case .invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }

    func test_rateLimitUsesRetryAfterHeader() async throws {
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 429,
                body: #"{"error":"Too Many Requests","status":429,"message":"Rate limit exceeded"}"#,
                headers: ["Retry-After": "17"]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected rate limit error")
        } catch let error as HelixError {
            guard case .rateLimited(let retryAfter) = error else {
                return XCTFail("Expected rateLimited, got \(error)")
            }
            XCTAssertEqual(retryAfter, 17)
        }
    }

    func test_twitchErrorResponsePreservesStatusAndErrorName() async throws {
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 400,
                body: #"{"error":"Bad Request","status":400,"message":"Missing broadcaster_id"}"#
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.error, "Bad Request")
            XCTAssertEqual(apiError.status, 400)
            XCTAssertEqual(apiError.message, "Missing broadcaster_id")
        }
    }

    func test_updateChannelInfoAcceptsNoContentResponse() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 204, body: "")
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        try await api.updateChannelInfo(
            forBroadcasterID: "broadcaster-id",
            with: ChannelInfoUpdate(title: "New title")
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/channels?broadcaster_id=broadcaster-id")
    }

    func test_eventSubSubscriptionAcceptsAcceptedResponse() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 202, body: #"{"data":[]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        try await api.createEventSubSubscription(
            type: "channel.chat.message",
            version: "1",
            condition: ["broadcaster_user_id": "broadcaster-id", "user_id": "user-id"],
            sessionId: "session-id"
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/eventsub/subscriptions")
    }

    func test_fetchChannelFollowersPageReturnsPaginationCursor() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "total": 2,
              "data": [
                {
                  "user_id": "1",
                  "user_login": "viewer1",
                  "user_name": "Viewer1",
                  "followed_at": "2024-01-01T00:00:00Z"
                }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let page = try await api.fetchChannelFollowersPage(
            forBroadcasterID: "broadcaster-id",
            first: 1
        )

        XCTAssertEqual(page.data.map(\.userName), ["Viewer1"])
        XCTAssertEqual(page.nextCursor, "next-cursor")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/channels/followers?broadcaster_id=broadcaster-id&first=1"
        )
    }

    func test_channelFollowersSequenceFetchesNextPageUsingCursor() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "total": 2,
              "data": [
                {
                  "user_id": "1",
                  "user_login": "viewer1",
                  "user_name": "Viewer1",
                  "followed_at": "2024-01-01T00:00:00Z"
                }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """),
            .json(statusCode: 200, body: """
            {
              "total": 2,
              "data": [
                {
                  "user_id": "2",
                  "user_login": "viewer2",
                  "user_name": "Viewer2",
                  "followed_at": "2024-01-02T00:00:00Z"
                }
              ],
              "pagination": {}
            }
            """),
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        var followers: [String] = []
        for try await follower in api.channelFollowers(forBroadcasterID: "broadcaster-id", pageSize: 1) {
            followers.append(follower.userName)
        }

        XCTAssertEqual(followers, ["Viewer1", "Viewer2"])

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(
            requests[0].url?.absoluteString,
            "https://api.twitch.tv/helix/channels/followers?broadcaster_id=broadcaster-id&first=1"
        )
        XCTAssertEqual(
            requests[1].url?.absoluteString,
            "https://api.twitch.tv/helix/channels/followers?broadcaster_id=broadcaster-id&first=1&after=next-cursor"
        )
    }
}

actor MockHTTPClient: HTTPClient {
    enum Response {
        case json(statusCode: Int, body: String, headers: [String: String] = [:])
        case nonHTTP(body: Data)
    }

    private var responses: [Response]
    private(set) var requests: [URLRequest] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else {
            throw HelixError.networkError("No mock response queued")
        }

        switch responses.removeFirst() {
        case .json(let statusCode, let body, let headers):
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            return (Data(body.utf8), response)

        case .nonHTTP(let body):
            return (body, URLResponse(url: request.url ?? URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: body.count, textEncodingName: nil))
        }
    }
}

private func makeAuth(
    clientId: String = "client-id",
    clientSecret: String? = nil,
    httpClient: any HTTPClient = URLSessionHTTPClient()
) -> TwitchAuth {
    TwitchAuth(
        oauthClient: TwitchOAuthClient(
            clientId: clientId,
            clientSecret: clientSecret,
            httpClient: httpClient
        ),
        tokenStore: InMemoryTokenStore()
    )
}
