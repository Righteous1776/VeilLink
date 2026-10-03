import XCTest
@testable import VeilLink

final class LocalGameMissionTests: XCTestCase {
    func testMissionSelectionIsDeterministicPerSession() {
        let games = MiniGameKind.allCases
        for game in games {
            let first = LocalGameMissionDirector.mission(
                for: game,
                sessionID: "mission-determinism-session"
            )
            let second = LocalGameMissionDirector.mission(
                for: game,
                sessionID: "mission-determinism-session"
            )
            XCTAssertEqual(first, second)
            XCTAssertFalse(first.code.isEmpty)
            XCTAssertFalse(first.title.isEmpty)
            XCTAssertFalse(first.detail.isEmpty)
        }
    }

    func testArtilleryMissionProgressReadsResolvedState() throws {
        let sessionID = "mission-artillery-test"
        var state = ArtilleryState()
        let move = try XCTUnwrap(
            ArtilleryBot.chooseShot(in: state, actor: .host, sessionID: sessionID)
        )
        XCTAssertTrue(
            state.apply(
                angle: move.angle,
                power: move.power,
                actor: .host,
                sessionID: sessionID
            )
        )

        let snapshot = makeSnapshot(
            id: sessionID,
            game: .artillery,
            artillery: state
        )
        let mission = LocalGameMission(
            code: "WIND_READ",
            title: "读风校射",
            detail: "test",
            systemImage: "wind"
        )
        let progress = LocalGameMissionEvaluator.progress(
            for: mission,
            session: snapshot
        )

        XCTAssertGreaterThanOrEqual(progress.fraction, 0.45)
        XCTAssertLessThanOrEqual(progress.fraction, 1)
        XCTAssertNotEqual(progress.label, "等待第一步操作")
    }

    func testTacticalMissionProgressIsBoundedAndReadOnly() {
        let state = TacticalState()
        let snapshot = makeSnapshot(
            id: "mission-tactical-test",
            game: .tactical,
            tactical: state
        )
        let mission = LocalGameMission(
            code: "SUPPLY_FIRST",
            title: "粮道优先",
            detail: "test",
            systemImage: "shippingbox.fill"
        )
        let before = state
        let progress = LocalGameMissionEvaluator.progress(
            for: mission,
            session: snapshot
        )

        XCTAssertGreaterThanOrEqual(progress.fraction, 0)
        XCTAssertLessThanOrEqual(progress.fraction, 1)
        XCTAssertEqual(state, before)
    }

    private func makeSnapshot(
        id: String,
        game: MiniGameKind,
        tactical: TacticalState? = nil,
        artillery: ArtilleryState? = nil
    ) -> MiniGameSessionSnapshot {
        MiniGameSessionSnapshot(
            id: id,
            game: game,
            hostIsLocal: true,
            status: .active,
            invitedAt: Date(timeIntervalSince1970: 1),
            startedAt: Date(timeIntervalSince1970: 2),
            lastActivity: Date(timeIntervalSince1970: 3),
            gomoku: game == .gomoku ? GomokuState() : nil,
            xiangqi: game == .xiangqi ? XiangqiState() : nil,
            ludo: game == .ludo ? LudoState() : nil,
            tactical: tactical,
            artillery: artillery,
            lightTrail: game == .lightTrail ? LightTrailState() : nil,
            magneticHockey: game == .magneticHockey ? MagneticHockeyState() : nil,
            endedByResignation: false
        )
    }
}
