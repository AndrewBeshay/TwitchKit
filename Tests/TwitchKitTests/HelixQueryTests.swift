import Foundation
import XCTest
@testable import TwitchKit

final class HelixQueryTests: XCTestCase {
    func test_itemsBuildsRepeatedQueryParameters() {
        let items = HelixQuery.items("id", values: ["1", "2", "3"])

        XCTAssertEqual(items.map(\.name), ["id", "id", "id"])
        XCTAssertEqual(items.map(\.value), ["1", "2", "3"])
    }

    func test_appendSkipsNilOptionalQueryParameter() {
        var items: [URLQueryItem] = []

        HelixQuery.append(HelixQuery.item("user_id", nil), to: &items)
        HelixQuery.append(HelixQuery.item("broadcaster_id", "123"), to: &items)

        XCTAssertEqual(items, [URLQueryItem(name: "broadcaster_id", value: "123")])
    }

    func test_appendPaginationRejectsInvalidPageSize() throws {
        var items: [URLQueryItem] = []

        XCTAssertThrowsError(try HelixQuery.appendPagination(to: &items, first: 101, after: nil)) { error in
            guard case HelixError.badRequest(let apiError) = error else {
                return XCTFail("Expected badRequest, got \(error)")
            }
            XCTAssertEqual(apiError.message, "Page size must be between 1 and 100")
        }
    }
}
