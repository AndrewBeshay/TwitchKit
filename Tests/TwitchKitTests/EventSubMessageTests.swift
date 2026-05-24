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
}
