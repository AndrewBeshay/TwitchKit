import Foundation
import os

private let logger = Logger(subsystem: "com.twitchkit", category: "eventsub")

public actor EventSubClient {
    /// Stream of parsed events — initialized once, consumers iterate without actor hop.
    public nonisolated let events: AsyncStream<EventSubEvent>
    private let eventsContinuation: AsyncStream<EventSubEvent>.Continuation

    /// Stream of connection-state transitions, suitable for driving UI such as a
    /// "Reconnecting…" indicator.
    ///
    /// Single-consumer (like ``events``): exactly one iterator consumes this stream,
    /// and there is no value replay for late subscribers. Begin iterating
    /// *before/around* ``connect()`` so you observe the initial
    /// `.connecting`/`.connected` transitions.
    public nonisolated let connectionState: AsyncStream<ConnectionState>
    private let connectionStateContinuation: AsyncStream<ConnectionState>.Continuation
    private var lastEmittedState: ConnectionState?

    private let api: HelixClient
    private let isLive: @Sendable () async -> Bool
    private let pathMonitor: NetworkPathMonitoring
    private var pathMonitorTask: Task<Void, Never>?
    private var isNetworkAvailable = true   // optimistic until told otherwise

    private var webSocketTask: URLSessionWebSocketTask?
    private var sessionId: String?
    private var receiveTasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var keepaliveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var keepaliveDeadline: ContinuousClock.Instant?
    private var keepaliveTimeout: Int = 10
    private var reconnectAttempts: Int = 0
    private var shouldReconnect = false
    private var isConnecting = false
    private var desiredSubscriptions: Set<EventSubSubscription> = []
    private var desiredSubscriptionsById: [String: EventSubSubscription] = [:]
    private var activeSubscriptionsById: [String: EventSubSubscription] = [:]
    private var seenMessageIds: Set<String> = []
    private var seenMessageIdOrder: [String] = []

    private static let websocketURL = URL(string: "wss://eventsub.wss.twitch.tv/ws")!
    private static let maxSeenMessageIds = 4_096

    public init(
        api: HelixClient,
        isLive: @escaping @Sendable () async -> Bool,
        pathMonitor: NetworkPathMonitoring = NWPathNetworkMonitor(),
        eventBufferingPolicy: AsyncStream<EventSubEvent>.Continuation.BufferingPolicy = .bufferingNewest(1_000)
    ) {
        self.api = api
        self.isLive = isLive
        self.pathMonitor = pathMonitor
        (events, eventsContinuation) = AsyncStream.makeStream(
            of: EventSubEvent.self,
            bufferingPolicy: eventBufferingPolicy
        )
        (connectionState, connectionStateContinuation) = AsyncStream.makeStream(of: ConnectionState.self)
    }

    deinit {
        reconnectTask?.cancel()
        pathMonitorTask?.cancel()
        pathMonitor.cancel()
        for task in receiveTasks.values {
            task.cancel()
        }
        keepaliveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        welcomeContinuation?.resume(throwing: HelixError.networkError("EventSub client deallocated"))
        eventsContinuation.finish()
        connectionStateContinuation.finish()
    }

    // MARK: - Public

    /// Continuation used to make connect() wait for session_welcome before returning.
    private var welcomeContinuation: CheckedContinuation<Void, Error>?

    /// Test seam: replaces the socket-opening body of a connect() attempt
    /// so the connect-coalescing logic can be exercised without a real
    /// WebSocket (there is no socket seam in this client — see
    /// EventSubConnectionStateTests). Always nil in production.
    private var connectBodyForTesting: (@Sendable () async throws -> Void)?

    /// Internal, for tests only — see `connectBodyForTesting`.
    func setConnectBodyForTesting(_ body: @escaping @Sendable () async throws -> Void) {
        connectBodyForTesting = body
    }

    /// Internal, for tests only — true while a connect() attempt is in flight.
    var isConnectingForTesting: Bool { isConnecting }

    /// The in-flight connect() attempt, if any. One shared client serves
    /// every consumer on an account (e.g. one chat session per open
    /// channel), so a second connect() landing while the first is
    /// mid-handshake is normal operation — those callers await this task
    /// and share its outcome instead of erroring.
    private var inFlightConnect: Task<Void, Error>?

    public func connect(timeout: Duration = .seconds(15)) async throws {
        if sessionId != nil {
            return
        }
        // Coalesce concurrent callers onto the in-flight attempt: they
        // succeed together or fail with the same underlying error.
        if let inFlightConnect {
            try await inFlightConnect.value
            return
        }

        startConnectionLifecycle()
        isConnecting = true
        // Unstructured Task (inheriting this actor's isolation) so the
        // attempt's lifetime is owned by the client, not the first
        // caller — a cancelled initiator must not tear the handshake out
        // from under the coalesced waiters.
        let attempt = Task {
            if let connectBodyForTesting {
                try await connectBodyForTesting()
            } else {
                try await openConnection(to: Self.websocketURL, resetReconnectAttempts: true, timeout: timeout)
            }
        }
        inFlightConnect = attempt
        defer {
            inFlightConnect = nil
            isConnecting = false
        }
        try await attempt.value
    }

    /// Marks the client as intending to be connected and begins path monitoring,
    /// emitting `.connecting`. `connect()` calls this before opening the socket;
    /// it is the seam that ties network monitoring to an intended-connected lifecycle.
    func startConnectionLifecycle() {
        shouldReconnect = true
        emit(.connecting)
        startPathMonitorIfNeeded()
    }

    // MARK: - Connection State

    /// Emits a connection state, deduping so rapid flaps don't spam identical states.
    private func emit(_ state: ConnectionState) {
        guard state != lastEmittedState else { return }
        lastEmittedState = state
        connectionStateContinuation.yield(state)
    }

    // MARK: - Network Path Monitoring

    private func startPathMonitorIfNeeded() {
        guard pathMonitorTask == nil else { return }
        pathMonitor.start()
        pathMonitorTask = Task { [weak self] in
            guard let self else { return }
            for await status in self.pathMonitor.pathUpdates {
                await self.handlePathStatus(status)
            }
        }
    }

    private func handlePathStatus(_ status: NetworkPathStatus) {
        switch status {
        case .unsatisfied:
            isNetworkAvailable = false
            // Stop hammering a dead network: cancel the in-flight backoff sleep.
            reconnectTask?.cancel()
            reconnectTask = nil
            if sessionId == nil { emit(.waitingForNetwork) }
        case .satisfied:
            let wasOffline = !isNetworkAvailable
            isNetworkAvailable = true
            // Reconnect immediately if we *want* to be connected but aren't.
            if wasOffline, shouldReconnect, sessionId == nil {
                reconnectAttempts = 0           // reset backoff — restore is "attempt 1"
                reconnectTask?.cancel()
                emit(.reconnecting)
                reconnectTask = Task { await attemptReconnect() }
            }
        }
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
        startReceiveLoop(for: task)

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
        pathMonitorTask?.cancel()
        pathMonitorTask = nil
        pathMonitor.cancel()
        emit(.disconnected)
        cancelReceiveTasks()
        keepaliveTask?.cancel()
        keepaliveTask = nil
        keepaliveDeadline = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        sessionId = nil
        activeSubscriptionsById.removeAll()
        clearSeenMessageIds()
        welcomeContinuation?.resume(throwing: HelixError.networkError("EventSub disconnected"))
        welcomeContinuation = nil
    }

    @discardableResult
    public func subscribe(_ subscription: EventSubSubscription) async throws -> EventSubSubscriptionRecord {
        let record = try await createSubscription(subscription)
        desiredSubscriptions.insert(subscription)
        desiredSubscriptionsById[record.id] = subscription
        return record
    }

    @discardableResult
    public func subscribe(type: String, version: String, condition: [String: String]) async throws -> EventSubSubscriptionRecord {
        try await subscribe(EventSubSubscription(type: type, version: version, condition: condition))
    }

    public func unsubscribe(id: String) async throws {
        let localSubscription = activeSubscriptionsById[id] ?? desiredSubscriptionsById[id]

        do {
            try await api.deleteEventSubSubscription(id: id)
        } catch HelixError.notFound where localSubscription != nil {
            // The remote subscription can already be gone after a lost WebSocket.
        }

        activeSubscriptionsById.removeValue(forKey: id)
        desiredSubscriptionsById.removeValue(forKey: id)
        if let localSubscription {
            desiredSubscriptions.remove(localSubscription)
            desiredSubscriptionsById = desiredSubscriptionsById.filter { $0.value != localSubscription }
            activeSubscriptionsById = activeSubscriptionsById.filter { $0.value != localSubscription }
        }
    }

    public func unsubscribe(_ subscription: EventSubSubscription) async throws {
        if let id = activeSubscriptionsById.first(where: { $0.value == subscription })?.key
            ?? desiredSubscriptionsById.first(where: { $0.value == subscription })?.key {
            try await unsubscribe(id: id)
            return
        }

        desiredSubscriptions.remove(subscription)
        desiredSubscriptionsById = desiredSubscriptionsById.filter { $0.value != subscription }
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

    private func startReceiveLoop(for task: URLSessionWebSocketTask) {
        logger.info("🔵 EventSub: starting receive loop")
        let taskId = ObjectIdentifier(task)
        receiveTasks[taskId]?.cancel()
        receiveTasks[taskId] = Task { [weak self, weak task] in
            guard let self, let task else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    await self.handleMessage(message, from: task)
                } catch {
                    logger.error("❌ EventSub: receive error: \(error.localizedDescription)")
                    await self.receiveLoopDidEnd(for: task, error: error)
                    return
                }
            }
        }
    }

    private func receiveLoopDidEnd(for task: URLSessionWebSocketTask, error: Error) {
        receiveTasks.removeValue(forKey: ObjectIdentifier(task))
        guard !Task.isCancelled else { return }
        guard webSocketTask === task else { return }
        handleDisconnect()
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message, from task: URLSessionWebSocketTask) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8) else {
            logger.warning("⚠️ EventSub: received non-string message")
            return
        }

        let envelope: EventSubEnvelope
        do {
            envelope = try JSONDecoder.twitch().decode(EventSubEnvelope.self, from: data)
        } catch {
            logger.warning("⚠️ EventSub: failed to decode message: \(eventSubDecodingErrorDescription(error), privacy: .public); JSON prefix: \(text.prefix(200), privacy: .public)")
            return
        }

        guard rememberMessageId(envelope.metadata.messageId) else {
            logger.debug("EventSub: ignoring duplicate message \(envelope.metadata.messageId)")
            return
        }

        switch envelope.metadata.messageType {
        case "session_welcome":
            sessionId = envelope.payload.session?.id
            keepaliveTimeout = envelope.payload.session?.keepaliveTimeoutSeconds ?? 10
            logger.info("🟢 EventSub: session_welcome — id=\(self.sessionId ?? "nil"), keepalive=\(self.keepaliveTimeout)s")
            updateKeepaliveDeadline()
            emit(.connected)
            // Resume connect() — caller was waiting for session ID
            welcomeContinuation?.resume()
            welcomeContinuation = nil

        case "session_keepalive":
            updateKeepaliveDeadline()

        case "notification":
            updateKeepaliveDeadline()
            let subType = envelope.metadata.subscriptionType ?? "unknown"
            logger.debug("EventSub notification: \(subType)")
            let event = parseNotificationEvent(type: subType, envelopeData: data)
            eventsContinuation.yield(event)

        case "session_reconnect":
            if webSocketTask === task,
               let newUrl = envelope.payload.session?.reconnectUrl,
               let url = URL(string: newUrl) {
                reconnectTask?.cancel()
                reconnectTask = Task { await reconnectTo(url, replacing: task) }
            }

        case "revocation":
            if let revocation = envelope.payload.subscription {
                eventsContinuation.yield(.revocation(revocation))
            }

        default:
            break
        }
    }

    private func parseNotificationEvent(type: String, envelopeData: Data) -> EventSubEvent {
        EventSubEvent.decodeNotification(type: type, envelope: envelopeData)
    }

    // MARK: - Keepalive

    private func updateKeepaliveDeadline() {
        keepaliveDeadline = ContinuousClock().now.advanced(by: .seconds(keepaliveTimeout + 5))
        guard keepaliveTask == nil else { return }

        keepaliveTask = Task { [weak self] in
            guard let self else { return }
            await self.runKeepaliveWatchdog()
        }
    }

    private func runKeepaliveWatchdog() async {
        while !Task.isCancelled {
            guard let deadline = keepaliveDeadline else {
                keepaliveTask = nil
                return
            }

            let now = ContinuousClock().now
            if now < deadline {
                try? await ContinuousClock().sleep(until: deadline)
                continue
            }

            keepaliveTask = nil
            handleDisconnect()
            return
        }
    }

    // MARK: - Reconnection

    private func reconnectTo(_ url: URL, replacing oldTask: URLSessionWebSocketTask) async {
        guard shouldReconnect, webSocketTask === oldTask else { return }
        let newTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask = newTask
        newTask.resume()
        startReceiveLoop(for: newTask)

        do {
            try await waitForWelcome(timeout: .seconds(15))
            oldTask.cancel(with: .normalClosure, reason: nil)
            cancelReceiveTask(for: oldTask)
        } catch {
            newTask.cancel(with: .abnormalClosure, reason: nil)
            cancelReceiveTask(for: newTask)
            if webSocketTask === newTask {
                webSocketTask = oldTask
            }
            handleDisconnect()
        }
    }

    private func handleDisconnect() {
        logger.warning("⚠️ EventSub: disconnected")
        cancelReceiveTasks()
        keepaliveTask?.cancel()
        keepaliveTask = nil
        keepaliveDeadline = nil
        webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
        webSocketTask = nil
        sessionId = nil
        activeSubscriptionsById.removeAll()
        clearSeenMessageIds()

        // If connect() is still waiting for session_welcome, fail it
        welcomeContinuation?.resume(throwing: HelixError.networkError("WebSocket disconnected before session_welcome"))
        welcomeContinuation = nil

        guard shouldReconnect else { return }
        if isNetworkAvailable {
            emit(.reconnecting)
            reconnectTask?.cancel()
            reconnectTask = Task { await attemptReconnect() }
        } else {
            emit(.waitingForNetwork)   // parked; handlePathStatus(.satisfied) will resume
        }
    }

    private func attemptReconnect() async {
        guard shouldReconnect else { return }
        guard isNetworkAvailable else { emit(.waitingForNetwork); return }  // park

        let live = await isLive()
        reconnectAttempts += 1
        let decision = reconnectDecision(
            networkAvailable: isNetworkAvailable,
            shouldReconnect: shouldReconnect,
            isLive: live,
            attempt: reconnectAttempts
        )
        guard case .attempt(let delay) = decision.action else { return }

        try? await Task.sleep(for: delay)
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

    private func waitForWelcome(timeout: Duration) async throws {
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

    private func cleanupFailedConnection(task: URLSessionWebSocketTask, error: Error) {
        cancelReceiveTasks()
        keepaliveTask?.cancel()
        keepaliveTask = nil
        keepaliveDeadline = nil
        task.cancel(with: .abnormalClosure, reason: nil)
        if webSocketTask === task {
            webSocketTask = nil
        }
        sessionId = nil
        clearSeenMessageIds()
        welcomeContinuation?.resume(throwing: error)
        welcomeContinuation = nil
    }

    private func rememberMessageId(_ messageId: String) -> Bool {
        let insertResult = seenMessageIds.insert(messageId)
        guard insertResult.inserted else {
            return false
        }

        seenMessageIdOrder.append(messageId)
        let overflow = seenMessageIdOrder.count - Self.maxSeenMessageIds
        if overflow > 0 {
            for staleMessageId in seenMessageIdOrder.prefix(overflow) {
                seenMessageIds.remove(staleMessageId)
            }
            seenMessageIdOrder.removeFirst(overflow)
        }
        return true
    }

    private func clearSeenMessageIds() {
        seenMessageIds.removeAll(keepingCapacity: true)
        seenMessageIdOrder.removeAll(keepingCapacity: true)
    }

    private func resubscribeAll() async throws {
        activeSubscriptionsById.removeAll()
        for subscription in desiredSubscriptions {
            let record = try await createSubscription(subscription)
            desiredSubscriptionsById[record.id] = subscription
        }
    }

    private func cancelReceiveTask(for task: URLSessionWebSocketTask) {
        receiveTasks.removeValue(forKey: ObjectIdentifier(task))?.cancel()
    }

    private func cancelReceiveTasks() {
        for task in receiveTasks.values {
            task.cancel()
        }
        receiveTasks.removeAll()
    }
}
