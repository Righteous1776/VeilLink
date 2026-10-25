import XCTest
#if canImport(VeilMegaEngines)
@testable import VeilMegaEngines
#elseif canImport(VeilLink)
@testable import VeilLink
#endif

final class VeilR7RenderCacheSmokeTests: XCTestCase {
    func testCacheParityAcrossDistricts() throws {
        for seed in UInt64(0)..<100 {
            for district in 0..<4 {
                let cache = try XCTUnwrap(VeilRhythmRenderCache(seed: seed, district: district))
                for beat in 0..<16 {
                    for time in [0.0, 0.5, 1.6] {
                        XCTAssertEqual(cache.visible(nextBeat:beat, secondsToNextBeat:time),
                          VeilRhythmVisualTimeline.notes(seed:seed,district:district,nextBeat:beat,secondsToNextBeat:time,capacity:5))
                    }
                }
            }
        }
    }
    func testRejectOutOfRangeAndStale() throws {
        XCTAssertNil(VeilRhythmRenderCache(seed: 1, district: 4))
        let cache = try XCTUnwrap(VeilRhythmRenderCache(seed: 1, district: 0))
        XCTAssertTrue(cache.visible(nextBeat: 16, secondsToNextBeat: 0).isEmpty)
        XCTAssertEqual(VeilRenderSnapshotWatchdog.check(now: 2, sampledAt: 1, running: true), .stale)
        XCTAssertEqual(VeilRenderSnapshotWatchdog.check(now: 2, sampledAt: 1, running: false), .fresh(0))
    }
}
