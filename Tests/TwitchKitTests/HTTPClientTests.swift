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
        let auth = TwitchAuth(clientId: "client-id", tokenNamespace: "headers")
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
        let auth = TwitchAuth(clientId: "client-id", clientSecret: "secret", tokenNamespace: "retry", httpClient: transport)
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
        let auth = TwitchAuth(clientId: "client-id", clientSecret: "secret", tokenNamespace: "oauth", httpClient: transport)

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
        let auth = TwitchAuth(clientId: "client-id", tokenNamespace: "non-http")
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
