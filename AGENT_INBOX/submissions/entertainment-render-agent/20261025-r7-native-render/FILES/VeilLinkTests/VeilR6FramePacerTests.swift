import XCTest
#if canImport(VeilMegaEngines)
@testable import VeilMegaEngines
#elseif canImport(VeilLink)
@testable import VeilLink
#endif

final class VeilR6FramePacerTests: XCTestCase {
    func testFirstFrameHasNoTimeJump() {
        var p=VeilFramePacer()
        XCTAssertEqual(p.advance(now:200)?.simulationSteps,0)
    }
    func testSixtyFramesIsOneSecond() {
        var p=VeilFramePacer()
        _ = p.advance(now:0)
        for i in 1...60 { _ = p.advance(now:Double(i)/60) }
        XCTAssertEqual(p.totalSimSteps,60)
    }
    func testThirtyFPSStillHasSixtyLogicSteps() {
        var p=VeilFramePacer()
        _ = p.advance(now:0)
        for i in 1...30 { _ = p.advance(now:Double(i)/30) }
        XCTAssertEqual(p.totalSimSteps,60)
    }
    func testBackgroundGapIsCappedAndResetSafe() {
        var p=VeilFramePacer()
        _ = p.advance(now:0)
        let step=p.advance(now:10000)!
        XCTAssertLessThanOrEqual(step.simulationSteps,4)
        XCTAssertGreaterThan(step.droppedSeconds,9999)
        p.reset()
        XCTAssertEqual(p.advance(now:10001)?.simulationSteps,0)
    }
    func testInvalidTimeDoesNotCorruptClock() {
        var p=VeilFramePacer()
        _ = p.advance(now:5)
        XCTAssertNil(p.advance(now:.nan))
        XCTAssertNil(p.advance(now:4))
        XCTAssertEqual(p.advance(now:5+1.0/60)?.simulationSteps,1)
    }
    func testQualityBudgetsBoundMemoryAndParticles() {
        let low=VeilRenderBudget(tier:.legacy)
        let high=VeilRenderBudget(tier:.high)
        XCTAssertEqual(low.targetFPS,30)
        XCTAssertEqual(low.particleBudget,0)
        XCTAssertLessThan(low.maxSprites,high.maxSprites)
    }
    func testInterpolationAlwaysValid() {
        var p=VeilFramePacer()
        _=p.advance(now:0)
        for i in 1...200 {
            let step=p.advance(now:Double(i)/41)!
            XCTAssertGreaterThanOrEqual(step.interpolation,0)
            XCTAssertLessThanOrEqual(step.interpolation,1)
        }
    }
}
