import Foundation

/// The outcome of evaluating whether EventSub should retry its WebSocket connection.
///
/// This is the pure core of the reconnect backoff ladder, extracted from
/// ``EventSubClient`` so the gating + delay math can be unit-tested without
/// sockets, sleeps, or the network.
struct ReconnectDecision: Equatable {
    enum Action: Equatable {
        /// Stop retrying for now — either we don't want to reconnect, the network
        /// path is unsatisfied, or the non-live ladder has exhausted its attempts.
        case park
        /// Sleep `delay`, then attempt a fresh connection.
        case attempt(delay: Duration)
    }

    let action: Action
}

/// Decides whether to attempt a reconnect (and after what backoff delay) or to park.
///
/// - Parameters:
///   - networkAvailable: Whether the OS reports a usable network path.
///   - shouldReconnect: Whether the client still intends to be connected.
///   - isLive: Tunes the ladder. A live channel retries forever with a short,
///     5s-capped backoff; a non-live channel gives up after 5 attempts with a
///     longer, 30s-capped backoff.
///   - attempt: The 1-based attempt number being evaluated.
/// - Returns: ``ReconnectDecision/Action/park`` to stop, or
///   ``ReconnectDecision/Action/attempt(delay:)`` with the backoff delay.
func reconnectDecision(
    networkAvailable: Bool,
    shouldReconnect: Bool,
    isLive: Bool,
    attempt: Int
) -> ReconnectDecision {
    guard shouldReconnect else { return ReconnectDecision(action: .park) }
    guard networkAvailable else { return ReconnectDecision(action: .park) }

    let maxAttempts = isLive ? Int.max : 5
    guard attempt <= maxAttempts else { return ReconnectDecision(action: .park) }

    let baseDelay: Double = isLive ? 0.5 : 1.0
    let maxDelay: Double = isLive ? 5.0 : 30.0
    let seconds = min(baseDelay * pow(2.0, Double(attempt - 1)), maxDelay)
    return ReconnectDecision(action: .attempt(delay: .seconds(seconds)))
}
