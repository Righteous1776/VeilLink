import Foundation

extension TacticalV2 {
    enum TacticalOverlayV2: String, Codable, CaseIterable, Hashable {
        case battlefield
        case intelligence
        case supply
        case objectives
        case threat
    }

    struct MapRenderSnapshotV2: Hashable {
        struct FriendlyMarker: Hashable, Identifiable {
            let id: String
            let kind: UnitKind
            let cell: Int
            let steps: Int
        }

        struct EnemyMarker: Hashable, Identifiable {
            let id: String
            let level: IntelLevel
            let estimatedCell: Int?
            let uncertaintyRadius: UInt8
            let kindEstimate: UnitKind?
            let confidencePermille: Int16
        }

        let lod: MapLODLevelV2
        let overlay: TacticalOverlayV2
        let candidateCells: [Int]
        let visibleCells: Set<Int>
        let exploredCells: Set<Int>
        let friendlies: [FriendlyMarker]
        let enemies: [EnemyMarker]
        let supplyPermille: [Int16]
        let threatPermille: [Int16]
        let objectives: [ObjectiveMarkerV2]
    }

    enum MapRenderSnapshotBuilderV2 {
        static func build(
            map: Map,
            sectorIndex: SectorIndexV2,
            viewport: NormalizedRectV2,
            zoom: Double,
            overlay: TacticalOverlayV2,
            redacted: RedactedTacticalViewV2,
            operational: OperationalFieldV2? = nil
        ) -> MapRenderSnapshotV2 {
            let lod = MapLODLevelV2.resolve(zoom: zoom)
            let candidates = sectorIndex.candidateCells(viewport: viewport)

            func inViewport(_ cell: Int) -> Bool {
                guard let c = map.cell(cell) else { return false }
                return viewport.expanded(by: 0.03).contains(
                    MapGeometryV2.normalizedCenter(cell: c, map: map)
                )
            }

            let friendlies = redacted.friendlies
                .filter { inViewport($0.cell) }
                .map {
                    MapRenderSnapshotV2.FriendlyMarker(
                        id: $0.id,
                        kind: $0.kind,
                        cell: $0.cell,
                        steps: $0.steps
                    )
                }

            let enemies = redacted.enemyMarkers
                .filter { marker in
                    guard let cell = marker.estimatedCell else { return false }
                    return inViewport(cell)
                }
                .map {
                    MapRenderSnapshotV2.EnemyMarker(
                        id: $0.id,
                        level: $0.level,
                        estimatedCell: $0.estimatedCell,
                        uncertaintyRadius: $0.uncertaintyRadius,
                        kindEstimate: $0.kindEstimate,
                        confidencePermille: $0.confidencePermille
                    )
                }

            return MapRenderSnapshotV2(
                lod: lod,
                overlay: overlay,
                candidateCells: candidates,
                visibleCells: redacted.visibleCells,
                exploredCells: redacted.exploredCells,
                friendlies: friendlies,
                enemies: enemies,
                supplyPermille: operational?.supplyPermille
                    ?? Array(repeating: 0, count: map.cells.count),
                threatPermille: operational?.threatPermille
                    ?? Array(repeating: 0, count: map.cells.count),
                objectives: operational?.objectives ?? []
            )
        }
    }
}
