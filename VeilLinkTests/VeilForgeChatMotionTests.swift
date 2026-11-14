import XCTest
@testable import VeilLink

final class VeilForgeChatMotionTests: XCTestCase {
    func testRailDetentsFollowRecordedDeliveryState() {
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.position(.queued), 0)
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.position(.sending), 1)
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.position(.delivered), 2)
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.position(.paused), 0)
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.position(.cancelled), 0)
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.position(.failed), 0)
    }
    func testStageLabelsNeverClaimFictionalProgress() {
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.code(.queued), "QUEUE")
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.code(.sending), "TX")
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.code(.delivered), "ACK")
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.code(.paused), "HOLD")
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.code(.cancelled), "STOP")
        XCTAssertEqual(VeilForgeChatDeliveryPolicy.code(.failed), "ERR")
    }
}
