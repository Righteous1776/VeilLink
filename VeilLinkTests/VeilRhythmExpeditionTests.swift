import XCTest
@testable import VeilLink

final class VeilRhythmExpeditionTests: XCTestCase {
    typealias E = VeilRhythmExpedition
    private func complete(_ session: inout E.Session) throws {
        for beat in 0..<E.beatsPerDistrict {
            let note = session.expectedNote!
            XCTAssertEqual(note.beat, beat)
            try session.perform(.tap(beat: beat, lane: note.lane, offset: 0))
        }
    }
    func testSeedDeterminism() {
        for district in 0..<E.districtCount {
            for beat in 0..<E.beatsPerDistrict {
                XCTAssertEqual(E.note(seed: 21, district: district, beat: beat), E.note(seed: 21, district: district, beat: beat))
            }
        }
    }
    func testDifferentSeeds() {
        let a=(0..<16).compactMap { E.note(seed: 1,district:0,beat:$0)?.lane }
        let b=(0..<16).compactMap { E.note(seed: 2,district:0,beat:$0)?.lane }
        XCTAssertNotEqual(a,b)
    }
    func testPerfectWinFourDistricts() throws {
        var s=E.Session(seed: 7)
        for district in 0..<E.districtCount {
            try complete(&s)
            if district < E.districtCount-1 { try s.perform(.travel) }
        }
        XCTAssertEqual(s.phase,.cleared)
        XCTAssertEqual(s.collectedFragments,4)
        XCTAssertEqual(s.progress,1)
        XCTAssertEqual(s.bestCombo,64)
    }
    func testInvalidActionDoesNotMutate() {
        var s=E.Session(seed: 11)
        XCTAssertThrowsError(try s.perform(.tap(beat:1,lane:0,offset:0)))
        XCTAssertThrowsError(try s.perform(.travel))
        XCTAssertEqual(s.history.count,0)
        XCTAssertEqual(s.score,0)
    }
    func testWrongLaneLoss() throws {
        var s=E.Session(seed: 1)
        let lane=s.expectedNote!.lane
        let result=try s.perform(.tap(beat:0,lane:(lane+1)%4,offset:0))
        XCTAssertEqual(result.quality,.miss)
        XCTAssertEqual(s.focus,88)
    }
    func testInvalidTimeAndLane() {
        var s=E.Session(seed: 1)
        XCTAssertThrowsError(try s.perform(.tap(beat:0,lane:4,offset:0)))
        XCTAssertThrowsError(try s.perform(.tap(beat:0,lane:0,offset:.infinity)))
        XCTAssertThrowsError(try s.perform(.tap(beat:0,lane:0,offset:10)))
        XCTAssertEqual(s.nextBeat,0)
    }
    func testGoodThreshold() throws {
        var s=E.Session(seed: 17)
        let lane=s.expectedNote!.lane
        let event=try s.perform(.tap(beat:0,lane:lane,offset:0.15))
        XCTAssertEqual(event.quality,.good)
        XCTAssertGreaterThan(s.score,0)
    }
    func testReplayMatches() throws {
        var first=E.Session(seed: 100)
        var actions:[E.Command]=[]
        for b in 0..<16 {
            let lane=first.expectedNote!.lane
            let a=E.Command.tap(beat:b,lane:lane,offset:0)
            try first.perform(a)
            actions.append(a)
        }
        let again=try E.replay(seed:100,commands:actions)
        XCTAssertEqual(again.score,first.score)
        XCTAssertEqual(again.history,first.history)
    }
    func testCodableSnapshot() throws {
        var s=E.Session(seed: 800)
        try s.perform(.tap(beat:0,lane:s.expectedNote!.lane,offset:0))
        let revived=try JSONDecoder().decode(E.Session.self,from:JSONEncoder().encode(s))
        XCTAssertEqual(revived.history,s.history)
        XCTAssertEqual(revived.nextBeat,s.nextBeat)
    }
    func testCompletionStopsInput() throws {
        var s=E.Session(seed: 1)
        for d in 0..<4 {
            try complete(&s)
            if d<3 { try s.perform(.travel) }
        }
        XCTAssertThrowsError(try s.perform(.travel))
        XCTAssertThrowsError(try s.perform(.tap(beat:15,lane:0,offset:0)))
    }
}

extension VeilRhythmExpeditionTests {
    func testChapterContentPackChartMatchesEngine() {
        let expected = [
            [0,1,2,1,1,0,2,3,1,3,1,3,0,1,0,2],
            [2,1,3,3,2,3,0,1,0,0,2,0,0,1,3,1],
            [3,1,1,2,1,0,3,1,2,2,1,1,3,2,2,2],
            [0,1,0,3,3,0,1,2,1,1,0,2,1,1,1,2]
        ]
        for district in 0..<4 {
            let observed = (0..<16).map { E.note(seed: 20261025, district: district, beat: $0)!.lane }
            XCTAssertEqual(observed, expected[district])
        }
    }
}
