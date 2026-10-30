import XCTest
@testable import VeilLink

/// Source-inclusive integration smoke tests. Require Governor to import the
/// R4 VeilRhythmExpedition dependency before compiling this test target.
final class VeilEntertainmentR5IntegrationSmokeTests: XCTestCase {
    func testRhythmRequiresActualTapTime() throws {
        var game = VeilRhythmLiveConductor(seed: 20261025)
        try game.start(at: 100)
        let lane = try XCTUnwrap(game.session.expectedNote?.lane)
        XCTAssertThrowsError(try game.tap(lane: lane, at: 100))
        XCTAssertEqual(game.session.score, 0)
        XCTAssertEqual(try game.tap(lane: lane, at: 101.6), .hit(.perfect))
    }

    func testRhythmPauseDoesNotAutoMiss() throws {
        var game = VeilRhythmLiveConductor(seed: 5)
        try game.start(at: 0)
        try game.pause(at: 1)
        XCTAssertEqual(try game.advance(to: 200), 0)
        try game.resume(at: 201)
        XCTAssertEqual(game.session.nextBeat, 0)
    }

    func testStationRequiresDispatchBeforeDayClose() {
        var game = VeilStationChronicle.Game(seed: 1)
        XCTAssertThrowsError(try game.apply(.closeDay))
        XCTAssertEqual(game.day, 0)
        XCTAssertEqual(game.funds, 240)
    }

    func testStationReplayReconstructsState() throws {
        var game = VeilStationChronicle.Game(seed: 9)
        try game.apply(.undertake(.archive))
        try game.apply(.dispatch)
        try game.apply(.closeDay)
        let copy = try VeilStationChronicle.importReplay(game.exportReplay())
        XCTAssertEqual(copy.events, game.events)
        XCTAssertEqual(copy.funds, game.funds)
    }

    func testStationTwentyOriginalScenes() {
        XCTAssertEqual(VeilStationChronicle.dayStories.count, 20)
        XCTAssertEqual(Set(VeilStationChronicle.dayStories).count, 20)
    }

    func testStationRejectsMalformedImport() {
        XCTAssertThrowsError(try VeilStationChronicle.importReplay(Data("{}".utf8)))
    }
}
