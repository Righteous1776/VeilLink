import XCTest
@testable import VeilLink

final class TacticalSoloV2Tests: XCTestCase {
    func testSoloRuntimeResolvesDeterministicallyAndAdvancesBothSides() throws {
        let width = 4
        let height = 4
        let cells = (0..<(width * height)).map { index in
            TacticalV2.Cell(
                index: index,
                row: index / width,
                col: index % width,
                terrainCode: "plain",
                movementCostMilli: 1000,
                visionOpacityPermille: 0,
                supplyFactorPermille: 1000,
                elevationBand: 0,
                road: index.isMultiple(of: 3)
            )
        }
        let map = TacticalV2.Map(
            mapID: "solo-test",
            width: width,
            height: height,
            cells: cells
        )
        let state = TacticalV2.TruthStateV2(
            scenarioID: "solo-test",
            mapID: map.mapID,
            rulesVersion: 2,
            scenarioVersion: 1,
            seed: 42,
            units: [
                TacticalV2.Unit(
                    id: "cao-command",
                    faction: .cao,
                    kind: .command,
                    cell: 12,
                    steps: 2
                ),
                TacticalV2.Unit(
                    id: "yuan-command",
                    faction: .yuan,
                    kind: .command,
                    cell: 0,
                    steps: 2
                )
            ],
            revision: TacticalV2.Revision(
                map: 1,
                terrain: 1,
                unit: 1,
                supply: 1
            )
        )

        let human = TacticalV2.OrderV2(
            id: "human-0",
            kind: .march,
            actor: .cao,
            issuedTurn: 0,
            unitID: "cao-command",
            routeCells: [12, 8]
        )

        let a = try TacticalV2.SoloRuntimeV2.resolveTurn(
            state: state,
            map: map,
            humanOrder: human
        )
        let b = try TacticalV2.SoloRuntimeV2.resolveTurn(
            state: state,
            map: map,
            humanOrder: human
        )

        XCTAssertEqual(a.state, b.state)
        XCTAssertEqual(a.frame, b.frame)
        XCTAssertEqual(a.botOrder, b.botOrder)
        XCTAssertEqual(a.state.simulationTurn, 1)
        XCTAssertEqual(a.state.unit(id: "cao-command")?.cell, 8)
        XCTAssertNotEqual(a.state.unit(id: "yuan-command")?.cell, 0)
    }

    func testSoloBotNeverCreatesNonContiguousRoute() throws {
        let width = 6
        let height = 6
        let map = TacticalV2.Map(
            mapID: "solo-bot",
            width: width,
            height: height,
            cells: (0..<(width * height)).map { index in
                TacticalV2.Cell(
                    index: index,
                    row: index / width,
                    col: index % width,
                    terrainCode: "plain",
                    movementCostMilli: 1000,
                    visionOpacityPermille: 0,
                    supplyFactorPermille: 1000,
                    elevationBand: 0,
                    road: false
                )
            }
        )
        let state = TacticalV2.TruthStateV2(
            scenarioID: "solo-bot",
            mapID: map.mapID,
            rulesVersion: 2,
            scenarioVersion: 1,
            seed: 7,
            units: [
                TacticalV2.Unit(id: "cao", faction: .cao, kind: .command, cell: 30, steps: 2),
                TacticalV2.Unit(id: "yuan", faction: .yuan, kind: .cavalry, cell: 0, steps: 2)
            ]
        )

        let order = TacticalV2.SoloRuntimeV2.makeBotOrder(
            state: state,
            map: map,
            actor: .yuan
        )

        XCTAssertEqual(order.actor, .yuan)
        XCTAssertEqual(order.issuedTurn, 0)
        try order.validate(map: map)
        if order.routeCells.count == 2 {
            XCTAssertTrue(
                map.neighbors(of: Int(order.routeCells[0]))
                    .contains(Int(order.routeCells[1]))
            )
        }
    }
}
