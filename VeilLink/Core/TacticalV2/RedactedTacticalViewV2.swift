import Foundation

extension TacticalV2 {
    struct RedactedTacticalViewV2: Codable, Hashable {
        struct FriendlyFormation: Codable, Hashable, Identifiable {
            let id: String
            let kind: UnitKind
            let cell: Int
            let steps: Int
        }

        struct EnemyMarker: Codable, Hashable, Identifiable {
            let id: String
            let level: IntelLevel
            let estimatedCell: Int?
            let uncertaintyRadius: UInt8
            let kindEstimate: UnitKind?
            let stepsEstimate: Int?
            let confidencePermille: Int16
            let lastObservedTurn: Int32
        }

        let viewer: Faction
        let visibleCells: Set<Int>
        let exploredCells: Set<Int>
        let friendlies: [FriendlyFormation]
        let enemyMarkers: [EnemyMarker]

        init(intel: PlayerIntelState) {
            viewer = intel.viewer
            visibleCells = intel.visibleCells
            exploredCells = intel.exploredCells
            friendlies = intel.friendlyUnits.map {
                FriendlyFormation(
                    id: $0.id,
                    kind: $0.kind,
                    cell: $0.cell,
                    steps: $0.steps
                )
            }
            enemyMarkers = intel.contacts.map {
                EnemyMarker(
                    id: $0.contactID,
                    level: $0.level,
                    estimatedCell: $0.estimatedCell,
                    uncertaintyRadius: $0.uncertaintyRadius,
                    kindEstimate: $0.kindEstimate,
                    stepsEstimate: $0.stepsEstimate,
                    confidencePermille: $0.confidencePermille,
                    lastObservedTurn: $0.lastObservedTurn
                )
            }
        }
    }
}
