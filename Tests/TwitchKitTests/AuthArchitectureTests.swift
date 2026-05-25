import XCTest
@testable import TwitchKit

final class AuthArchitectureTests: XCTestCase {
    func test_tokenProviderStoresExternallyManagedToken() async throws {
        let store = InMemoryTokenStore()
        let provider = TwitchTokenProvider(
            oauthClient: TwitchOAuthClient(clientId: "client-id"),
            tokenStore: store
        )

        try await provider.setToken(OAuthToken(accessToken: "access-token", refreshToken: "refresh-token"))

        let accessToken = try await provider.accessToken()
        let storedToken = try await store.loadToken()
        XCTAssertEqual(accessToken, "access-token")
        XCTAssertEqual(storedToken?.refreshToken, "refresh-token")
    }

    func test_helixClientAcceptsAnyAccessTokenProvider() async throws {
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
        let api = HelixClient(
            tokenProvider: StaticTokenProvider(accessToken: "backend-issued-token"),
            clientId: "client-id",
            httpClient: transport
        )

        _ = try await api.fetchUser()

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer backend-issued-token")
    }
}

private struct StaticTokenProvider: TwitchAccessTokenProvider {
    let token: String

    init(accessToken: String) {
        token = accessToken
    }

    func accessToken() async throws -> String {
        token
    }

    func refreshIfNeeded() async throws {}
}
