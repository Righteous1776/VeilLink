import XCTest
@testable import VeilLink

final class VeilStationChronicleTests: XCTestCase {
    typealias E = VeilStationChronicle
    func testFourNamedEras() {
        XCTAssertEqual(E.Era.allCases.count,4)
        XCTAssertEqual(E.Game(seed:1).currentEra,.steam)
    }
    func testDemandStableAcrossSeedsAndDays() {
        for seed: UInt64 in [0,1,999,UInt64.max] {
            for day in 0..<20 {
                XCTAssertEqual(E.demand(seed:seed,day:day), E.demand(seed:seed,day:day))
                XCTAssertTrue((30...90).contains(E.demand(seed:seed,day:day)))
            }
        }
        XCTAssertEqual(E.demand(seed:2,day:-1),0)
    }
    func testDispatchMustPrecedeDayClose() {
        var g=E.Game(seed:1)
        XCTAssertThrowsError(try g.apply(.closeDay))
        XCTAssertEqual(g.day,0)
    }
    func testNoDoubleDispatch() throws {
        var g=E.Game(seed:2)
        try g.apply(.dispatch)
        XCTAssertThrowsError(try g.apply(.dispatch))
        XCTAssertEqual(g.commands.count,1)
    }
    func testOneProjectPerDay() throws {
        var g=E.Game(seed:1)
        try g.apply(.undertake(.restore))
        XCTAssertThrowsError(try g.apply(.undertake(.archive)))
        XCTAssertEqual(g.historyPoints,0)
    }
    func testCannotOverspend() throws {
        var g=E.Game(seed:2)
        try g.apply(.undertake(.platform))
        try g.apply(.dispatch)
        try g.apply(.closeDay)
        // No negative treasury invariant across any legal future decisions.
        for _ in 0..<19 {
            if g.condition < 30 && g.funds >= 40 { try g.apply(.undertake(.restore)) }
            else if g.trust < 35 && g.funds >= 25 { try g.apply(.undertake(.outreach)) }
            else if g.funds >= 80 { try g.apply(.undertake(.platform)) }
            try g.apply(.dispatch)
            if g.phase == .running { try g.apply(.closeDay) }
        }
        XCTAssertGreaterThanOrEqual(g.funds,0)
        XCTAssertEqual(g.phase,.completed)
    }
    func testEraTransitionsAtDayFive() throws {
        var g=E.Game(seed:4)
        for _ in 0..<5 { try g.apply(.dispatch); try g.apply(.closeDay) }
        XCTAssertEqual(g.day,5)
        XCTAssertEqual(g.currentEra,.electrification)
    }
    func testCompleteTwentyDays() throws {
        var g=E.Game(seed:6)
        for _ in 0..<20 {
            if g.condition < 30 && g.funds >= 40 { try g.apply(.undertake(.restore)) }
            else if g.trust < 35 && g.funds >= 25 { try g.apply(.undertake(.outreach)) }
            else if g.funds >= 25 { try g.apply(.undertake(.archive)) }
            try g.apply(.dispatch)
            if g.phase == .running { try g.apply(.closeDay) }
        }
        XCTAssertEqual(g.phase,.completed)
        XCTAssertEqual(g.progress,1)
        XCTAssertEqual(g.day,20)
        XCTAssertTrue(g.historyPoints >= 4)
        XCTAssertThrowsError(try g.apply(.dispatch))
    }
    func testFailedActionIsAtomic() throws {
        var g=E.Game(seed:1)
        let before=try JSONEncoder().encode(g)
        XCTAssertThrowsError(try g.apply(.closeDay))
        let after=try JSONEncoder().encode(g)
        let pre=try JSONDecoder().decode(E.Game.self,from:before)
        let post=try JSONDecoder().decode(E.Game.self,from:after)
        XCTAssertEqual(pre.events,post.events)
        XCTAssertEqual(g.funds,240)
    }
    func testReplayRoundTrip() throws {
        var g=E.Game(seed:123)
        try g.apply(.undertake(.archive))
        try g.apply(.dispatch)
        try g.apply(.closeDay)
        let imported=try E.importReplay(g.exportReplay())
        XCTAssertEqual(imported.commands,g.commands)
        XCTAssertEqual(imported.events,g.events)
        XCTAssertEqual(imported.funds,g.funds)
    }
    func testRejectInvalidReplay() {
        XCTAssertThrowsError(try E.importReplay(Data("{}".utf8)))
        XCTAssertThrowsError(try E.importReplay(Data(repeating:65,count:32769)))
        XCTAssertThrowsError(try E.importReplay(Data("{\"version\":2,\"seed\":1,\"commands\":[]}".utf8)))
    }
    func testCapacityCappedAndStationConditionBounded() throws {
        var g=E.Game(seed:8)
        for _ in 0..<20 {
            if g.funds >= 80 { try g.apply(.undertake(.platform)) }
            try g.apply(.dispatch)
            if g.phase == .running { try g.apply(.closeDay) } else { break }
        }
        XCTAssertLessThanOrEqual(g.capacity,140)
        XCTAssertTrue((0...100).contains(g.condition))
    }
    func testTwentyOriginalDayStories() {
        XCTAssertEqual(E.dayStories.count,20)
        XCTAssertEqual(Set(E.dayStories).count,20)
        XCTAssertTrue(E.dayStories.allSatisfy { $0.count >= 18 })
    }
    func testOriginalBulletinsHaveSpeaker() {
        let b=E.Game(seed:1).bulletin
        XCTAssertFalse(b.speaker.isEmpty)
        XCTAssertFalse(b.message.isEmpty)
    }
    func testTwoHundredSeedsConservativeFullCampaign() throws {
        for seed in UInt64(0)..<200 {
            var g=E.Game(seed:seed)
            for _ in 0..<20 {
                if g.condition < 30 && g.funds >= 40 { try g.apply(.undertake(.restore)) }
                else if g.trust < 35 && g.funds >= 25 { try g.apply(.undertake(.outreach)) }
                else if g.funds >= 25 { try g.apply(.undertake(.archive)) }
                try g.apply(.dispatch)
                XCTAssertGreaterThanOrEqual(g.funds,0)
                XCTAssertTrue((0...100).contains(g.trust))
                if g.phase == .running { try g.apply(.closeDay) }
            }
            XCTAssertEqual(g.phase,.completed,"seed=\(seed)")
            XCTAssertEqual(g.day,20)
            let loaded=try E.importReplay(g.exportReplay())
            XCTAssertEqual(loaded.funds,g.funds)
            XCTAssertEqual(loaded.events,g.events)
        }
    }

}
