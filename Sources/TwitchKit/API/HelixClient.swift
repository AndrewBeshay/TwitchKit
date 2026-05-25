import Foundation
import os

private let logger = Logger(subsystem: "com.twitchkit", category: "helix")

public struct HelixClient: Sendable {
    private let tokenProvider: any TwitchAccessTokenProvider
    private let clientId: String
    private let httpClient: any HTTPClient

    private static let baseURL = "https://api.twitch.tv/helix/"

    public init(
        tokenProvider: any TwitchAccessTokenProvider,
        clientId: String,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.tokenProvider = tokenProvider
        self.clientId = clientId
        self.httpClient = httpClient
    }

    public init(auth: TwitchAuth, clientId: String, httpClient: any HTTPClient = URLSessionHTTPClient()) {
        self.init(tokenProvider: auth, clientId: clientId, httpClient: httpClient)
    }

    func request<T: Decodable & Sendable>(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> HelixResponse<T> {
        let response = try await sendAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        return try decodeHelixResponse(T.self, from: response.data, response: response.httpResponse)
    }

    func requestNoContent(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws {
        let response = try await sendAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        try validateSuccess(
            data: response.data,
            response: response.httpResponse,
            acceptedStatusCodes: [204],
            fallbackMessage: "No content response expected"
        )
    }

    func requestAccepted(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        fallbackMessage: String
    ) async throws {
        let response = try await sendAuthenticatedRequest(
            endpoint: endpoint,
            method: method,
            queryItems: queryItems,
            body: body
        )
        try validateSuccess(
            data: response.data,
            response: response.httpResponse,
            acceptedStatusCodes: [202],
            fallbackMessage: fallbackMessage
        )
    }

    func pagedRequest<T: Decodable & Sendable>(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil,
        pageSize: Int? = nil
    ) -> HelixPagedSequence<T> {
        HelixPagedSequence { cursor in
            var pagedQueryItems = queryItems ?? []
            try HelixQuery.appendPagination(to: &pagedQueryItems, first: pageSize, after: cursor)

            let response: HelixResponse<T> = try await request(
                endpoint: endpoint,
                queryItems: pagedQueryItems.isEmpty ? nil : pagedQueryItems
            )
            return response.page
        }
    }

    private func sendAuthenticatedRequest(
        endpoint: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> HelixHTTPResponse {
        var components = URLComponents(string: Self.baseURL + endpoint)!
        components.queryItems = queryItems

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = method
        urlRequest.httpBody = body

        let token = try await tokenProvider.accessToken()
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(clientId, forHTTPHeaderField: "Client-Id")
        if body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await httpClient.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HelixError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                logger.warning("Helix \(endpoint) returned 401; refreshing token and retrying")
                try await tokenProvider.refreshIfNeeded()
                let newToken = try await tokenProvider.accessToken()
                urlRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await httpClient.data(for: urlRequest)
                guard let retryHttp = retryResponse as? HTTPURLResponse else {
                    throw HelixError.invalidResponse
                }
                return HelixHTTPResponse(data: retryData, httpResponse: retryHttp)
            }

            return HelixHTTPResponse(data: data, httpResponse: httpResponse)
        } catch let error as HelixError {
            throw error
        } catch {
            throw HelixError.networkError(error.localizedDescription)
        }
    }

    private func decodeHelixResponse<T: Decodable & Sendable>(
        _ type: T.Type,
        from data: Data,
        response: HTTPURLResponse
    ) throws -> HelixResponse<T> {
        try validateSuccess(
            data: data,
            response: response,
            acceptedStatusCodes: [200, 202],
            fallbackMessage: "Helix response expected"
        )

        do {
            return try JSONDecoder.twitch().decode(HelixResponse<T>.self, from: data)
        } catch {
            let rawJSON = String(data: data.prefix(500), encoding: .utf8) ?? "non-utf8"
            logger.error("Helix decode failed for \(String(describing: type)): \(error); JSON: \(rawJSON)")
            throw HelixError.decodingFailed(error.localizedDescription)
        }
    }

    private func validateSuccess(
        data: Data,
        response: HTTPURLResponse,
        acceptedStatusCodes: Set<Int>,
        fallbackMessage: String
    ) throws {
        if acceptedStatusCodes.contains(response.statusCode) {
            return
        }
        try throwError(data: data, response: response, fallbackMessage: fallbackMessage)
    }

    private func throwError(data: Data, response: HTTPURLResponse, fallbackMessage: String) throws -> Never {
        switch response.statusCode {
        case 400:
            throw HelixError.badRequest(apiError(from: data, status: response.statusCode, fallbackMessage: fallbackMessage))
        case 401:
            throw HelixError.unauthorized
        case 403:
            throw HelixError.forbidden(apiError(from: data, status: response.statusCode, fallbackMessage: fallbackMessage))
        case 404:
            throw HelixError.notFound
        case 409:
            throw HelixError.conflict(apiError(from: data, status: response.statusCode, fallbackMessage: fallbackMessage))
        case 422:
            throw HelixError.unprocessable(apiError(from: data, status: response.statusCode, fallbackMessage: fallbackMessage))
        case 429:
            throw HelixError.rateLimited(retryAfter: retryAfter(from: response) ?? 60)
        default:
            throw HelixError.serverError(status: response.statusCode)
        }
    }

    private func apiError(from data: Data, status: Int, fallbackMessage: String) -> TwitchAPIError {
        (try? JSONDecoder.twitch().decode(TwitchAPIError.self, from: data))
            ?? TwitchAPIError.fallback(status: status, message: fallbackMessage)
    }

    private func retryAfter(from response: HTTPURLResponse) -> Int? {
        response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
    }
}

private struct HelixHTTPResponse: Sendable {
    let data: Data
    let httpResponse: HTTPURLResponse
}
