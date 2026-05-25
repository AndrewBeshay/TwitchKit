import Foundation

public enum HelixError: Error, Sendable, LocalizedError {
    // Auth
    case unauthorized
    case forbidden(TwitchAPIError)

    // Client errors
    case badRequest(TwitchAPIError)
    case notFound
    case conflict(TwitchAPIError)
    case unprocessable(TwitchAPIError)
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
        case .forbidden(let error): "Forbidden: \(error.message)"
        case .badRequest(let error): "Bad request: \(error.message)"
        case .notFound: "Not found"
        case .conflict(let error): "Conflict: \(error.message)"
        case .unprocessable(let error): "Unprocessable: \(error.message)"
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
public struct TwitchAPIError: Decodable, Sendable, Equatable {
    public let error: String
    public let status: Int
    public let message: String

    public init(error: String, status: Int, message: String) {
        self.error = error
        self.status = status
        self.message = message
    }

    static func fallback(status: Int, message: String) -> Self {
        Self(error: "HTTP \(status)", status: status, message: message)
    }
}

/// Response wrapper for Helix endpoints.
public struct HelixResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let data: [T]
    public let pagination: Pagination?
    public let total: Int?

    public init(data: [T], pagination: Pagination? = nil, total: Int? = nil) {
        self.data = data
        self.pagination = pagination
        self.total = total
    }

    public var page: HelixPage<T> {
        HelixPage(data: data, pagination: pagination, total: total)
    }
}

public struct Pagination: Decodable, Sendable, Equatable {
    public let cursor: String?

    public init(cursor: String?) {
        self.cursor = cursor
    }
}

/// A single page of elements returned by a paginated Helix endpoint.
public struct HelixPage<Element: Sendable>: Sendable {
    public let data: [Element]
    public let pagination: Pagination?
    public let total: Int?

    public init(data: [Element], pagination: Pagination? = nil, total: Int? = nil) {
        self.data = data
        self.pagination = pagination
        self.total = total
    }

    public var nextCursor: String? {
        pagination?.cursor
    }
}

extension HelixPage: Equatable where Element: Equatable {}

/// An async sequence that lazily follows Helix cursor pagination.
public struct HelixPagedSequence<Element: Sendable>: AsyncSequence, Sendable {
    public typealias AsyncIterator = Iterator

    private let initialCursor: String?
    private let fetchPage: @Sendable (String?) async throws -> HelixPage<Element>

    public init(
        startingAfter initialCursor: String? = nil,
        fetchPage: @escaping @Sendable (String?) async throws -> HelixPage<Element>
    ) {
        self.initialCursor = initialCursor
        self.fetchPage = fetchPage
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(nextCursor: initialCursor, fetchPage: fetchPage)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var buffer: [Element] = []
        private var nextCursor: String?
        private var shouldFetchPage = true
        private let fetchPage: @Sendable (String?) async throws -> HelixPage<Element>

        init(
            nextCursor: String?,
            fetchPage: @escaping @Sendable (String?) async throws -> HelixPage<Element>
        ) {
            self.nextCursor = nextCursor
            self.fetchPage = fetchPage
        }

        public mutating func next() async throws -> Element? {
            while buffer.isEmpty {
                guard shouldFetchPage else {
                    return nil
                }

                let page = try await fetchPage(nextCursor)
                buffer = page.data
                nextCursor = page.nextCursor
                shouldFetchPage = page.nextCursor != nil

                if buffer.isEmpty, !shouldFetchPage {
                    return nil
                }
            }

            return buffer.removeFirst()
        }
    }
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
