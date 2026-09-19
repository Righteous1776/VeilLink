import Foundation

extension TacticalV2 {
    enum GuanduScenarioV2 {
        static let scenarioID = "guandu-campaign-v2"
        static let rulesVersion: UInt16 = 2
        static let scenarioVersion: UInt16 = 1

        static func deterministicSeed(sessionID: String) -> UInt64 {
            StableHash64.fnv1a("guandu-v2|\(sessionID)")
        }

        static func initialTruthState(
            map: Map,
            seed: UInt64
        ) -> TruthStateV2 {
            let units: [Unit] = [
                Unit(id: "cao-command", faction: .cao, kind: .command,
                     cell: nearest(map, x: 0.37, y: 0.63), steps: 2),
                Unit(id: "cao-infantry-l", faction: .cao, kind: .infantry,
                     cell: nearest(map, x: 0.32, y: 0.67), steps: 2),
                Unit(id: "cao-infantry-r", faction: .cao, kind: .infantry,
                     cell: nearest(map, x: 0.42, y: 0.66), steps: 2),
                Unit(id: "cao-cavalry", faction: .cao, kind: .cavalry,
                     cell: nearest(map, x: 0.29, y: 0.60), steps: 2),
                Unit(id: "cao-ranged", faction: .cao, kind: .ranged,
                     cell: nearest(map, x: 0.39, y: 0.72), steps: 2),
                Unit(id: "cao-supply", faction: .cao, kind: .supply,
                     cell: nearest(map, x: 0.31, y: 0.80), steps: 1),

                Unit(id: "yuan-command", faction: .yuan, kind: .command,
                     cell: nearest(map, x: 0.49, y: 0.39), steps: 2),
                Unit(id: "yuan-infantry-l", faction: .yuan, kind: .infantry,
                     cell: nearest(map, x: 0.41, y: 0.45), steps: 2),
                Unit(id: "yuan-infantry-r", faction: .yuan, kind: .infantry,
                     cell: nearest(map, x: 0.56, y: 0.44), steps: 2),
                Unit(id: "yuan-cavalry", faction: .yuan, kind: .cavalry,
                     cell: nearest(map, x: 0.62, y: 0.35), steps: 2),
                Unit(id: "yuan-ranged", faction: .yuan, kind: .ranged,
                     cell: nearest(map, x: 0.47, y: 0.31), steps: 2),
                Unit(id: "yuan-supply", faction: .yuan, kind: .supply,
                     cell: nearest(map, x: 0.46, y: 0.53), steps: 1)
            ]

            return TruthStateV2(
                scenarioID: scenarioID,
                mapID: map.mapID,
                rulesVersion: rulesVersion,
                scenarioVersion: scenarioVersion,
                seed: seed,
                units: units,
                revision: Revision(map: 1, terrain: 1, unit: 1, supply: 1)
            )
        }

        private static func nearest(
            _ map: Map,
            x: Double,
            y: Double
        ) -> Int {
            MapGeometryV2.nearestCell(
                point: NormalizedPointV2(x: x, y: y),
                map: map
            ) ?? 0
        }
    }
}
