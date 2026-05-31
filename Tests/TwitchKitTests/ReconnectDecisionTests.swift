import XCTest
@testable import TwitchKit

/// Tests for the pure reconnect-decision helper that drives EventSub's backoff ladder.
///
/// The decision is a pure function so the ladder math + give-up/park gating can be
/// verified deterministically, with no sockets, sleeps, or network involved.
final class ReconnectDecisionTests: XCTestCase {

    func test_offlineAlwaysParks() {
        let decision = reconnectDecision(
            networkAvailable: false, shouldReconnect: true, isLive: true, attempt: 1
        )
        XCTAssertEqual(decision.action, .park)
    }

    func test_notWantingToReconnectParks() {
        let decision = reconnectDecision(
            networkAvailable: true, shouldReconnect: false, isLive: true, attempt: 1
        )
        XCTAssertEqual(decision.action, .park)
    }

    func test_liveUsesHalfSecondBaseDelay() {
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, isLive: true, attempt: 1).action,
            .attempt(delay: .seconds(0.5))
        )
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, isLive: true, attempt: 2).action,
            .attempt(delay: .seconds(1.0))
        )
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, isLive: true, attempt: 4).action,
            .attempt(delay: .seconds(4.0))
        )
    }

    func test_liveCapsDelayAtFiveSeconds() {
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, isLive: true, attempt: 5).action,
            .attempt(delay: .seconds(5.0))
        )
    }

    func test_liveNeverGivesUp() {
        // isLive == true => unbounded attempts, always capped delay, never .park.
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, isLive: true, attempt: 1_000).action,
            .attempt(delay: .seconds(5.0))
        )
    }

    func test_notLiveUsesOneSecondBaseDelayDoublingEachAttempt() {
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, isLive: false, attempt: 1).action,
            .attempt(delay: .seconds(1.0))
        )
        // attempt 5 is the last allowed for a non-live channel: 1 * 2^4 = 16s (under the 30s cap).
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, isLive: false, attempt: 5).action,
            .attempt(delay: .seconds(16.0))
        )
    }

    func test_notLiveGivesUpAfterFiveAttempts() {
        // maxAttempts == 5 for a non-live channel, so attempt 6 onward parks (gives up).
        XCTAssertEqual(
            reconnectDecision(networkAvailable: true, shouldReconnect: true, isLive: false, attempt: 6).action,
            .park
        )
    }
}
