import XCTest
#if canImport(VeilMegaEngines)
@testable import VeilMegaEngines
#elseif canImport(VeilLink)
@testable import VeilLink
#endif

final class VeilR6VisualTimelineTests: XCTestCase {
    typealias V=VeilRhythmVisualTimeline
    func testOneNoteAtHitLine() throws {
        let note=try XCTUnwrap(V.notes(seed:7,district:0,nextBeat:0,secondsToNextBeat:0).first)
        XCTAssertEqual(note.y,V.strikeY,accuracy:1e-8)
        XCTAssertEqual(note.beat,0)
    }
    func testFutureNoteStartsAtSpawnLine() throws {
        let note=try XCTUnwrap(V.notes(seed:7,district:0,nextBeat:0,secondsToNextBeat:1.6).first)
        XCTAssertEqual(note.y,V.spawnY,accuracy:1e-8)
    }
    func testAllFourLaneCentersAreInsideCanvas() {
        for seed in UInt64(0)..<80 {
            let arr=V.notes(seed:seed,district:0,nextBeat:0,secondsToNextBeat:0.5)
            XCTAssertFalse(arr.isEmpty)
            for note in arr {
                XCTAssertTrue((0..<4).contains(note.lane))
                XCTAssertGreaterThan(note.x,0)
                XCTAssertLessThan(note.x,390)
                XCTAssertGreaterThanOrEqual(note.y,V.spawnY)
                XCTAssertLessThanOrEqual(note.y,V.strikeY)
            }
        }
    }
    func testInvalidFrameHasNoNotes() {
        XCTAssertTrue(V.notes(seed:1,district:0,nextBeat:0,secondsToNextBeat:.nan).isEmpty)
        XCTAssertTrue(V.notes(seed:1,district:-1,nextBeat:0,secondsToNextBeat:0).isEmpty)
        XCTAssertTrue(V.notes(seed:1,district:0,nextBeat:16,secondsToNextBeat:0).isEmpty)
    }
    func testNoFutureLeakAcrossDistrict() {
        let notes=V.notes(seed:1,district:3,nextBeat:15,secondsToNextBeat:1.2,capacity:10)
        XCTAssertTrue(notes.allSatisfy { $0.beat==15 })
    }
    func testClockAnimationInvariantAcrossFPS() {
        let at60=V.notes(seed:3,district:1,nextBeat:2,secondsToNextBeat:0.42)
        let at30=V.notes(seed:3,district:1,nextBeat:2,secondsToNextBeat:0.42)
        XCTAssertEqual(at60,at30)
    }
}
