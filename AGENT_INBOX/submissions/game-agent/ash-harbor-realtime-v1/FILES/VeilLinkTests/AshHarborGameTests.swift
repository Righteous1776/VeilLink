import XCTest
@testable import VeilLink

final class AshHarborGameTests: XCTestCase {
    func testIdenticalInputStreamIsDeterministic() {
        var first = AshHarborState(seed: 44)
        var second = AshHarborState(seed: 44)

        for tick in 0..<2_500 {
            let input = AshHarborInput(
                throttle: tick % 500 < 90 ? 0.25 : 0.72,
                rudder: sin(Double(tick) * 0.019),
                rescuing: tick % 260 < 80,
                searchlight: tick % 180 < 120
            )

            first.step(input: input)
            second.step(input: input)
            XCTAssertEqual(first, second)

            if first.isFinished {
                break
            }
        }
    }

    func testResourcesStayBounded() {
        var state = AshHarborState(seed: 91)

        for tick in 0..<4_000 where !state.isFinished {
            state.step(
                input: AshHarborInput(
                    throttle: 0.7,
                    rudder: cos(Double(tick) * 0.022),
                    rescuing: false,
                    searchlight: tick % 90 < 50
                )
            )

            let snapshot = state.snapshot()
            XCTAssertTrue((0...100).contains(snapshot.hull))
            XCTAssertTrue((0...100).contains(snapshot.battery))
        }
    }

    func testRescueRequiresLowSpeedAndHold() {
        let site = AshHarborRescueSite(
            id: 1,
            x: 120,
            y: 430,
            holdTicks: 4,
            radioLine: "test"
        )

        let level = AshHarborLevel(
            name: "test",
            worldLength: 600,
            timeLimitTicks: 600,
            rescueSites: [site],
            debris: []
        )

        var state = AshHarborState(seed: 1, level: level)

        for _ in 0..<6 {
            state.step(
                input: AshHarborInput(
                    throttle: 0,
                    rudder: 0,
                    rescuing: true,
                    searchlight: false
                )
            )
        }

        XCTAssertEqual(state.snapshot().rescued, 1)
    }

    func testFinishedStateDoesNotAdvance() {
        let level = AshHarborLevel(
            name: "short",
            worldLength: 100,
            timeLimitTicks: 5_000,
            rescueSites: [],
            debris: []
        )

        var state = AshHarborState(seed: 2, level: level)

        for _ in 0..<600 where !state.isFinished {
            state.step(
                input: AshHarborInput(
                    throttle: 1,
                    rudder: 0,
                    rescuing: false,
                    searchlight: false
                )
            )
        }

        XCTAssertEqual(state.outcome, .reachedHarbor)

        let frozen = state
        state.step(
            input: AshHarborInput(
                throttle: 0,
                rudder: 1,
                rescuing: true,
                searchlight: true
            )
        )
        XCTAssertEqual(state, frozen)
    }

    func testSearchlightConsumesBattery() {
        var lit = AshHarborState(seed: 7)
        var dark = AshHarborState(seed: 7)

        for _ in 0..<300 {
            lit.step(input: AshHarborInput(searchlight: true))
            dark.step(input: AshHarborInput(searchlight: false))
        }

        XCTAssertLessThan(lit.battery, dark.battery)
    }
}
