import XCTest
@testable import VeilLink

final class AfterglowConvoyGameTests: XCTestCase {
    func testIdenticalSeedAndInputStreamAreDeterministic() {
        var first = AfterglowConvoyState(seed: 0xA11CE)
        var second = AfterglowConvoyState(seed: 0xA11CE)

        for tick in 0..<1_200 {
            let input = AfterglowConvoyInput(
                vertical: sin(Double(tick) * 0.021),
                shielding: tick % 190 < 52
            )
            first.step(input: input)
            second.step(input: input)
            XCTAssertEqual(first, second)
            if first.isFinished { break }
        }
    }

    func testHazardGenerationIsStable() {
        let state = AfterglowConvoyState(seed: 42)
        for segment in 1...30 {
            XCTAssertEqual(state.hazard(for: segment), state.hazard(for: segment))
        }
    }

    func testInputClampsVerticalRange() {
        XCTAssertEqual(AfterglowConvoyInput(vertical: 4).vertical, 1)
        XCTAssertEqual(AfterglowConvoyInput(vertical: -4).vertical, -1)
    }

    func testResourcesStayBounded() {
        var state = AfterglowConvoyState(seed: 88)
        for tick in 0..<3_600 where !state.isFinished {
            state.step(input: AfterglowConvoyInput(
                vertical: cos(Double(tick) * 0.013),
                shielding: tick % 240 < 70
            ))
            XCTAssertTrue((0...100).contains(state.hull))
            XCTAssertTrue((0...100).contains(state.beacon))
            XCTAssertTrue((0...100).contains(state.shield))
        }
    }

    func testShieldPreservesBeaconDuringEquivalentOpening() {
        var plain = AfterglowConvoyState(seed: 9)
        var guarded = AfterglowConvoyState(seed: 9)
        for _ in 0..<300 {
            plain.step(input: AfterglowConvoyInput(vertical: 0, shielding: false))
            guarded.step(input: AfterglowConvoyInput(vertical: 0, shielding: true))
        }
        XCTAssertGreaterThan(guarded.beacon, plain.beacon)
        XCTAssertLessThan(guarded.shield, plain.shield)
    }

    func testStoryBeatAppearsAfterEarlyProgress() {
        var state = AfterglowConvoyState(seed: 101)
        for _ in 0..<600 where !state.isFinished {
            state.step(input: AfterglowConvoyInput())
            if state.snapshot().storyLine != nil { break }
        }
        XCTAssertNotNil(state.snapshot().storyLine)
    }

    func testFinishedStateDoesNotAdvance() {
        var state = AfterglowConvoyState(seed: 5)
        for _ in 0..<5_000 where !state.isFinished {
            state.step(input: AfterglowConvoyInput(vertical: 0.1, shielding: false))
        }
        XCTAssertTrue(state.isFinished)
        let finished = state
        state.step(input: AfterglowConvoyInput(vertical: -1, shielding: true))
        XCTAssertEqual(state, finished)
    }

    func testDifferentSeedsDivergeAcrossHazardCorpus() {
        let first = AfterglowConvoyState(seed: 1)
        let second = AfterglowConvoyState(seed: 2)
        XCTAssertNotEqual(
            (1...12).map { first.hazard(for: $0) },
            (1...12).map { second.hazard(for: $0) }
        )
    }
}
