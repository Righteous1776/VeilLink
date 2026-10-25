import XCTest
@testable import VeilMegaEngines

final class VeilRhythmLiveConductorTests: XCTestCase {
    typealias C = VeilRhythmLiveConductor
    func testNoFreePerfect() throws {
        var c=C(seed:3)
        try c.start(at:100)
        XCTAssertThrowsError(try c.tap(lane: c.session.expectedNote!.lane, at:100))
        XCTAssertEqual(c.session.score,0)
        XCTAssertEqual(c.session.nextBeat,0)
    }
    func testActualMeasuredPerfect() throws {
        var c=C(seed:3)
        try c.start(at:100)
        let lane=c.session.expectedNote!.lane
        XCTAssertEqual(try c.tap(lane:lane, at:101.6), .hit(.perfect))
        XCTAssertEqual(c.session.nextBeat,1)
    }
    func testGoodMeasuredOffset() throws {
        var c=C(seed:3)
        try c.start(at:10)
        XCTAssertEqual(try c.tap(lane:c.session.expectedNote!.lane,at:11.74),.hit(.good))
    }
    func testInvalidTimestampsAreRejected() throws {
        var c=C(seed:1)
        XCTAssertThrowsError(try c.start(at:.nan))
        try c.start(at:10)
        XCTAssertThrowsError(try c.tap(lane:0,at:.infinity))
        XCTAssertThrowsError(try c.tap(lane:0,at:9))
        XCTAssertEqual(c.session.nextBeat,0)
    }
    func testExpiredNotesActuallyMiss() throws {
        var c=C(seed:2)
        try c.start(at:0)
        XCTAssertEqual(try c.advance(to:2),1)
        XCTAssertEqual(c.session.score,0)
        XCTAssertEqual(c.session.focus,88)
    }
    func testWrongLaneJudgedMiss() throws {
        var c=C(seed:2)
        try c.start(at:0)
        XCTAssertEqual(try c.tap(lane:(c.session.expectedNote!.lane+1)%4,at:1.6),.hit(.miss))
    }
    func testPauseTimeExcluded() throws {
        var c=C(seed:2)
        try c.start(at:0)
        try c.pause(at:1.0)
        XCTAssertThrowsError(try c.tap(lane:0,at:20))
        try c.resume(at:20)
        XCTAssertEqual(try c.advance(to:20.59),0)
        XCTAssertEqual(try c.tap(lane:c.session.expectedNote!.lane,at:20.6),.hit(.perfect))
    }
    func testNoBackgroundConsumption() throws {
        var c=C(seed:2)
        try c.start(at:0)
        try c.pause(at:1)
        XCTAssertEqual(try c.advance(to:300),0)
        XCTAssertEqual(c.session.nextBeat,0)
        try c.resume(at:301)
        XCTAssertEqual(try c.advance(to:301.79),1)
    }
    func testInvalidLaneCannotSkipBeat() throws {
        var c=C(seed:2)
        try c.start(at:0)
        XCTAssertThrowsError(try c.tap(lane:5,at:1.6))
        XCTAssertEqual(c.session.nextBeat,0)
    }
    func testTravelRequiresStageClearAndStartsFresh() throws {
        var c=C(seed:2)
        try c.start(at:10)
        XCTAssertThrowsError(try c.travel(at:10))
        for beat in 0..<16 {
            let note=c.session.expectedNote!
            try c.tap(lane:note.lane,at:11.6 + note.nominalTime)
            XCTAssertEqual(c.session.nextBeat,beat+1)
        }
        try c.travel(at:25)
        XCTAssertFalse(c.isRunning)
        XCTAssertEqual(c.session.district,1)
        try c.start(at:26)
        XCTAssertEqual(try c.tap(lane:c.session.expectedNote!.lane,at:27.6),.hit(.perfect))
    }
    func testSnapshotRebaseAtPendingBeat() throws {
        var original=C(seed:2)
        try original.start(at:0)
        let first=original.session.expectedNote!
        try original.tap(lane:first.lane,at:1.6)
        let snapshot=try JSONDecoder().decode(VeilRhythmExpedition.Session.self,
                from:JSONEncoder().encode(original.session))
        var c=C(session:snapshot)
        try c.start(at:100)
        XCTAssertEqual(try c.tap(lane:c.session.expectedNote!.lane,at:101.6),.hit(.perfect))
        XCTAssertEqual(c.session.nextBeat,2)
    }
    func testLargeClockGapEventuallyFailsSafely() throws {
        var c=C(seed:2)
        try c.start(at:0)
        _ = try c.advance(to:90000)
        XCTAssertEqual(c.session.phase,.failed)
        XCTAssertLessThanOrEqual(c.session.totalActions,1024)
    }
    func testFrameRenderingIsReadOnly() throws {
        var c=C(seed:2)
        try c.start(at:1)
        let initial=c.session.nextBeat
        let frame=c.frame(at:2)
        XCTAssertTrue(frame.running)
        XCTAssertEqual(c.session.nextBeat,initial)
    }
    func testEventReplayEquivalent() throws {
        var c=C(seed:2)
        try c.start(at:0)
        for _ in 0..<5 {
            let note=c.session.expectedNote!
            try c.tap(lane:note.lane,at:1.6+note.nominalTime)
        }
        let replay=try VeilRhythmExpedition.replay(seed:2,commands:c.session.history.map(\.command))
        XCTAssertEqual(c.session.score,replay.score)
        XCTAssertEqual(c.session.focus,replay.focus)
    }
    func testHundredSeedsDeterministicPerfectCampaign() throws {
        for seed in UInt64(0)..<100 {
            var conductor = C(seed:seed)
            var time = 100.0
            try conductor.start(at:time)
            for district in 0..<4 {
                for _ in 0..<16 {
                    let note = conductor.session.expectedNote!
                    try conductor.tap(lane:note.lane,at:time + C.leadIn + note.nominalTime)
                }
                if district < 3 {
                    time += 100
                    try conductor.travel(at:time)
                    try conductor.start(at:time)
                }
            }
            XCTAssertEqual(conductor.session.phase,.cleared)
            XCTAssertEqual(conductor.session.bestCombo,64)
        }
    }

}
