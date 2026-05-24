import XCTest
@testable import TwitchKit

final class TwitchScopeTests: XCTestCase {
    func test_allKnownScopeFamiliesAreRepresented() {
        let scopes = Set(TwitchScope.allCases.map(\.rawValue))

        XCTAssertTrue(scopes.contains("analytics:read:extensions"))
        XCTAssertTrue(scopes.contains("channel:manage:polls"))
        XCTAssertTrue(scopes.contains("moderator:manage:warnings"))
        XCTAssertTrue(scopes.contains("user:read:whispers"))
        XCTAssertTrue(scopes.contains("chat:edit"))
        XCTAssertTrue(scopes.contains("whispers:read"))
    }
}
