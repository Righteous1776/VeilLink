import XCTest
@testable import VeilLink

final class BlackoutDistrictGameTests: XCTestCase {
    func testDeterministicReplay() {
        var first =
            BlackoutDistrictState(
                seed: 77
            )

        var second =
            BlackoutDistrictState(
                seed: 77
            )

        for tick in 0..<4_000 {
            let input =
                BlackoutInput(
                    throttle:
                        sin(
                            Double(tick) *
                            0.013
                        ),
                    steering:
                        cos(
                            Double(tick) *
                            0.017
                        ) * 0.75,
                    repairing:
                        tick % 240 < 80
                )

            first.step(
                input: input
            )

            second.step(
                input: input
            )

            XCTAssertEqual(
                first,
                second
            )

            if first.isFinished {
                break
            }
        }
    }

    func testGridMetricsStayBounded() {
        var state =
            BlackoutDistrictState(
                seed: 19
            )

        for tick in 0..<5_000
        where !state.isFinished {
            state.step(
                input:
                    BlackoutInput(
                        throttle:
                            tick % 400 < 250
                            ? 0.7
                            : -0.2,
                        steering:
                            sin(
                                Double(tick) *
                                0.021
                            ),
                        repairing:
                            false
                    )
            )

            let snapshot =
                state.snapshot()

            XCTAssertTrue(
                (0...1)
                    .contains(
                        snapshot.gridStability
                    )
            )

            XCTAssertTrue(
                (0...snapshot.totalNodes)
                    .contains(
                        snapshot.poweredNodes
                    )
            )

            XCTAssertTrue(
                (0...snapshot.totalBuildings)
                    .contains(
                        snapshot.litBuildings
                    )
            )

            XCTAssertGreaterThanOrEqual(
                snapshot.timeRemaining,
                0
            )
        }
    }

    func testStormEventuallyCreatesFaults() {
        var state =
            BlackoutDistrictState(
                seed: 5
            )

        var observedFault = false

        for _ in 0..<8_000
        where !state.isFinished {
            state.step(
                input:
                    BlackoutInput()
            )

            if state.snapshot().activeFaults > 0 {
                observedFault = true
                break
            }
        }

        XCTAssertTrue(
            observedFault
        )
    }

    func testDifferentSeedsDivergeUnderStorm() {
        var first =
            BlackoutDistrictState(
                seed: 1
            )

        var second =
            BlackoutDistrictState(
                seed: 2
            )

        for _ in 0..<2_000 {
            first.step(
                input:
                    BlackoutInput()
            )

            second.step(
                input:
                    BlackoutInput()
            )
        }

        XCTAssertNotEqual(
            first.nodes,
            second.nodes
        )
    }

    func testTimeExpiryFreezesState() {
        var state =
            BlackoutDistrictState(
                seed: 101
            )

        for _ in 0...BlackoutDistrictState.timeLimitTicks
        where !state.isFinished {
            state.step(
                input:
                    BlackoutInput()
            )
        }

        XCTAssertNotEqual(
            state.outcome,
            .running
        )

        let frozen = state

        state.step(
            input:
                BlackoutInput(
                    throttle: 1,
                    steering: 1,
                    repairing: true
                )
        )

        XCTAssertEqual(
            state,
            frozen
        )
    }

    func testInitialCityHasAllDeclaredBuildings() {
        let state =
            BlackoutDistrictState(
                seed: 42
            )

        let snapshot =
            state.snapshot()

        XCTAssertEqual(
            snapshot.totalNodes,
            9
        )

        XCTAssertEqual(
            snapshot.totalBuildings,
            state.nodes.reduce(0) {
                $0 + $1.buildingCount
            }
        )

        XCTAssertGreaterThan(
            snapshot.totalBuildings,
            90
        )
    }
}
