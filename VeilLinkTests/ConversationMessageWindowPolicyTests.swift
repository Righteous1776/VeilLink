import XCTest
@testable import VeilLink

final class ConversationMessageWindowPolicyTests: XCTestCase {
    func testResolvedPaginationLimitIsRetainedAfterFetchingOlderPages() {
        XCTAssertEqual(
            ConversationMessageWindowPolicy.committedLimit(
                currentLimit: 120,
                resolvedLimit: 240,
                loadAll: false
            ),
            240
        )
    }

    func testPaginationRefreshDoesNotReduceAnAlreadyExpandedLimit() {
        XCTAssertEqual(
            ConversationMessageWindowPolicy.committedLimit(
                currentLimit: 360,
                resolvedLimit: 240,
                loadAll: false
            ),
            360
        )
    }

    func testLoadAllRefreshDoesNotChangeThePagedWindowLimit() {
        XCTAssertEqual(
            ConversationMessageWindowPolicy.committedLimit(
                currentLimit: 240,
                resolvedLimit: 0,
                loadAll: true
            ),
            240
        )
    }
}
