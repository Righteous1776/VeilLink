import XCTest
#if canImport(VeilMegaEngines)
@testable import VeilMegaEngines
#elseif canImport(VeilLink)
@testable import VeilLink
#endif

final class VeilR7FrameStatsSmokeTests: XCTestCase {
    func testBoundedRecentWindow() {
        var stats = VeilRenderFrameStats()
        for i in 0...400 { stats.observe(Double(i)/30) }
        XCTAssertEqual(stats.report.sampleCount, 240)
        XCTAssertEqual(stats.report.slowFrames, 0)
    }
    func testNonfiniteAndBackgroundGapExcluded() {
        var stats = VeilRenderFrameStats()
        stats.observe(1)
        stats.observe(.nan)
        stats.observe(360)
        stats.observe(360.03)
        XCTAssertEqual(stats.report.sampleCount, 1)
    }
}
