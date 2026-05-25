import XCTest
import Foundation
@testable import TwitchKit

/// Tests for EventSub WebSocket message parsing — the envelope that wraps all events.
final class EventSubMessageTests: XCTestCase {

    func test_decodeSessionWelcome() throws {
        let json = """
        {
            "metadata": {
                "message_id": "96a3f3b5-5dec-4eed-908e-e11ee657416c",
                "message_type": "session_welcome",
                "message_timestamp": "2023-07-19T14:56:51.634234626Z"
            },
            "payload": {
                "session": {
                    "id": "AQoQHR3s6Mb4T8GFB1l3DlPfiRIGY2VsbC1h",
                    "status": "connected",
                    "connected_at": "2023-07-19T14:56:51.616329898Z",
                    "keepalive_timeout_seconds": 10,
                    "reconnect_url": null
                }
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder.twitch().decode(EventSubEnvelope.self, from: json)

        XCTAssertEqual(envelope.metadata.messageType, "session_welcome")
        XCTAssertEqual(envelope.payload.session?.id, "AQoQHR3s6Mb4T8GFB1l3DlPfiRIGY2VsbC1h")
        XCTAssertEqual(envelope.payload.session?.status, "connected")
        XCTAssertEqual(envelope.payload.session?.keepaliveTimeoutSeconds, 10)
        XCTAssertEqual(envelope.payload.session?.reconnectUrl, nil)
    }

    func test_decodeSessionKeepalive() throws {
        let json = """
        {
            "metadata": {
                "message_id": "keepalive-123",
                "message_type": "session_keepalive",
                "message_timestamp": "2023-07-19T15:00:00Z"
            },
            "payload": {}
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder.twitch().decode(EventSubEnvelope.self, from: json)

        XCTAssertEqual(envelope.metadata.messageType, "session_keepalive")
        XCTAssertNil(envelope.payload.session)
    }

    func test_decodeSessionReconnect() throws {
        let json = """
        {
            "metadata": {
                "message_id": "reconnect-456",
                "message_type": "session_reconnect",
                "message_timestamp": "2023-07-19T15:05:00Z"
            },
            "payload": {
                "session": {
                    "id": "newSession123",
                    "status": "reconnecting",
                    "keepalive_timeout_seconds": 10,
                    "reconnect_url": "wss://eventsub.wss.twitch.tv/ws?session_id=newSession123"
                }
            }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder.twitch().decode(EventSubEnvelope.self, from: json)

        XCTAssertEqual(envelope.metadata.messageType, "session_reconnect")
        XCTAssertEqual(envelope.payload.session?.reconnectUrl, "wss://eventsub.wss.twitch.tv/ws?session_id=newSession123")
    }

    func test_unknownEventType() {
        let data = "some raw payload".data(using: .utf8)!
        let event = EventSubEvent.unknown(type: "channel.new_thing", payload: data)

        if case .unknown(let type, let payload) = event {
            XCTAssertEqual(type, "channel.new_thing")
            XCTAssertEqual(payload, data)
        } else {
            XCTFail("Expected .unknown case")
        }
    }

    func test_decodeTypedStreamOnlineEvent() throws {
        let json = """
        {
            "id": "9001",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "type": "live",
            "started_at": "2020-10-11T10:11:12.123Z"
        }
        """.data(using: .utf8)!

        let event = EventSubEvent.decode(type: "stream.online", payload: json)

        guard case .streamOnline(let stream) = event else {
            return XCTFail("Expected .streamOnline")
        }
        XCTAssertEqual(stream.id, "9001")
        XCTAssertEqual(stream.broadcasterUserId, "1337")
        XCTAssertEqual(stream.type, .live)
    }

    func test_decodeTypedChannelUpdateEvent() throws {
        let json = """
        {
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "title": "Best Stream Ever",
            "language": "en",
            "category_id": "21779",
            "category_name": "Fortnite",
            "content_classification_labels": ["MatureGame"]
        }
        """.data(using: .utf8)!

        let event = EventSubEvent.decode(type: "channel.update", payload: json)

        guard case .channelUpdate(let update) = event else {
            return XCTFail("Expected .channelUpdate")
        }
        XCTAssertEqual(update.title, "Best Stream Ever")
        XCTAssertEqual(update.categoryName, "Fortnite")
        XCTAssertEqual(update.contentClassificationLabels, ["MatureGame"])
    }

    func test_decodeTypedModerationAndChannelPointsEvents() throws {
        let banJSON = """
        {
            "user_id": "1234",
            "user_login": "bad_user",
            "user_name": "Bad_User",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "moderator_user_id": "4242",
            "moderator_user_login": "mod_user",
            "moderator_user_name": "Mod_User",
            "reason": "Breaking the rules",
            "banned_at": "2020-07-15T18:16:11.17106713Z",
            "ends_at": null,
            "is_permanent": true
        }
        """.data(using: .utf8)!

        let redemptionJSON = """
        {
            "id": "redemption-id",
            "broadcaster_user_id": "1337",
            "broadcaster_user_login": "cool_user",
            "broadcaster_user_name": "Cool_User",
            "user_id": "9001",
            "user_login": "viewer",
            "user_name": "Viewer",
            "user_input": "Hydrate",
            "status": "unfulfilled",
            "reward": {
                "id": "reward-id",
                "title": "Hydrate",
                "prompt": "Drink water",
                "cost": 100
            },
            "redeemed_at": "2020-07-15T17:16:03.17106713Z"
        }
        """.data(using: .utf8)!

        let banEvent = EventSubEvent.decode(type: "channel.ban", payload: banJSON)
        let redemptionEvent = EventSubEvent.decode(
            type: "channel.channel_points_custom_reward_redemption.add",
            payload: redemptionJSON
        )

        guard case .ban(let ban) = banEvent else {
            return XCTFail("Expected .ban")
        }
        XCTAssertTrue(ban.isPermanent)
        XCTAssertEqual(ban.reason, "Breaking the rules")

        guard case .channelPointsCustomRewardRedemptionAdd(let redemption) = redemptionEvent else {
            return XCTFail("Expected .channelPointsCustomRewardRedemptionAdd")
        }
        XCTAssertEqual(redemption.status, .unfulfilled)
        XCTAssertEqual(redemption.reward.title, "Hydrate")
        XCTAssertEqual(redemption.userInput, "Hydrate")
    }

    func test_unknownEventDecodeFallsBackToRawPayload() {
        let data = #"{"future":true}"#.data(using: .utf8)!
        let event = EventSubEvent.decode(type: "channel.future", payload: data)

        guard case .unknown(let type, let payload) = event else {
            return XCTFail("Expected .unknown")
        }
        XCTAssertEqual(type, "channel.future")
        XCTAssertEqual(payload, data)
    }
}
