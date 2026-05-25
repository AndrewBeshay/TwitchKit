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

    func test_helixRequestUsesConfiguredTimeout() async throws {
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
        let api = HelixClient(
            auth: auth,
            clientId: "client-id",
            httpClient: transport,
            requestConfiguration: HelixRequestConfiguration(timeoutInterval: 12)
        )

        _ = try await api.fetchUser()

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.timeoutInterval, 12)
    }

    func test_helixRequestPreservesCancellation() async throws {
        let transport = MockHTTPClient(responses: [.cancellation])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func test_fetchUsersUsesRepeatedIdAndLoginQueryParameters() async throws {
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
                },
                {
                  "id": "2",
                  "login": "anotherdev",
                  "display_name": "AnotherDev",
                  "profile_image_url": "https://example.com/profile2.png",
                  "broadcaster_type": ""
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let users = try await api.fetchUsers(ids: ["1"], logins: ["anotherdev"])

        XCTAssertEqual(users.map(\.login), ["twitchdev", "anotherdev"])

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/users?id=1&login=anotherdev"
        )
    }

    func test_fetchUserByLoginReturnsFirstMatch() async throws {
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

        let user = try await api.fetchUser(login: "twitchdev")

        XCTAssertEqual(user.id, "1")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://api.twitch.tv/helix/users?login=twitchdev")
    }

    func test_fetchUsersRequiresAtLeastOneIdentifier() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchUsers()
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "At least one user ID or login is required")
        }
    }

    func test_fetchStreamsPageUsesFilterAndPaginationQueryParameters() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "stream-1",
                  "user_id": "1",
                  "user_login": "twitchdev",
                  "user_name": "TwitchDev",
                  "game_id": "493057",
                  "game_name": "PUBG: BATTLEGROUNDS",
                  "type": "live",
                  "title": "Building TwitchKit",
                  "tags": ["Swift"],
                  "viewer_count": 42,
                  "started_at": "2024-01-01T00:00:00Z",
                  "language": "en",
                  "thumbnail_url": "https://example.com/{width}x{height}.jpg",
                  "is_mature": false
                }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let page = try await api.fetchStreamsPage(
            userIDs: ["1"],
            gameIDs: ["493057"],
            languages: ["en"],
            type: .live,
            first: 25,
            after: "cursor",
            before: "previous-cursor"
        )

        XCTAssertEqual(page.data.first?.userLogin, "twitchdev")
        XCTAssertEqual(page.nextCursor, "next-cursor")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/streams?user_id=1&game_id=493057&language=en&type=live&first=25&after=cursor&before=previous-cursor"
        )
    }

    func test_fetchStreamForOfflineUserReturnsNil() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: #"{"data":[]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let stream = try await api.fetchStream(forUserID: "offline-user")

        XCTAssertNil(stream)
    }

    func test_fetchGamesUsesRepeatedIdentifierQueryParameters() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "493057",
                  "name": "PUBG: BATTLEGROUNDS",
                  "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/493057-{width}x{height}.jpg",
                  "igdb_id": "27789"
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let games = try await api.fetchGames(ids: ["493057"], names: ["Just Chatting"], igdbIDs: ["27789"])

        XCTAssertEqual(games.first?.name, "PUBG: BATTLEGROUNDS")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/games?id=493057&name=Just%20Chatting&igdb_id=27789"
        )
    }

    func test_fetchTopGamesPageUsesPaginationQueryParameters() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "id": "493057",
                  "name": "PUBG: BATTLEGROUNDS",
                  "box_art_url": "https://static-cdn.jtvnw.net/ttv-boxart/493057-{width}x{height}.jpg",
                  "igdb_id": "27789"
                }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let page = try await api.fetchTopGamesPage(first: 10, after: "cursor")

        XCTAssertEqual(page.data.first?.id, "493057")
        XCTAssertEqual(page.nextCursor, "next-cursor")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/games/top?first=10&after=cursor"
        )
    }

    func test_sendChatMessageEncodesTypedRequestBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "message_id": "message-1",
                  "is_sent": true
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let result = try await api.sendChatMessage(
            broadcasterId: "broadcaster-id",
            senderId: "sender-id",
            message: "Hello from TwitchKit",
            replyParentMessageId: "parent-message-id",
            forSourceOnly: true,
            pin: true
        )

        XCTAssertEqual(result.messageId, "message-1")
        XCTAssertTrue(result.isSent)

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://api.twitch.tv/helix/chat/messages")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(object["broadcaster_id"] as? String, "broadcaster-id")
        XCTAssertEqual(object["sender_id"] as? String, "sender-id")
        XCTAssertEqual(object["message"] as? String, "Hello from TwitchKit")
        XCTAssertEqual(object["reply_parent_message_id"] as? String, "parent-message-id")
        XCTAssertEqual(object["for_source_only"] as? Bool, true)
        XCTAssertEqual(object["pin"] as? Bool, true)
    }

    func test_sendChatMessageReturnsDropReasonWhenMessageIsNotSent() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "message_id": "",
                  "is_sent": false,
                  "drop_reason": {
                    "code": "automod_held",
                    "message": "Your message has been held for review by AutoMod."
                  }
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let result = try await api.sendChatMessage(
            broadcasterId: "broadcaster-id",
            senderId: "sender-id",
            message: "Held message"
        )

        XCTAssertFalse(result.isSent)
        XCTAssertEqual(result.dropReason?.code, "automod_held")
    }

    func test_fetchChattersPageUsesBroadcasterModeratorAndPagination() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                { "user_id": "1", "user_login": "viewer", "user_name": "Viewer" }
              ],
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let page = try await api.fetchChattersPage(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            first: 50,
            after: "cursor"
        )

        XCTAssertEqual(page.data.first?.userLogin, "viewer")
        let request = try await firstRecordedRequest(from: transport)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/chat/chatters?broadcaster_id=broadcaster&moderator_id=moderator&first=50&after=cursor"
        )
    }

    func test_updateChatSettingsEncodesOnlyProvidedFields() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "broadcaster_id": "broadcaster",
                  "emote_mode": false,
                  "follower_mode": true,
                  "follower_mode_duration": 10,
                  "slow_mode": true,
                  "slow_mode_wait_time": 30,
                  "subscriber_mode": false,
                  "unique_chat_mode": false
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        _ = try await api.updateChatSettings(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            with: ChatSettingsUpdate(slowMode: true, slowModeWaitTime: 30)
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/chat/settings?broadcaster_id=broadcaster&moderator_id=moderator"
        )
        XCTAssertEqual(object["slow_mode"] as? Bool, true)
        XCTAssertEqual(object["slow_mode_wait_time"] as? Int, 30)
        XCTAssertNil(object["subscriber_mode"])
    }

    func test_sendAnnouncementUsesQueryParametersAndJSONBody() async throws {
        let transport = MockHTTPClient(responses: [.json(statusCode: 204, body: "")])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        try await api.sendChatAnnouncement(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            message: "hello",
            color: .purple
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/chat/announcements?broadcaster_id=broadcaster&moderator_id=moderator"
        )
        XCTAssertEqual(object["message"] as? String, "hello")
        XCTAssertEqual(object["color"] as? String, "purple")
    }

    func test_banUserEncodesNestedDataBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "user_id": "target",
                  "user_login": "targetlogin",
                  "user_name": "Target",
                  "expires_at": "2026-01-01T00:00:00Z",
                  "created_at": "2025-01-01T00:00:00Z",
                  "reason": "test",
                  "moderator_id": "moderator",
                  "moderator_login": "modlogin",
                  "moderator_name": "Mod"
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        _ = try await api.banUser(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            userID: "target",
            duration: 60,
            reason: "test"
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let data = try XCTUnwrap(object["data"] as? [String: Any])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/bans?broadcaster_id=broadcaster&moderator_id=moderator"
        )
        XCTAssertEqual(data["user_id"] as? String, "target")
        XCTAssertEqual(data["duration"] as? Int, 60)
        XCTAssertEqual(data["reason"] as? String, "test")
    }

    func test_fetchModeratorsPageUsesRepeatedUserIDs() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                { "user_id": "1", "user_login": "mod", "user_name": "Mod" }
              ],
              "pagination": {}
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        _ = try await api.fetchModeratorsPage(broadcasterID: "broadcaster", userIDs: ["1", "2"])

        let request = try await firstRecordedRequest(from: transport)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/moderators?broadcaster_id=broadcaster&user_id=1&user_id=2"
        )
    }

    func test_warnChatUserEncodesNestedDataBody() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "broadcaster_id": "broadcaster",
                  "user_id": "target",
                  "moderator_id": "moderator",
                  "reason": "stop"
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        _ = try await api.warnChatUser(
            broadcasterID: "broadcaster",
            moderatorID: "moderator",
            userID: "target",
            reason: "stop"
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let data = try XCTUnwrap(object["data"] as? [String: Any])
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/moderation/warnings?broadcaster_id=broadcaster&moderator_id=moderator"
        )
        XCTAssertEqual(data["user_id"] as? String, "target")
        XCTAssertEqual(data["reason"] as? String, "stop")
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

    func test_rateLimitPreservesRateLimitHeaders() async throws {
        let resetAt = Date.now.addingTimeInterval(30)
        let resetEpoch = Int(resetAt.timeIntervalSince1970)
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 429,
                body: #"{"error":"Too Many Requests","status":429,"message":"Rate limit exceeded"}"#,
                headers: [
                    "Ratelimit-Limit": "800",
                    "Ratelimit-Remaining": "0",
                    "Ratelimit-Reset": "\(resetEpoch)",
                    "Retry-After": "17",
                ]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected rate limit error")
        } catch let error as HelixError {
            guard case .rateLimited(let rateLimit) = error else {
                return XCTFail("Expected rateLimited, got \(error)")
            }
            XCTAssertEqual(rateLimit.limit, 800)
            XCTAssertEqual(rateLimit.remaining, 0)
            XCTAssertEqual(rateLimit.resetAt, Date(timeIntervalSince1970: TimeInterval(resetEpoch)))
            XCTAssertEqual(rateLimit.retryAfter, 17)
            XCTAssertEqual(rateLimit.recommendedRetryDelay, 17)
        }
    }

    func test_rateLimitFallsBackToResetHeaderForRetryDelay() async throws {
        let resetAt = Date.now.addingTimeInterval(30)
        let resetEpoch = Int(resetAt.timeIntervalSince1970)
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 429,
                body: #"{"error":"Too Many Requests","status":429,"message":"Rate limit exceeded"}"#,
                headers: ["Ratelimit-Reset": "\(resetEpoch)"]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected rate limit error")
        } catch let error as HelixError {
            guard case .rateLimited(let rateLimit) = error else {
                return XCTFail("Expected rateLimited, got \(error)")
            }
            XCTAssertEqual(rateLimit.retryAfter, nil)
            XCTAssertNotNil(rateLimit.resetAt)
            XCTAssertGreaterThanOrEqual(rateLimit.recommendedRetryDelay ?? 0, 0)
        }
    }

    func test_successfulPageResponseIncludesRateLimitMetadata() async throws {
        let resetEpoch = 1_770_000_000
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 200,
                body: """
                {
                  "data": [
                    {
                      "id": "509658",
                      "name": "Just Chatting",
                      "box_art_url": "https://example.com/box-{width}x{height}.jpg",
                      "igdb_id": "0"
                    }
                  ],
                  "pagination": { "cursor": "next-cursor" }
                }
                """,
                headers: [
                    "Ratelimit-Limit": "800",
                    "Ratelimit-Remaining": "799",
                    "Ratelimit-Reset": "\(resetEpoch)",
                ]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let page = try await api.fetchTopGamesPage(first: 1)

        XCTAssertEqual(page.data.first?.id, "509658")
        XCTAssertEqual(page.nextCursor, "next-cursor")
        XCTAssertEqual(page.metadata?.statusCode, 200)
        XCTAssertEqual(page.metadata?.rateLimit.limit, 800)
        XCTAssertEqual(page.metadata?.rateLimit.remaining, 799)
        XCTAssertEqual(page.metadata?.rateLimit.resetAt, Date(timeIntervalSince1970: TimeInterval(resetEpoch)))
    }

    func test_responseMetadataHandlerReceivesSuccessfulResponseMetadata() async throws {
        let recorder = MetadataRecorder()
        let transport = MockHTTPClient(responses: [
            .json(
                statusCode: 200,
                body: """
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
                """,
                headers: ["Ratelimit-Remaining": "798"]
            )
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(
            auth: auth,
            clientId: "client-id",
            httpClient: transport,
            responseMetadataHandler: { metadata in
                Task { await recorder.append(metadata) }
            }
        )

        _ = try await api.fetchUser()

        let metadata = try await recorder.waitForFirst()
        XCTAssertEqual(metadata.statusCode, 200)
        XCTAssertEqual(metadata.rateLimit.remaining, 798)
    }

    func test_serviceUnavailableRetriesOnceByDefault() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 503, body: #"{"error":"Service Unavailable","status":503,"message":"Try again"}"#),
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
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let user = try await api.fetchUser()

        XCTAssertEqual(user.id, "1")
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    func test_serviceUnavailableRetryCanBeDisabled() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 503, body: #"{"error":"Service Unavailable","status":503,"message":"Try again"}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(
            auth: auth,
            clientId: "client-id",
            httpClient: transport,
            retryPolicy: .never
        )

        do {
            _ = try await api.fetchUser()
            XCTFail("Expected server error")
        } catch let error as HelixError {
            guard case .serverError(let status) = error else {
                return XCTFail("Expected serverError, got \(error)")
            }
            XCTAssertEqual(status, 503)
        }

        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
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
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let transportBody = try XCTUnwrap(object["transport"] as? [String: Any])
        XCTAssertEqual(transportBody["method"] as? String, "websocket")
        XCTAssertEqual(transportBody["session_id"] as? String, "session-id")
    }

    func test_eventSubSubscriptionSupportsWebhookTransport() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 202, body: #"{"data":[]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        try await api.createEventSubSubscription(
            type: "user.update",
            version: "1",
            condition: ["user_id": "1234"],
            transport: .webhook(callback: URL(string: "https://example.com/eventsub")!, secret: "secret")
        )

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let transportBody = try XCTUnwrap(object["transport"] as? [String: Any])
        XCTAssertEqual(transportBody["method"] as? String, "webhook")
        XCTAssertEqual(transportBody["callback"] as? String, "https://example.com/eventsub")
        XCTAssertEqual(transportBody["secret"] as? String, "secret")
    }

    func test_eventSubSubscriptionSupportsBatchingFlag() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 202, body: #"{"data":[]}"#)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        try await api.createEventSubSubscription(
            type: "drop.entitlement.grant",
            version: "1",
            condition: ["organization_id": "organization"],
            transport: .webhook(callback: URL(string: "https://example.com/eventsub")!, secret: "secret"),
            isBatchingEnabled: true
        )

        let request = try await firstRecordedRequest(from: transport)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["is_batching_enabled"] as? Bool, true)
    }

    func test_fetchEventSubSubscriptionsPageDecodesCostMetadataAndFilter() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "total": 2,
              "data": [
                {
                  "id": "subscription-1",
                  "status": "enabled",
                  "type": "stream.online",
                  "version": "1",
                  "condition": {
                    "broadcaster_user_id": "1234"
                  },
                  "created_at": "2020-11-10T20:08:33.12345678Z",
                  "transport": {
                    "method": "websocket",
                    "session_id": "session-id",
                    "connected_at": "2020-11-10T20:08:30Z"
                  },
                  "cost": 1
                }
              ],
              "total_cost": 1,
              "max_total_cost": 10000,
              "pagination": { "cursor": "next-cursor" }
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let page = try await api.fetchEventSubSubscriptionsPage(
            filter: .status(.enabled),
            after: "cursor"
        )

        XCTAssertEqual(page.total, 2)
        XCTAssertEqual(page.totalCost, 1)
        XCTAssertEqual(page.maxTotalCost, 10000)
        XCTAssertEqual(page.nextCursor, "next-cursor")
        XCTAssertEqual(page.data.first?.id, "subscription-1")
        XCTAssertEqual(page.data.first?.status, .enabled)
        XCTAssertEqual(page.data.first?.transport.method, .websocket)
        XCTAssertEqual(page.data.first?.transport.sessionId, "session-id")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/eventsub/subscriptions?status=enabled&after=cursor"
        )
    }

    func test_fetchEventSubSubscriptionsPageSupportsSubscriptionFilter() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "total": 1,
              "data": [
                {
                  "id": "subscription-1",
                  "status": "webhook_callback_verification_pending",
                  "type": "user.update",
                  "version": "1",
                  "condition": {
                    "user_id": "1234"
                  },
                  "created_at": "2020-11-10T14:32:18.730260295Z",
                  "transport": {
                    "method": "webhook",
                    "callback": "https://example.com/eventsub"
                  },
                  "cost": 0
                }
              ],
              "pagination": {}
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let page = try await api.fetchEventSubSubscriptionsPage(filter: .subscriptionID("subscription-1"))

        XCTAssertEqual(page.data.first?.status, .webhookCallbackVerificationPending)
        XCTAssertEqual(page.data.first?.transport.callback?.absoluteString, "https://example.com/eventsub")

        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/eventsub/subscriptions?subscription_id=subscription-1"
        )
    }

    func test_fetchEventSubSubscriptionsPageRejectsEmptyFilterValue() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            _ = try await api.fetchEventSubSubscriptionsPage(filter: .subscriptionID(""))
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "EventSub subscription filter value is required")
        }
    }

    func test_deleteEventSubSubscriptionUsesDeleteMethodAndIdQuery() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 204, body: "")
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        try await api.deleteEventSubSubscription(id: "subscription-1")

        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://api.twitch.tv/helix/eventsub/subscriptions?id=subscription-1"
        )
    }

    func test_deleteEventSubSubscriptionRejectsEmptyID() async throws {
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: MockHTTPClient(responses: []))

        do {
            try await api.deleteEventSubSubscription(id: "")
            XCTFail("Expected bad request")
        } catch let error as HelixError {
            guard case .badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "EventSub subscription ID is required")
        }
    }

    func test_fetchChannelsInfoUsesRepeatedBroadcasterIDs() async throws {
        let transport = MockHTTPClient(responses: [
            .json(statusCode: 200, body: """
            {
              "data": [
                {
                  "broadcaster_id": "1",
                  "broadcaster_login": "twitchdev",
                  "broadcaster_name": "TwitchDev",
                  "broadcaster_language": "en",
                  "game_id": "509658",
                  "game_name": "Just Chatting",
                  "title": "Building TwitchKit",
                  "delay": 0,
                  "tags": ["Swift"],
                  "content_classification_labels": [],
                  "is_branded_content": false
                },
                {
                  "broadcaster_id": "2",
                  "broadcaster_login": "twitch",
                  "broadcaster_name": "Twitch",
                  "broadcaster_language": "en",
                  "game_id": "509658",
                  "game_name": "Just Chatting",
                  "title": "Live",
                  "delay": 0,
                  "tags": [],
                  "content_classification_labels": [],
                  "is_branded_content": false
                }
              ]
            }
            """)
        ])
        let auth = makeAuth()
        try await auth.setToken(OAuthToken(accessToken: "access-token"))
        let api = HelixClient(auth: auth, clientId: "client-id", httpClient: transport)

        let channels = try await api.fetchChannelsInfo(forBroadcasterIDs: ["1", "2"])

        XCTAssertEqual(channels.map(\.broadcasterName), ["TwitchDev", "Twitch"])
        let requests = await transport.recordedRequests()
        XCTAssertEqual(
            requests.first?.url?.absoluteString,
            "https://api.twitch.tv/helix/channels?broadcaster_id=1&broadcaster_id=2"
        )
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
        XCTAssertEqual(page.total, 2)

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
        case cancellation
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

        case .cancellation:
            throw CancellationError()
        }
    }
}

actor MetadataRecorder {
    private var metadata: [HelixResponseMetadata] = []

    func append(_ value: HelixResponseMetadata) {
        metadata.append(value)
    }

    func waitForFirst() async throws -> HelixResponseMetadata {
        for _ in 0..<20 {
            if let first = metadata.first {
                return first
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw HelixError.invalidResponse
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

private func firstRecordedRequest(from transport: MockHTTPClient) async throws -> URLRequest {
    let requests = await transport.recordedRequests()
    return try XCTUnwrap(requests.first)
}
