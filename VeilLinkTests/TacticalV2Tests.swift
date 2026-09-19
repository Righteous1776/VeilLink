import XCTest
@testable import VeilLink

final class TacticalV2Tests: XCTestCase {
    private func cell(
        _ index: Int,
        width: Int,
        opacity: Int16 = 0
    ) -> TacticalV2.Cell {
        TacticalV2.Cell(
            index: index,
            row: index / width,
            col: index % width,
            terrainCode: "plain",
            movementCostMilli: 1000,
            visionOpacityPermille: opacity,
            supplyFactorPermille: 1000,
            elevationBand: 0,
            road: false
        )
    }

    func testSectorIndexUsesEighteenMacroSectors() {
        let width = 48
        let height = 27
        let map = TacticalV2.Map(
            mapID: "test",
            width: width,
            height: height,
            cells: (0..<(width * height)).map {
                cell($0, width: width)
            }
        )

        let index = TacticalV2.SectorIndexV2(map: map)
        let full = TacticalV2.NormalizedRectV2(
            minX: 0, minY: 0, maxX: 1, maxY: 1
        )

        XCTAssertEqual(index.sectors(intersecting: full).count, 18)
        XCTAssertEqual(
            index.candidateCells(
                viewport: full,
                prefetchMargin: 0
            ).count,
            1296
        )
    }

    func testRoutePlannerIsDeterministic() {
        let width = 12
        let height = 8
        let map = TacticalV2.Map(
            mapID: "route",
            width: width,
            height: height,
            cells: (0..<(width * height)).map {
                cell($0, width: width)
            }
        )

        let a = TacticalV2.RoutePlannerV2.plan(
            map: map,
            from: 0,
            to: 70
        )
        let b = TacticalV2.RoutePlannerV2.plan(
            map: map,
            from: 0,
            to: 70
        )
        XCTAssertEqual(a, b)
        XCTAssertEqual(a?.cells.first, 0)
        XCTAssertEqual(a?.cells.last, 70)
    }

    func testDragPlannerDoesNotRecomputeSameSnappedCell() {
        let width = 12
        let height = 8
        let map = TacticalV2.Map(
            mapID: "drag",
            width: width,
            height: height,
            cells: (0..<(width * height)).map {
                cell($0, width: width)
            }
        )

        var planner = TacticalV2.RouteDragPlannerV2()
        planner.begin(originCell: 0)
        _ = planner.update(targetCell: 20, map: map)
        let first = planner.recomputeCount
        _ = planner.update(targetCell: 20, map: map)

        XCTAssertEqual(planner.recomputeCount, first)
    }

    func testUnknownEnemyDoesNotEnterRedactedView() {
        let width = 12
        let height = 8
        let map = TacticalV2.Map(
            mapID: "intel",
            width: width,
            height: height,
            cells: (0..<(width * height)).map {
                cell($0, width: width)
            }
        )

        let friendly = TacticalV2.Unit(
            id: "cao",
            faction: .cao,
            kind: .infantry,
            cell: 0,
            steps: 2
        )
        let enemy = TacticalV2.Unit(
            id: "yuan",
            faction: .yuan,
            kind: .infantry,
            cell: width * height - 1,
            steps: 2
        )

        var memory = TacticalV2.IntelMemoryV2()
        var cache = TacticalV2.VisibilityCacheV2()
        let intel = memory.project(
            truthUnits: [friendly, enemy],
            map: map,
            viewer: .cao,
            simulationTurn: 0,
            visibilityCache: &cache,
            revision: .zero
        )

        let redacted = TacticalV2.RedactedTacticalViewV2(
            intel: intel
        )
        XCTAssertTrue(redacted.enemyMarkers.isEmpty)
    }

    func testWEGORejectsTamperedReveal() throws {
        let width = 6
        let height = 2
        let map = TacticalV2.Map(
            mapID: "wego",
            width: width,
            height: height,
            cells: (0..<(width * height)).map {
                cell($0, width: width)
            }
        )

        let goodOrder = TacticalV2.OrderV2(
            id: "cao-order",
            kind: .march,
            actor: .cao,
            issuedTurn: 0,
            unitID: "cao",
            routeCells: [0, 1]
        )
        let yuanOrder = TacticalV2.OrderV2(
            id: "yuan-order",
            kind: .march,
            actor: .yuan,
            issuedTurn: 0,
            unitID: "yuan",
            routeCells: [5, 4]
        )

        let caoReveal = TacticalV2.RevealV2(
            actor: .cao,
            turn: 0,
            batch: .init(orders: [goodOrder]),
            nonce: 11
        )
        let yuanReveal = TacticalV2.RevealV2(
            actor: .yuan,
            turn: 0,
            batch: .init(orders: [yuanOrder]),
            nonce: 22
        )

        var round = TacticalV2.WEGORoundV2(turn: 0)
        try round.commit(caoReveal.commitment())
        try round.commit(yuanReveal.commitment())
        try round.beginReveal()

        let tampered = TacticalV2.RevealV2(
            actor: .cao,
            turn: 0,
            batch: .init(orders: [
                TacticalV2.OrderV2(
                    id: "cao-order",
                    kind: .march,
                    actor: .cao,
                    issuedTurn: 0,
                    unitID: "cao",
                    routeCells: [0, 6]
                )
            ]),
            nonce: 11
        )

        XCTAssertThrowsError(
            try round.reveal(tampered, map: map)
        ) { error in
            XCTAssertEqual(
                error as? TacticalV2.WEGOErrorV2,
                .commitmentMismatch
            )
        }
    }

    func testPrivacyBoundaryDoesNotClaimEndpointSecrecy() {
        XCTAssertFalse(
            TacticalV2.PrivacyBoundaryV2.guaranteesEndpointSecrecy
        )
        XCTAssertTrue(
            TacticalV2.PrivacyBoundaryV2
                .guaranteesTransportConfidentialityWhenWrappedByVeilLinkE2EE
        )
    }
}
