import Foundation
import XCTest
@testable import TwitchKit

final class EventSubWebhookVerifierTests: XCTestCase {
    func test_eventSubWebhookVerifierValidatesSignature() throws {
        let body = Data(#"{"subscription":{"id":"sub"},"challenge":"abc123"}"#.utf8)
        let verifier = EventSubWebhookVerifier(secret: "secret")

        XCTAssertTrue(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: "sha256=ee5636024ec838b2bccd0e7b35bb8d7785529a3b250f063f69eabe841e040d6c"
            )
        )
        XCTAssertFalse(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: "sha256=invalid"
            )
        )
    }

    func test_eventSubWebhookVerifierExtractsChallenge() throws {
        let body = Data(#"{"subscription":{"id":"sub"},"challenge":"abc123"}"#.utf8)

        let challenge = try EventSubWebhookVerifier.challenge(from: body)

        XCTAssertEqual(challenge, "abc123")
    }

    func test_eventSubWebhookVerifierAcceptsFreshTimestamp() {
        // 2024-01-01T00:00:00Z
        let sent = Date(timeIntervalSince1970: 1_704_067_200)

        XCTAssertTrue(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(60)
            )
        )
        XCTAssertTrue(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00.500Z",
                now: sent.addingTimeInterval(60)
            )
        )
        // Exactly at the 10-minute boundary is still fresh.
        XCTAssertTrue(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(600)
            )
        )
    }

    func test_eventSubWebhookVerifierRejectsStaleTimestamp() {
        // 2024-01-01T00:00:00Z, evaluated 11 minutes later.
        let sent = Date(timeIntervalSince1970: 1_704_067_200)

        XCTAssertFalse(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(660)
            )
        )
    }

    func test_eventSubWebhookVerifierRejectsUnparseableTimestamp() {
        XCTAssertFalse(EventSubWebhookVerifier.isTimestampFresh("not-a-date", now: .now))
        XCTAssertFalse(EventSubWebhookVerifier.isTimestampFresh("", now: .now))
    }

    func test_eventSubWebhookVerifierRejectsFarFutureTimestamp() {
        // 2024-01-01T00:00:00Z
        let sent = Date(timeIntervalSince1970: 1_704_067_200)

        // 6 minutes ahead of "now" exceeds the 5-minute forward skew allowance.
        XCTAssertFalse(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(-360)
            )
        )
        // 1 minute ahead of "now" is tolerated as clock skew.
        XCTAssertTrue(
            EventSubWebhookVerifier.isTimestampFresh(
                "2024-01-01T00:00:00Z",
                now: sent.addingTimeInterval(-60)
            )
        )
    }

    func test_eventSubWebhookVerifierValidatesSignatureAndFreshness() {
        let body = Data(#"{"subscription":{"id":"sub"},"challenge":"abc123"}"#.utf8)
        let verifier = EventSubWebhookVerifier(secret: "secret")
        // 2024-01-01T00:00:00Z, matching the timestamp signed below.
        let sent = Date(timeIntervalSince1970: 1_704_067_200)

        // Valid signature and a fresh timestamp passes.
        XCTAssertTrue(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: "sha256=ee5636024ec838b2bccd0e7b35bb8d7785529a3b250f063f69eabe841e040d6c",
                now: sent.addingTimeInterval(60)
            )
        )
        // A valid signature does not save a stale (replayed) message.
        XCTAssertFalse(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: "sha256=ee5636024ec838b2bccd0e7b35bb8d7785529a3b250f063f69eabe841e040d6c",
                now: sent.addingTimeInterval(660)
            )
        )
        // A fresh timestamp does not save an invalid signature.
        XCTAssertFalse(
            verifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: "sha256=invalid",
                now: sent.addingTimeInterval(60)
            )
        )
        // The static overload applies the same freshness check.
        XCTAssertFalse(
            EventSubWebhookVerifier.isValid(
                messageID: "msg-1",
                timestamp: "2024-01-01T00:00:00Z",
                body: body,
                signature: "sha256=ee5636024ec838b2bccd0e7b35bb8d7785529a3b250f063f69eabe841e040d6c",
                secret: "secret",
                now: sent.addingTimeInterval(660)
            )
        )
    }
}
