import XCTest
@testable import VeilLink

final class VoicePTTResilienceR11Tests: XCTestCase {
    func testJitterBufferReordersFramesBeforePlayout() {
        var buffer = VeilPTTJitterBuffer(frameBytes: 4, targetDepth: 3, maximumBufferedFrames: 6, missingFramePatienceTicks: 1)
        XCTAssertTrue(buffer.push(index: 0, bytes: Data([0,0,0,0])))
        XCTAssertTrue(buffer.push(index: 2, bytes: Data([2,2,2,2])))
        XCTAssertTrue(buffer.push(index: 1, bytes: Data([1,1,1,1])))
        XCTAssertEqual(buffer.nextForPlayout(), .frame(Data([0,0,0,0])))
        XCTAssertEqual(buffer.nextForPlayout(), .frame(Data([1,1,1,1])))
        XCTAssertEqual(buffer.nextForPlayout(), .frame(Data([2,2,2,2])))
    }

    func testJitterBufferConcealsMissingFrameWithoutStalling() {
        var buffer = VeilPTTJitterBuffer(frameBytes: 4, targetDepth: 2, maximumBufferedFrames: 6, missingFramePatienceTicks: 0)
        XCTAssertTrue(buffer.push(index: 0, bytes: Data([0,0,0,0])))
        XCTAssertTrue(buffer.push(index: 2, bytes: Data([2,2,2,2])))
        XCTAssertEqual(buffer.nextForPlayout(), .frame(Data([0,0,0,0])))
        XCTAssertEqual(buffer.nextForPlayout(), .conceal(frameBytes: 4))
        XCTAssertEqual(buffer.nextForPlayout(), .frame(Data([2,2,2,2])))
        XCTAssertEqual(buffer.snapshot.concealedFrames, 1)
    }

    func testEndedTalkDrainsBufferedFrames() {
        var buffer = VeilPTTJitterBuffer(frameBytes: 4, targetDepth: 3, maximumBufferedFrames: 6, missingFramePatienceTicks: 1)
        XCTAssertTrue(buffer.push(index: 0, bytes: Data([1,1,1,1])))
        buffer.markEnded()
        XCTAssertEqual(buffer.nextForPlayout(), .frame(Data([1,1,1,1])))
        XCTAssertEqual(buffer.nextForPlayout(), .finished)
    }

    func testLegacyAudioTuningUsesDeeperBufferAndLowerUIRate() {
        let legacy = VeilRealtimeAudioTuning.resolved(performanceLabel: "LEGACY-COMPACT")
        let modern = VeilRealtimeAudioTuning.resolved(performanceLabel: "13PRO-HIGH")
        XCTAssertGreaterThan(legacy.targetJitterFrames, modern.targetJitterFrames)
        XCTAssertGreaterThan(legacy.meterPublishInterval, modern.meterPublishInterval)
        XCTAssertGreaterThan(legacy.preferredIOBufferDuration, modern.preferredIOBufferDuration)
    }

    func testRealtimePrioritySitsBetweenControlAndBulk() {
        XCTAssertLessThan(BLESendPriority.bulk, BLESendPriority.realtime)
        XCTAssertLessThan(BLESendPriority.realtime, BLESendPriority.control)
    }
}
