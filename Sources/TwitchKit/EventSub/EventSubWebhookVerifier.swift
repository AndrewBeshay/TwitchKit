import CryptoKit
import Foundation

/// Verifies Twitch EventSub webhook signatures and callback verification challenges.
public struct EventSubWebhookVerifier: Sendable {
    public let secret: String

    public init(secret: String) {
        self.secret = secret
    }

    /// Returns `true` when the EventSub webhook request signature matches the request body.
    ///
    /// Build `messageID`, `timestamp`, and `signature` from Twitch's
    /// `Twitch-Eventsub-Message-Id`, `Twitch-Eventsub-Message-Timestamp`, and
    /// `Twitch-Eventsub-Message-Signature` headers. Pass the exact raw HTTP body bytes as `body`.
    public func isValid(messageID: String, timestamp: String, body: Data, signature: String) -> Bool {
        Self.isValid(messageID: messageID, timestamp: timestamp, body: body, signature: signature, secret: secret)
    }

    /// Returns `true` when the EventSub webhook request signature matches the request body.
    public static func isValid(
        messageID: String,
        timestamp: String,
        body: Data,
        signature: String,
        secret: String
    ) -> Bool {
        var message = Data(messageID.utf8)
        message.append(Data(timestamp.utf8))
        message.append(body)

        let key = SymmetricKey(data: Data(secret.utf8))
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: message, using: key)
        let expectedSignature = "sha256=" + authenticationCode.map { String(format: "%02x", $0) }.joined()
        return constantTimeEqual(expectedSignature, signature.lowercased())
    }

    /// Extracts the challenge string from a webhook callback verification request body.
    public static func challenge(from body: Data) throws -> String? {
        try JSONDecoder.twitch().decode(EventSubWebhookVerification.self, from: body).challenge
    }

    private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let lhsBytes = Array(lhs.utf8)
        let rhsBytes = Array(rhs.utf8)

        guard lhsBytes.count == rhsBytes.count else {
            return false
        }

        var difference: UInt8 = 0
        for index in lhsBytes.indices {
            difference |= lhsBytes[index] ^ rhsBytes[index]
        }
        return difference == 0
    }
}

private struct EventSubWebhookVerification: Decodable {
    let challenge: String?
}
