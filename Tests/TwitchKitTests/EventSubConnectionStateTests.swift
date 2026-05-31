import XCTest
import Foundation
@testable import TwitchKit

/// Tests that network-path transitions drive the public `connectionState` stream.
///
/// There is no socket seam in `EventSubClient`, so these tests exercise the
/// network-transition *logic* deterministically via a scripted path monitor and
/// stop at `.reconnecting` — the first post-restore emission, which is the
/// behavior this feature owns.
final class EventSubConnectionStateTests: XCTestCase {

    func test_pathTransitionsDriveConnectionStateSequence() async throws {
        let mock = MockNetworkPathMonitor()
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: mock)

        // Single-consumer: start iterating before driving transitions. The stream
        // buffers, so emissions made before the first `await next` are preserved.
        let collector = Task { () -> [ConnectionState] in
            var observed: [ConnectionState] = []
            for await state in client.connectionState {
                observed.append(state)
                if state == .reconnecting { break }
            }
            return observed
        }

        // Begin the path-aware lifecycle without opening a real socket.
        await client.startConnectionLifecycle()  // → .connecting

        mock.send(.satisfied)                     // already optimistic → no change
        mock.send(.unsatisfied)                   // → .waitingForNetwork
        mock.send(.satisfied)                     // network restored → .reconnecting

        let observed = await collector.value
        await client.disconnect()                 // stops the parked reconnect loop

        XCTAssertEqual(observed, [.connecting, .waitingForNetwork, .reconnecting])
    }

    func test_disconnectEmitsDisconnected() async throws {
        let mock = MockNetworkPathMonitor()
        let client = EventSubClient(api: makeDummyAPI(), isLive: { false }, pathMonitor: mock)

        let collector = Task { () -> [ConnectionState] in
            var observed: [ConnectionState] = []
            for await state in client.connectionState {
                observed.append(state)
                if state == .disconnected { break }
            }
            return observed
        }

        await client.startConnectionLifecycle()  // → .connecting
        await client.disconnect()                 // → .disconnected

        let observed = await collector.value
        XCTAssertEqual(observed, [.connecting, .disconnected])
        XCTAssertTrue(mock.didCancel)
    }
}

// MARK: - Test doubles

/// A `NetworkPathMonitoring` whose updates are driven by the test.
final class MockNetworkPathMonitor: NetworkPathMonitoring, @unchecked Sendable {
    let pathUpdates: AsyncStream<NetworkPathStatus>
    private let continuation: AsyncStream<NetworkPathStatus>.Continuation
    private(set) var didStart = false
    private(set) var didCancel = false

    init() {
        (pathUpdates, continuation) = AsyncStream.makeStream(of: NetworkPathStatus.self)
    }

    func start() { didStart = true }
    func cancel() { didCancel = true; continuation.finish() }

    /// Drives a scripted path-status change.
    func send(_ status: NetworkPathStatus) { continuation.yield(status) }
}

private func makeDummyAPI() -> HelixClient {
    HelixClient(
        auth: TwitchAuth(
            oauthClient: TwitchOAuthClient(clientId: "client-id", clientSecret: nil, httpClient: URLSessionHTTPClient()),
            tokenStore: InMemoryTokenStore()
        ),
        clientId: "client-id"
    )
}
