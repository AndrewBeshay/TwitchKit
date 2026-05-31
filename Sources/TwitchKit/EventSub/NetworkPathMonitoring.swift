import Foundation
import Network

/// Binary network-reachability signal. We only care whether a usable path
/// exists — not the interface type (Wi-Fi vs cellular is irrelevant to EventSub
/// reconnect; we never proactively drop a live socket on an interface change).
public enum NetworkPathStatus: Sendable {
    case satisfied
    case unsatisfied
}

/// Abstracts `NWPathMonitor` so the reconnect logic can be unit-tested with a
/// scripted sequence of path changes.
public protocol NetworkPathMonitoring: Sendable {
    /// Emits the current status promptly after ``start()``, then on every change.
    /// Single-consumer (matches ``EventSubClient/events``).
    var pathUpdates: AsyncStream<NetworkPathStatus> { get }
    func start()
    func cancel()
}

/// Production ``NetworkPathMonitoring`` backed by `NWPathMonitor`.
public final class NWPathNetworkMonitor: NetworkPathMonitoring, @unchecked Sendable {
    public let pathUpdates: AsyncStream<NetworkPathStatus>
    private let continuation: AsyncStream<NetworkPathStatus>.Continuation
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.twitchkit.networkpath")

    public init() {
        (pathUpdates, continuation) = AsyncStream.makeStream(of: NetworkPathStatus.self)
        monitor.pathUpdateHandler = { [continuation] path in
            continuation.yield(path.status == .satisfied ? .satisfied : .unsatisfied)
        }
    }

    public func start() { monitor.start(queue: queue) }

    public func cancel() {
        monitor.cancel()
        continuation.finish()
    }
}
