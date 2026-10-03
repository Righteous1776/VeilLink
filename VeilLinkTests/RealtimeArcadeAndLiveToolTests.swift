import XCTest
@testable import VeilLink

final class RealtimeArcadeAndLiveToolTests: XCTestCase {
    func testRealtimePlatformerCampaignGeometryIsValidAndHasProgression() {
        XCTAssertEqual(PlatformerLevel.campaign.count, 3)
        XCTAssertTrue(PlatformerLevel.campaign.allSatisfy(\.isValid))
        XCTAssertTrue(PlatformerLevel.campaign.allSatisfy { !$0.crystals.isEmpty && !$0.platforms.isEmpty })
    }

    func testRhythmChartAndEngineReplayDeterministically() {
        let firstChart = RhythmBeatGenerator.makeChart(level: 3, seed: 0xCAFE)
        XCTAssertEqual(firstChart, RhythmBeatGenerator.makeChart(level: 3, seed: 0xCAFE))
        XCTAssertNotEqual(firstChart, RhythmBeatGenerator.makeChart(level: 3, seed: 0xBEEF))

        var first = RhythmRunEngine(seed: 0xCAFE)
        var replay = RhythmRunEngine(seed: 0xCAFE)
        first.start()
        replay.start()
        for _ in 0..<240 {
            XCTAssertEqual(first.advance(deltaTime: 1.0 / 60.0), replay.advance(deltaTime: 1.0 / 60.0))
        }
        XCTAssertEqual(first.state, replay.state)
        XCTAssertEqual(first.chart, replay.chart)
    }

    func testSpaceSimulationClampsMovementAndReplaysIdentically() {
        var first = SpaceSimulation(seed: 42)
        var replay = SpaceSimulation(seed: 42)
        let input = SpaceInput(movement: SpaceVector(x: 3, y: 4))
        for _ in 0..<180 {
            XCTAssertEqual(first.advance(frameDelta: 1.0 / 60.0, input: input), replay.advance(frameDelta: 1.0 / 60.0, input: input))
        }
        XCTAssertEqual(first.snapshot, replay.snapshot)
        XCTAssertGreaterThanOrEqual(first.snapshot.player.position.x, 0)
        XCTAssertLessThanOrEqual(first.snapshot.player.position.x, first.configuration.arenaWidth)
        XCTAssertGreaterThanOrEqual(first.snapshot.player.position.y, 0)
        XCTAssertLessThanOrEqual(first.snapshot.player.position.y, first.configuration.arenaHeight)
    }

    func testLiveToolMathBoundsHardwareReadingsAndGeometry() {
        let silence = VeilLiveToolMath.soundReading(rms: 0, peak: 0)
        XCTAssertEqual(silence.decibels, -80)
        XCTAssertEqual(silence.peakDecibels, -80)
        XCTAssertEqual(silence.normalizedLevel, 0.01, accuracy: 0.000_001)

        let waveform = VeilLiveToolMath.downsample([0, 1, 0, 1], count: 2)
        XCTAssertEqual(waveform.count, 2)
        let expectedRMS = 1 / sqrt(2.0)
        XCTAssertEqual(waveform[0], expectedRMS, accuracy: 1e-12)
        XCTAssertEqual(waveform[1], expectedRMS, accuracy: 1e-12)

        let offset = VeilLiveToolMath.clampedBubbleOffset(roll: 90, pitch: 90, radius: 20)
        XCTAssertEqual(hypot(offset.x, offset.y), 20, accuracy: 0.000_001)
        XCTAssertEqual(VeilLiveToolMath.metronomeInterval(bpm: 120), 0.5, accuracy: 0.000_001)
        XCTAssertEqual(VeilBeaconPattern.sos.segments.filter(\.isOn).count, 9)
    }
}
