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
}
