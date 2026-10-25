import XCTest
#if canImport(VeilMegaEngines)
@testable import VeilMegaEngines
#elseif canImport(VeilLink)
@testable import VeilLink
#endif

final class VeilR7FrameStatsTests: XCTestCase {
    func testEmptyReportAndInitialSample() {
        var s = VeilRenderFrameStats()
        XCTAssertEqual(s.report.sampleCount, 0)
        s.observe(1)
        XCTAssertEqual(s.report.sampleCount, 0)
    }
    func testThirtyFpsCadence() {
        var s = VeilRenderFrameStats()
        for i in 0...60 { s.observe(Double(i) / 30) }
        XCTAssertEqual(s.report.sampleCount, 60)
        XCTAssertEqual(s.report.medianIntervalMs, 1000.0/30.0, accuracy:0.001)
        XCTAssertEqual(s.report.slowFrames, 0)
    }
    func testLongPauseNotCountedAsDroppedFrame() {
        var s = VeilRenderFrameStats()
        s.observe(1); s.observe(1.02); s.observe(200); s.observe(200.02)
        XCTAssertEqual(s.report.sampleCount, 2)
        XCTAssertEqual(s.report.slowFrames, 0)
    }
    func testRejectNaNAndBackwardsWithoutInflatingStats() {
        var s = VeilRenderFrameStats()
        s.observe(5)
        s.observe(.nan); s.observe(.infinity); s.observe(-3)
        s.observe(4)
        s.observe(4.02)
        XCTAssertEqual(s.report.sampleCount, 1)
    }
    func testSlowFramesCountWithinRing() {
        var s = VeilRenderFrameStats()
        s.observe(0)
        s.observe(0.05)
        s.observe(0.11)
        XCTAssertEqual(s.report.slowFrames, 2)
        XCTAssertEqual(s.report.sampleCount, 2)
    }
    func testRingBufferHardCapAndRecentSlowCount() {
        var s = VeilRenderFrameStats()
        s.observe(0)
        s.observe(0.07)
        for i in 1...400 { s.observe(0.07 + Double(i)*0.02) }
        XCTAssertEqual(s.report.sampleCount, 240)
        XCTAssertEqual(s.report.slowFrames, 0)
        XCTAssertLessThan(s.report.elapsedSeconds, 5)
    }
    func testResetClearsCounters() {
        var s = VeilRenderFrameStats()
        s.observe(1);s.observe(1.05);s.reset()
        XCTAssertEqual(s.report.sampleCount, 0)
        s.observe(999)
        XCTAssertEqual(s.report.sampleCount, 0)
    }
    func testDeterminismUnderIdenticalTraces() {
        var a = VeilRenderFrameStats(), b = VeilRenderFrameStats()
        for i in 0..<270 {
            let t = Double(i)/30.0 + (i%9==0 ? 0.003 : 0)
            a.observe(t);b.observe(t)
        }
        XCTAssertEqual(a.report,b.report)
    }
}
