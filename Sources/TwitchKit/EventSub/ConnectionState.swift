import Foundation

/// Observable connection state of an ``EventSubClient``, suitable for driving UI
/// such as a "Reconnecting…" indicator.
public enum ConnectionState: Sendable, Equatable {
    /// Initial `connect()` in progress, no session yet.
    case connecting
    /// `session_welcome` received; live.
    case connected
    /// Socket dropped, network is available, retrying.
    case reconnecting
    /// Socket dropped, network path is unsatisfied — parked until the path returns.
    case waitingForNetwork
    /// Intentional `disconnect()` — not coming back on its own.
    case disconnected
}
