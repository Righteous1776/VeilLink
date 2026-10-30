import XCTest
@testable import VeilLink

final class VeilR7RenderCacheTests: XCTestCase {
    typealias Cache = VeilRhythmRenderCache
    typealias Watch = VeilRenderSnapshotWatchdog

    func testAllDistrictsCanInitialize() {
        for d in 0..<4 { XCTAssertNotNil(Cache(seed: 42, district: d)) }
        XCTAssertNil(Cache(seed: 42, district: -1))
        XCTAssertNil(Cache(seed: 42, district: 4))
    }
    func testCacheMatchesReferenceForOneHundredSeedsAllDistricts() throws {
        for seed in UInt64(0)..<100 {
            for district in 0..<4 {
                let cache = try XCTUnwrap(Cache(seed: seed, district: district))
                for beat in 0..<16 {
                    for remaining in [-0.18, 0.0, 0.075, 0.5, 1.1, 1.6, 2.0] {
                        let base = VeilRhythmVisualTimeline.notes(seed: seed, district: district,
                                      nextBeat: beat, secondsToNextBeat: remaining, capacity: 5)
                        XCTAssertEqual(cache.visible(nextBeat: beat, secondsToNextBeat: remaining, capacity: 5), base)
                    }
                }
            }
        }
    }
    func testInvalidCapacityBeatAndClockProduceEmpty() throws {
        let c = try XCTUnwrap(Cache(seed: 1, district: 3))
        for k in [0, 17, -1] { XCTAssertTrue(c.visible(nextBeat: 2, secondsToNextBeat: 1, capacity:k).isEmpty) }
        XCTAssertTrue(c.visible(nextBeat: -1, secondsToNextBeat: 0).isEmpty)
        XCTAssertTrue(c.visible(nextBeat: 16, secondsToNextBeat: 0).isEmpty)
        XCTAssertTrue(c.visible(nextBeat: 0, secondsToNextBeat: .infinity).isEmpty)
        XCTAssertTrue(c.visible(nextBeat: 0, secondsToNextBeat: .nan).isEmpty)
    }
    func testStableVisualsIndifferentToRenderRate() throws {
        let c = try XCTUnwrap(Cache(seed: 100, district: 2))
        XCTAssertEqual(c.visible(nextBeat: 1, secondsToNextBeat: 0.25),
                       c.visible(nextBeat: 1, secondsToNextBeat: 0.25))
    }
    func testSnapshotFreshProgression() {
        if case .fresh(let age) = Watch.check(now: 50.1, sampledAt: 50, running: true) {
            XCTAssertEqual(age, 0.1, accuracy: 1e-10)
        } else { XCTFail("expected fresh snapshot") }
        XCTAssertEqual(Watch.check(now: 50, sampledAt: 50, running: true), .fresh(0))
    }
    func testExpiredRunningSnapshotHidden() {
        XCTAssertEqual(Watch.check(now: 51, sampledAt: 50, running: true), .stale)
        XCTAssertEqual(Watch.check(now: 51, sampledAt: 50, running: false), .fresh(0))
    }
    func testClockSkewPolicy() {
        XCTAssertEqual(Watch.check(now: 10, sampledAt: 10.01, running: true), .fresh(0))
        XCTAssertEqual(Watch.check(now: 10, sampledAt: 10.2, running: true), .invalid)
    }
    func testInvalidInputsFailClosed() {
        for v in [Double.nan, .infinity, -.infinity, -1] {
            XCTAssertEqual(Watch.check(now: v, sampledAt: 10, running: true), .invalid)
            XCTAssertEqual(Watch.check(now: 10, sampledAt: v, running: true), .invalid)
        }
    }
    func testFrameClockStallPolicyAtBoundary() {
        if case .fresh(let age) = Watch.check(now: 12 + Watch.maximumRunningAge,
                                                  sampledAt: 12, running: true) {
            XCTAssertEqual(age, Watch.maximumRunningAge, accuracy: 1e-10)
        } else { XCTFail("boundary snapshot must still be visible") }
    }
}
