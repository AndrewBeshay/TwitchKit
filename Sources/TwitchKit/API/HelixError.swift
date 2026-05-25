import Foundation

public enum HelixError: Error, Sendable, LocalizedError {
    // Auth
    case unauthorized
    case forbidden(String)

    // Client errors
    case badRequest(String)
    case notFound
    case conflict(String)
    case unprocessable(String)
    case rateLimited(retryAfter: Int)

    // Server errors
    case serverError(status: Int)

    // Client-side
    case notAuthenticated
    case missingClientSecret
    case invalidResponse
    case decodingFailed(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Unauthorized — token invalid or expired"
        case .forbidden(let msg): "Forbidden: \(msg)"
        case .badRequest(let msg): "Bad request: \(msg)"
        case .notFound: "Not found"
        case .conflict(let msg): "Conflict: \(msg)"
        case .unprocessable(let msg): "Unprocessable: \(msg)"
        case .rateLimited(let retry): "Rate limited — retry after \(retry)s"
        case .serverError(let status): "Server error (HTTP \(status))"
        case .notAuthenticated: "Not authenticated — login required"
        case .missingClientSecret: "Client secret required for this OAuth flow"
        case .invalidResponse: "Invalid HTTP response"
        case .decodingFailed(let msg): "JSON decode failed: \(msg)"
        case .networkError(let msg): "Network error: \(msg)"
        }
    }
}

/// Twitch API error response shape.
struct TwitchErrorResponse: Decodable {
    let error: String?
    let status: Int
    let message: String
}

/// Response wrapper for Helix endpoints.
public struct HelixResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: [T]
    public let pagination: Pagination?
}

public struct Pagination: Decodable, Sendable {
    public let cursor: String?
}

/// Factory for configured JSONDecoder — NOT shared (JSONDecoder is not Sendable).
extension JSONDecoder {
    static func twitch() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = TwitchDateParser.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Twitch ISO-8601 date: \(value)"
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    static func twitch() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

enum TwitchDateParser {
    static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
