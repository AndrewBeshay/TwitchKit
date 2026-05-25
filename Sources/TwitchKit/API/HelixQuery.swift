import Foundation

enum HelixQuery {
    static func item(_ name: String, _ value: String?) -> URLQueryItem? {
        value.map { URLQueryItem(name: name, value: $0) }
    }

    static func items(_ name: String, values: [String]) -> [URLQueryItem] {
        values.map { URLQueryItem(name: name, value: $0) }
    }

    static func append(_ item: URLQueryItem?, to queryItems: inout [URLQueryItem]) {
        if let item {
            queryItems.append(item)
        }
    }

    static func appendPagination(
        to queryItems: inout [URLQueryItem],
        first: Int?,
        after cursor: String?
    ) throws {
        if let first {
            guard (1...100).contains(first) else {
                throw HelixError.badRequest(
                    TwitchAPIError.fallback(status: 400, message: "Page size must be between 1 and 100")
                )
            }
            queryItems.append(URLQueryItem(name: "first", value: String(first)))
        }

        if let cursor {
            queryItems.append(URLQueryItem(name: "after", value: cursor))
        }
    }
}
