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
        var message = Data()
        message.reserveCapacity(messageID.utf8.count + timestamp.utf8.count + body.count)
        message.append(contentsOf: messageID.utf8)
        message.append(contentsOf: timestamp.utf8)
        message.append(body)

        let key = SymmetricKey(data: Data(secret.utf8))
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: message, using: key)
        guard let signatureBytes = signatureBytes(from: signature) else { return false }
        return constantTimeEqual(authenticationCode, signatureBytes)
    }

    /// Extracts the challenge string from a webhook callback verification request body.
    public static func challenge(from body: Data) throws -> String? {
        try JSONDecoder.twitch().decode(EventSubWebhookVerification.self, from: body).challenge
    }

    private static func signatureBytes(from signature: String) -> [UInt8]? {
        let prefix = Array("sha256=".utf8)
        let bytes = Array(signature.utf8)
        guard bytes.count == prefix.count + SHA256.byteCount * 2 else { return nil }

        for index in prefix.indices where bytes[index] != prefix[index] {
            return nil
        }

        var result: [UInt8] = []
        result.reserveCapacity(SHA256.byteCount)
        var index = prefix.count
        while index < bytes.count {
            guard let high = hexNibble(bytes[index]),
                  let low = hexNibble(bytes[index + 1]) else { return nil }
            result.append((high << 4) | low)
            index += 2
        }
        return result
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: byte - 48
        case 65...70: byte - 55
        case 97...102: byte - 87
        default: nil
        }
    }

    private static func constantTimeEqual(_ lhs: HMAC<SHA256>.MAC, _ rhs: [UInt8]) -> Bool {
        guard rhs.count == SHA256.byteCount else { return false }

        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}

private struct EventSubWebhookVerification: Decodable {
    let challenge: String?
}
