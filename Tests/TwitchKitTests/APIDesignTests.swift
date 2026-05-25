import XCTest
@testable import TwitchKit

final class APIDesignTests: XCTestCase {
    func test_authScopesSeparateDefaultsFromCompleteCatalog() {
        XCTAssertTrue(TwitchAuth.allScopes.contains("analytics:read:extensions"))
        XCTAssertTrue(TwitchAuth.defaultScopes.contains("user:read:email"))
        XCTAssertFalse(TwitchAuth.defaultScopes.contains("analytics:read:extensions"))
        XCTAssertLessThan(TwitchAuth.defaultScopes.count, TwitchAuth.allScopes.count)
    }

    func test_authURLsAcceptTypedScopes() {
        let auth = TwitchAuth(clientId: "client-id")

        let url = auth.implicitGrantURL(scopes: [.userReadEmail, .userReadChat])
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scope = components?.queryItems?.first { $0.name == "scope" }?.value

        XCTAssertEqual(scope, "user:read:email user:read:chat")
    }

    func test_rawScopeEscapeHatchAllowsFutureTwitchScopes() {
        let auth = TwitchAuth(clientId: "client-id")

        let url = auth.implicitGrantURL(rawScopes: ["future:scope"])
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let scope = components?.queryItems?.first { $0.name == "scope" }?.value

        XCTAssertEqual(scope, "future:scope")
    }

    func test_channelInfoUpdateEncodesOnlyProvidedFields() throws {
        let update = ChannelInfoUpdate(title: "New title", tags: [])

        let data = try JSONEncoder.twitch().encode(update)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["title"] as? String, "New title")
        XCTAssertEqual(object["tags"] as? [String], [])
        XCTAssertNil(object["game_id"])
    }

    func test_eventSubFactoriesUseMakePrefix() {
        let subscription = EventSubSubscription.makeChannelChatMessage(
            broadcasterID: "broadcaster",
            userID: "user"
        )

        XCTAssertEqual(subscription.type, "channel.chat.message")
        XCTAssertEqual(subscription.version, "1")
        XCTAssertEqual(subscription.condition["broadcaster_user_id"], "broadcaster")
        XCTAssertEqual(subscription.condition["user_id"], "user")
    }

    func test_chatMessageClosedDomainStringsDecodeKnownAndUnknownValues() throws {
        let known = try JSONDecoder.twitch().decode(ChatMessageType.self, from: Data(#""text""#.utf8))
        let unknown = try JSONDecoder.twitch().decode(ChatMessageType.self, from: Data(#""future_type""#.utf8))

        XCTAssertEqual(known, .text)
        XCTAssertEqual(unknown, .unknown("future_type"))
        XCTAssertEqual(known.rawValue, "text")
        XCTAssertEqual(unknown.rawValue, "future_type")
    }
}
