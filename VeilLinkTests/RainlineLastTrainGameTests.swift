import XCTest
import SpriteKit
@testable import VeilLink

final class RainlineLastTrainGameTests: XCTestCase {
    @MainActor
    func testResizeBeforePresentationDoesNotDoubleParentSceneNodes() {
        let scene = RainlineLastTrainScene(seed: 58)
        let oldSize = scene.size
        scene.size = CGSize(width: 430, height: 932)

        scene.didChangeSize(oldSize)
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: scene.size)))

        XCTAssertFalse(scene.children.isEmpty)
    }

    func testDeterministicReplay() {
        var first = RainlineState(seed: 77)
        var second = RainlineState(seed: 77)

        for tick in 0..<3_000 {
            let input = RainlineInput(
                move: sin(Double(tick) * 0.015),
                repairing: tick % 250 < 90,
                boostGrid: tick % 420 < 70
            )

            first.step(input: input)
            second.step(input: input)
            XCTAssertEqual(first, second)

            if first.isFinished {
                break
            }
        }
    }

    func testResourceBounds() {
        var state = RainlineState(seed: 91)

        for tick in 0..<7_000 where !state.isFinished {
            state.step(
                input: RainlineInput(
                    move: cos(Double(tick) * 0.018),
                    repairing: tick % 240 < 80,
                    boostGrid: tick % 600 < 120
                )
            )

            XCTAssertTrue((0...100).contains(state.trainPower))
            XCTAssertTrue((0...100).contains(state.traction))
            XCTAssertEqual(state.carPower.count, RainlineState.carCount)
            XCTAssertTrue(
                state.carPower.allSatisfy { (0...1).contains($0) }
            )
        }
    }

    func testFinishedStateIsImmutable() {
        var state = RainlineState(seed: 5)

        for _ in 0..<20_000 where !state.isFinished {
            state.step(
                input: RainlineInput(
                    move: 0,
                    repairing: false,
                    boostGrid: false
                )
            )
        }

        XCTAssertTrue(state.isFinished)
        let frozen = state

        state.step(
            input: RainlineInput(
                move: 1,
                repairing: true,
                boostGrid: true
            )
        )

        XCTAssertEqual(state, frozen)
    }

    func testStoryProgressesWithRoute() {
        var state = RainlineState(seed: 12)

        for _ in 0..<700 where !state.isFinished {
            state.step(
                input: RainlineInput(
                    boostGrid: true
                )
            )
        }

        XCTAssertNotNil(state.activeLine)
    }

    func testFaultGenerationIsSeedStable() {
        var first = RainlineState(seed: 123)
        var second = RainlineState(seed: 123)

        for _ in 0..<1_500 {
            first.step(input: RainlineInput())
            second.step(input: RainlineInput())
        }

        XCTAssertEqual(first.faults, second.faults)
    }

    func testFaultKindsDiversifyAcrossSeedCorpus() {
        var observed: Set<RainlineFault.Kind> = []

        for seed in UInt64(1)...UInt64(12) {
            var state = RainlineState(seed: seed)

            for _ in 0..<2_200 where !state.isFinished {
                state.step(input: RainlineInput())
            }

            observed.formUnion(state.faults.map(\.kind))
        }

        XCTAssertGreaterThanOrEqual(observed.count, 3)
    }

    func testFaultKindsRemainSeedStable() {
        var first = RainlineState(seed: 444)
        var second = RainlineState(seed: 444)

        for _ in 0..<2_200 {
            first.step(input: RainlineInput())
            second.step(input: RainlineInput())
        }

        XCTAssertEqual(
            first.faults.map(\.kind),
            second.faults.map(\.kind)
        )
    }
}
