import XCTest
@testable import VeilLink

final class LlamaNativeLifecycleTests: XCTestCase {
    func testCannotEnterSecondGenerationAcrossActorSuspension() {
        var fence = LlamaNativeLifecycle()
        XCTAssertTrue(fence.beginGeneration())
        XCTAssertFalse(fence.beginGeneration())
        XCTAssertEqual(fence.finishGeneration(), .noChange)
        XCTAssertTrue(fence.beginGeneration())
    }

    func testTrimRequestedDuringGenerationIsDeferred() {
        var fence = LlamaNativeLifecycle()
        XCTAssertTrue(fence.beginGeneration())
        XCTAssertFalse(fence.requestTrim())
        XCTAssertTrue(fence.trimPending)
        XCTAssertEqual(fence.finishGeneration(), .trim)
        XCTAssertFalse(fence.generating)
        XCTAssertFalse(fence.trimPending)
    }

    func testShutdownWinsOverPendingTrimAndPreventsNewEntry() {
        var fence = LlamaNativeLifecycle()
        XCTAssertTrue(fence.beginGeneration())
        XCTAssertFalse(fence.requestTrim())
        XCTAssertFalse(fence.requestShutdown())
        XCTAssertTrue(fence.shutdownPending)
        XCTAssertFalse(fence.beginGeneration())
        XCTAssertEqual(fence.finishGeneration(), .shutdown)
        XCTAssertFalse(fence.shutdownPending)
        XCTAssertFalse(fence.trimPending)
    }

    func testIdleShutdownCanReleaseImmediately() {
        var fence = LlamaNativeLifecycle()
        XCTAssertTrue(fence.requestShutdown())
        XCTAssertFalse(fence.generating)
        XCTAssertTrue(fence.requestTrim())
    }
}
