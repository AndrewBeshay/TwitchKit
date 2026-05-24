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
    private var keepaliveTimeout: Int = 10
    private var reconnectAttempts: Int = 0
    private var desiredSubscriptions: Set<EventSubSubscription> = []
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

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.waitForWelcome() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw HelixError.networkError("Timed out waiting for EventSub session_welcome")
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }

    public func disconnect() async {
        logger.info("🔌 EventSub: disconnecting")
        receiveTask?.cancel()
        receiveTask = nil
        keepaliveTask?.cancel()
        keepaliveTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        sessionId = nil
        welcomeContinuation?.resume(throwing: HelixError.networkError("EventSub disconnected"))
        welcomeContinuation = nil
    }

    public func subscribe(_ subscription: EventSubSubscription) async throws {
        desiredSubscriptions.insert(subscription)
        try await createSubscription(subscription)
    }

    public func subscribe(type: String, version: String, condition: [String: String]) async throws {
        try await subscribe(EventSubSubscription(type: type, version: version, condition: condition))
    }

    private func createSubscription(_ subscription: EventSubSubscription) async throws {
        guard let sessionId else {
            logger.error("❌ EventSub: no session ID — can't subscribe")
            throw HelixError.badRequest("No EventSub session — call connect() first")
        }
        logger.info("📡 EventSub: subscribing to \(subscription.type) v\(subscription.version) with session \(sessionId)")
        try await api.createEventSubSubscription(
            type: subscription.type,
            version: subscription.version,
            condition: subscription.condition,
            sessionId: sessionId
        )
        logger.info("✅ EventSub: subscribed to \(subscription.type)")
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
                Task { await reconnectTo(url) }
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
        let decoder = JSONDecoder.twitch()
        switch type {
        case "channel.chat.message":
            if let msg = try? decoder.decode(ChatMessage.self, from: data) {
                return .chatMessage(msg)
            }
        case "channel.follow":
            if let follow = try? decoder.decode(TwitchFollow.self, from: data) {
                return .follow(follow)
            }
        case "channel.subscribe":
            if let sub = try? decoder.decode(TwitchSubscription.self, from: data) {
                return .subscription(sub)
            }
        default:
            break
        }
        return .unknown(type: type, payload: data)
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

        // If connect() is still waiting for session_welcome, fail it
        welcomeContinuation?.resume(throwing: HelixError.networkError("WebSocket disconnected before session_welcome"))
        welcomeContinuation = nil

        Task { await attemptReconnect() }
    }

    private func attemptReconnect() async {
        let live = await isLive()
        let maxAttempts = live ? Int.max : 5
        let baseDelay: Double = live ? 0.5 : 1.0
        let maxDelay: Double = live ? 5.0 : 30.0

        reconnectAttempts += 1
        guard reconnectAttempts <= maxAttempts else { return }

        let delay = min(baseDelay * pow(2.0, Double(reconnectAttempts - 1)), maxDelay)
        try? await Task.sleep(for: .seconds(delay))

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

    private func resubscribeAll() async throws {
        for subscription in desiredSubscriptions {
            try await createSubscription(subscription)
        }
    }
}
