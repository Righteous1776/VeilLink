import XCTest
@testable import VeilLink

final class PrismRiftGameTests: XCTestCase {
    func testPrismRiftReplayIsDeterministic() {
        var first = PrismRiftState(seed: 0x2612)
        var replay = PrismRiftState(seed: 0x2612)
        for tick in 0..<2_400 {
            let input = PrismRiftInput(
                horizontal: sin(Double(tick) * 0.019),
                vertical: cos(Double(tick) * 0.013),
                firing: tick % 7 != 0,
                boosting: tick % 240 < 80
            )
            first.step(input: input)
            replay.step(input: input)
            XCTAssertEqual(first, replay)
        }
    }

    func testInputAndResourcesRemainBounded() {
        XCTAssertEqual(PrismRiftInput(horizontal: 9, vertical: -7).horizontal, 1)
        XCTAssertEqual(PrismRiftInput(horizontal: 9, vertical: -7).vertical, -1)

        var state = PrismRiftState(seed: 81)
        for tick in 0..<3_000 where state.outcome == .running {
            state.step(input: PrismRiftInput(
                horizontal: sin(Double(tick) * 0.03) * 4,
                vertical: cos(Double(tick) * 0.017) * 4,
                firing: true,
                boosting: tick.isMultiple(of: 2)
            ))
            let value = state.snapshot
            XCTAssertTrue((-1...1).contains(value.x))
            XCTAssertTrue((-1...1).contains(value.y))
            XCTAssertTrue((0...100).contains(value.hull))
            XCTAssertTrue((0...100).contains(value.shield))
            XCTAssertTrue((0...100).contains(value.energy))
        }
    }

    func testEncounterCorpusIsStableAndSeedSpecific() {
        let first = PrismRiftState(seed: 42)
        let replay = PrismRiftState(seed: 42)
        let other = PrismRiftState(seed: 43)
        let corpus = (1...40).map(first.encounter(for:))
        XCTAssertEqual(corpus, (1...40).map(replay.encounter(for:)))
        XCTAssertNotEqual(corpus, (1...40).map(other.encounter(for:)))
    }

    func testFirstBossStopsTravelAndExposesDeterministicTarget() {
        var state = PrismRiftState(seed: 7)
        for _ in 0..<1_200 where state.bossIndex == nil {
            state.step(input: PrismRiftInput(boosting: true))
        }
        XCTAssertEqual(state.bossIndex, 0)
        XCTAssertNotNil(state.bossHealth)
        let stoppedDistance = state.distance
        for _ in 0..<120 { state.step(input: PrismRiftInput()) }
        XCTAssertEqual(state.distance, stoppedDistance, accuracy: 0.000_001)
        XCTAssertEqual(state.bossPosition(index: 0), state.bossPosition(index: 0))
    }

    func testTerminalStateCannotMutate() {
        var state = PrismRiftState(seed: 99)
        for _ in 0..<20_000 where state.outcome == .running {
            state.step(input: PrismRiftInput())
        }
        XCTAssertEqual(state.outcome, .destroyed)
        let terminal = state
        state.step(input: PrismRiftInput(horizontal: 1, vertical: 1, firing: true, boosting: true))
        XCTAssertEqual(state, terminal)
    }
}
