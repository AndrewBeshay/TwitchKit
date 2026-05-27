import Foundation
import os

private let logger = Logger(subsystem: "com.twitchkit", category: "eventsub")

public actor EventSubClient {
    /// Stream of parsed events — initialized once, consumers iterate without actor hop.
    public nonisolated let events: AsyncStream<EventSubEvent>
    private let eventsContinuation: AsyncStream<EventSubEvent>.Continuation

    private let api: HelixClient
    private let isLive: @Sendable () async -> Bool

    private var webSocketTask: URLSessionWebSocketTask?
    private var sessionId: String?
    private var receiveTask: Task<Void, Never>?
    private var keepaliveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var keepaliveTimeout: Int = 10
    private var reconnectAttempts: Int = 0
    private var shouldReconnect = false
    private var desiredSubscriptions: Set<EventSubSubscription> = []
    private var activeSubscriptionsById: [String: EventSubSubscription] = [:]
    private var seenMessageIds: Set<String> = []

    private static let websocketURL = URL(string: "wss://eventsub.wss.twitch.tv/ws")!

    public init(api: HelixClient, isLive: @escaping @Sendable () async -> Bool) {
        self.api = api
        self.isLive = isLive
        (events, eventsContinuation) = AsyncStream.makeStream(of: EventSubEvent.self)
    }

    // MARK: - Public

    /// Continuation used to make connect() wait for session_welcome before returning.
    private var welcomeContinuation: CheckedContinuation<Void, Error>?

    public func connect(timeout: Duration = .seconds(15)) async throws {
        shouldReconnect = true
        try await openConnection(to: Self.websocketURL, resetReconnectAttempts: true, timeout: timeout)
    }

    private func openConnection(
        to url: URL,
        resetReconnectAttempts: Bool,
        timeout: Duration
    ) async throws {
        if sessionId != nil {
            return
        }
        logger.info("🔌 EventSub: connecting to \(Self.websocketURL.absoluteString)")
        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        if resetReconnectAttempts {
            reconnectAttempts = 0
        }
        startReceiveLoop()

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.waitForWelcome() }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw HelixError.networkError("Timed out waiting for EventSub session_welcome")
                }
                defer { group.cancelAll() }
                try await group.next()
            }
        } catch {
            cleanupFailedConnection(task: task, error: error)
            throw error
        }
    }

    public func disconnect() async {
        logger.info("🔌 EventSub: disconnecting")
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        keepaliveTask?.cancel()
        keepaliveTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        sessionId = nil
        activeSubscriptionsById.removeAll()
        welcomeContinuation?.resume(throwing: HelixError.networkError("EventSub disconnected"))
        welcomeContinuation = nil
    }

    @discardableResult
    public func subscribe(_ subscription: EventSubSubscription) async throws -> EventSubSubscriptionRecord {
        desiredSubscriptions.insert(subscription)
        return try await createSubscription(subscription)
    }

    @discardableResult
    public func subscribe(type: String, version: String, condition: [String: String]) async throws -> EventSubSubscriptionRecord {
        try await subscribe(EventSubSubscription(type: type, version: version, condition: condition))
    }

    public func unsubscribe(id: String) async throws {
        try await api.deleteEventSubSubscription(id: id)
        if let subscription = activeSubscriptionsById.removeValue(forKey: id) {
            desiredSubscriptions.remove(subscription)
        }
    }

    private func createSubscription(_ subscription: EventSubSubscription) async throws -> EventSubSubscriptionRecord {
        guard let sessionId else {
            logger.error("❌ EventSub: no session ID — can't subscribe")
            throw HelixError.badRequest(
                TwitchAPIError.fallback(status: 400, message: "No EventSub session — call connect() first")
            )
        }
        logger.info("📡 EventSub: subscribing to \(subscription.type) v\(subscription.version) with session \(sessionId)")
        let record = try await api.createEventSubSubscription(
            type: subscription.type,
            version: subscription.version,
            condition: subscription.condition,
            sessionId: sessionId,
            isBatchingEnabled: subscription.isBatchingEnabled
        )
        activeSubscriptionsById[record.id] = subscription
        logger.info("✅ EventSub: subscribed to \(subscription.type)")
        return record
    }

    // MARK: - Receive Loop

    private func startReceiveLoop() {
        logger.info("🔵 EventSub: starting receive loop")
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let task = await self.webSocketTask else {
                    logger.info("🔵 EventSub: no WebSocket task, exiting receive loop")
                    return
                }
                do {
                    let message = try await task.receive()
                    await self.handleMessage(message)
                } catch {
                    logger.error("❌ EventSub: receive error: \(error.localizedDescription)")
                    if !Task.isCancelled {
                        await self.handleDisconnect()
                    }
                    return
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else {
            logger.warning("⚠️ EventSub: received non-string message")
            return
        }

        guard let envelope = try? JSONDecoder.twitch().decode(EventSubEnvelope.self, from: data) else {
            logger.warning("⚠️ EventSub: failed to decode message: \(text.prefix(200))")
            return
        }

        guard seenMessageIds.insert(envelope.metadata.messageId).inserted else {
            logger.info("EventSub: ignoring duplicate message \(envelope.metadata.messageId)")
            return
        }

        switch envelope.metadata.messageType {
        case "session_welcome":
            sessionId = envelope.payload.session?.id
            keepaliveTimeout = envelope.payload.session?.keepaliveTimeoutSeconds ?? 10
            logger.info("🟢 EventSub: session_welcome — id=\(self.sessionId ?? "nil"), keepalive=\(self.keepaliveTimeout)s")
            resetKeepaliveTimer()
            // Resume connect() — caller was waiting for session ID
            welcomeContinuation?.resume()
            welcomeContinuation = nil

        case "session_keepalive":
            resetKeepaliveTimer()

        case "notification":
            resetKeepaliveTimer()
            let subType = envelope.metadata.subscriptionType ?? "unknown"
            logger.info("📨 EventSub: notification — \(subType)")
            if let eventData = envelope.payload.event?.rawData {
                let event = parseEvent(type: subType, data: eventData)
                eventsContinuation.yield(event)
            } else {
                logger.warning("⚠️ EventSub: notification had no event data")
            }

        case "session_reconnect":
            if let newUrl = envelope.payload.session?.reconnectUrl,
               let url = URL(string: newUrl) {
                reconnectTask?.cancel()
                reconnectTask = Task { await reconnectTo(url) }
            }

        case "revocation":
            if let revocation = envelope.payload.subscription {
                eventsContinuation.yield(.revocation(revocation))
            }

        default:
            break
        }
    }

    private func parseEvent(type: String, data: Data) -> EventSubEvent {
        EventSubEvent.decode(type: type, payload: data)
    }

    // MARK: - Keepalive

    private func resetKeepaliveTimer() {
        keepaliveTask?.cancel()
        keepaliveTask = Task { [weak self] in
            guard let self else { return }
            let timeout = await self.keepaliveTimeout
            try? await Task.sleep(for: .seconds(timeout + 5)) // 5s grace period
            if !Task.isCancelled {
                await self.handleDisconnect()
            }
        }
    }

    // MARK: - Reconnection

    private func reconnectTo(_ url: URL) async {
        guard shouldReconnect else { return }
        let oldTask = webSocketTask
        let newTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask = newTask
        newTask.resume()
        receiveTask?.cancel()
        startReceiveLoop()
        oldTask?.cancel(with: .normalClosure, reason: nil)
    }

    private func handleDisconnect() {
        logger.warning("⚠️ EventSub: disconnected")
        receiveTask?.cancel()
        keepaliveTask?.cancel()
        webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
        webSocketTask = nil
        sessionId = nil
        activeSubscriptionsById.removeAll()

        // If connect() is still waiting for session_welcome, fail it
        welcomeContinuation?.resume(throwing: HelixError.networkError("WebSocket disconnected before session_welcome"))
        welcomeContinuation = nil

        guard shouldReconnect else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { await attemptReconnect() }
    }

    private func attemptReconnect() async {
        guard shouldReconnect else { return }
        let live = await isLive()
        let maxAttempts = live ? Int.max : 5
        let baseDelay: Double = live ? 0.5 : 1.0
        let maxDelay: Double = live ? 5.0 : 30.0

        reconnectAttempts += 1
        guard reconnectAttempts <= maxAttempts else { return }

        let delay = min(baseDelay * pow(2.0, Double(reconnectAttempts - 1)), maxDelay)
        try? await Task.sleep(for: .seconds(delay))
        guard shouldReconnect, !Task.isCancelled else { return }

        do {
            try await openConnection(to: Self.websocketURL, resetReconnectAttempts: false, timeout: .seconds(15))
            try await resubscribeAll()
        } catch {
            await attemptReconnect()
        }
    }

    private func waitForWelcome() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            welcomeContinuation?.resume(throwing: HelixError.networkError("Superseded EventSub connection attempt"))
            welcomeContinuation = continuation
        }
    }

    private func cleanupFailedConnection(task: URLSessionWebSocketTask, error: Error) {
        receiveTask?.cancel()
        receiveTask = nil
        keepaliveTask?.cancel()
        keepaliveTask = nil
        task.cancel(with: .abnormalClosure, reason: nil)
        if webSocketTask === task {
            webSocketTask = nil
        }
        sessionId = nil
        welcomeContinuation?.resume(throwing: error)
        welcomeContinuation = nil
    }

    private func resubscribeAll() async throws {
        activeSubscriptionsById.removeAll()
        for subscription in desiredSubscriptions {
            _ = try await createSubscription(subscription)
        }
    }
}
