import XCTest
@testable import VeilLink

final class SignalDiveGameTests: XCTestCase {
    func testDeterministicReplay() {
        var first =
            SignalDiveState(
                seed: 88
            )

        var second =
            SignalDiveState(
                seed: 88
            )

        for tick in 0..<3_000 {
            let input =
                SignalDiveInput(
                    thrustX:
                        sin(
                            Double(tick) *
                            0.013
                        ),
                    thrustY:
                        cos(
                            Double(tick) *
                            0.017
                        ) * 0.7,
                    sonarPulse:
                        tick % 190 == 0,
                    floodlight:
                        tick % 240 < 160
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

    func testResourcesStayBounded() {
        var state =
            SignalDiveState(
                seed: 91
            )

        for tick in 0..<4_000
        where !state.isFinished {
            state.step(
                input:
                    SignalDiveInput(
                        thrustX:
                            sin(
                                Double(tick) *
                                0.011
                            ),
                        thrustY:
                            cos(
                                Double(tick) *
                                0.009
                            ),
                        sonarPulse:
                            tick % 210 == 0,
                        floodlight:
                            tick % 300 < 190
                    )
            )

            let snapshot =
                state.snapshot()

            XCTAssertTrue(
                (0...100)
                    .contains(
                        snapshot.hull
                    )
            )

            XCTAssertTrue(
                (0...100)
                    .contains(
                        snapshot.power
                    )
            )

            XCTAssertTrue(
                (0...1)
                    .contains(
                        snapshot.noise
                    )
            )

            XCTAssertGreaterThanOrEqual(
                snapshot.pressure,
                0
            )
        }
    }

    func testSonarConsumesPowerAndCreatesCooldown() {
        var state =
            SignalDiveState(
                seed: 12
            )

        let before =
            state.power

        state.step(
            input:
                SignalDiveInput(
                    sonarPulse: true,
                    floodlight: false
                )
        )

        XCTAssertLessThan(
            state.power,
            before
        )

        XCTAssertGreaterThan(
            state
                .snapshot()
                .sonarCooldown,
            0
        )

        XCTAssertTrue(
            state.events.contains {
                if case .sonar =
                    $0.kind {
                    return true
                }

                return false
            }
        )
    }

    func testSonarContactsAreStableForSameState() {
        let state =
            SignalDiveState(
                seed: 24
            )

        XCTAssertEqual(
            state.sonarContacts(),
            state.sonarContacts()
        )
    }

    func testBeaconRecoveryAtLowSpeed() {
        let level =
            SignalDiveLevel(
                length: 600,
                maxDepth: 800,
                beacons: [
                    .init(
                        id: 1,
                        x: 120,
                        depth: 260,
                        captureRadius: 100,
                        line: "test"
                    )
                ],
                obstacles: []
            )

        var state =
            SignalDiveState(
                seed: 1,
                level: level
            )

        state.step(
            input:
                SignalDiveInput(
                    floodlight: false
                )
        )

        XCTAssertEqual(
            state
                .snapshot()
                .recovered,
            1
        )

        XCTAssertEqual(
            state
                .snapshot()
                .lastLine,
            "控制台：四个信标都在。现在把它们带回有光的地方。"
        )
    }

    func testHullFailureFreezesState() {
        let level =
            SignalDiveLevel(
                length: 600,
                maxDepth: 800,
                beacons: [],
                obstacles: [
                    .init(
                        id: 1,
                        x: 120,
                        depth: 260,
                        radius: 120,
                        damage: 150
                    )
                ]
            )

        var state =
            SignalDiveState(
                seed: 2,
                level: level
            )

        state.step(
            input:
                SignalDiveInput(
                    floodlight: false
                )
        )

        XCTAssertEqual(
            state.outcome,
            .hullFailure
        )

        let frozen = state

        state.step(
            input:
                SignalDiveInput(
                    thrustX: 1,
                    thrustY: 1,
                    sonarPulse: true,
                    floodlight: true
                )
        )

        XCTAssertEqual(
            state,
            frozen
        )
    }

    func testDifferentSeedsChangeUnknownEchoField() {
        var first =
            SignalDiveState(
                seed: 1
            )

        var second =
            SignalDiveState(
                seed: 2
            )

        for _ in 0..<1_000 {
            first.step(
                input:
                    SignalDiveInput(
                        thrustX: 0.8,
                        floodlight: false
                    )
            )

            second.step(
                input:
                    SignalDiveInput(
                        thrustX: 0.8,
                        floodlight: false
                    )
            )
        }

        XCTAssertNotEqual(
            first
                .sonarContacts()
                .filter {
                    if case .massiveUnknown =
                        $0.kind {
                        return true
                    }

                    return false
                },
            second
                .sonarContacts()
                .filter {
                    if case .massiveUnknown =
                        $0.kind {
                        return true
                    }

                    return false
                }
        )
    }
}
