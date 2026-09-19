import Foundation

extension TacticalV2 {
    struct CombatForecastV2: Codable, Hashable {
        enum Confidence: UInt8, Codable, Hashable {
            case low = 0
            case medium = 1
            case high = 2
        }

        enum Balance: Int8, Codable, Hashable {
            case unfavorable = -1
            case uncertain = 0
            case favorable = 1
        }

        let balance: Balance
        let confidence: Confidence
        let friendlyStrengthBand: Int
        let enemyStrengthBand: Int?
        let terrainResistance: Int
        let noteCode: UInt8
    }

    enum CombatForecastEngineV2 {
        static func forecast(
            friendly: RedactedTacticalViewV2.FriendlyFormation,
            contact: RedactedTacticalViewV2.EnemyMarker,
            map: Map
        ) -> CombatForecastV2? {
            guard contact.level != .unknown,
                  let enemyCell = contact.estimatedCell,
                  let terrain = map.cell(enemyCell) else {
                return nil
            }

            let friendlyBand = baseStrength(
                kind: friendly.kind,
                steps: friendly.steps
            )

            let enemyBand: Int?
            if let steps = contact.stepsEstimate,
               let kind = contact.kindEstimate {
                enemyBand = baseStrength(
                    kind: kind,
                    steps: steps
                )
            } else if contact.level >= .partial,
                      let kind = contact.kindEstimate {
                enemyBand = baseStrength(
                    kind: kind,
                    steps: 2
                )
            } else {
                enemyBand = nil
            }

            let resistance = terrainResistance(terrain.terrainCode)
            let confidence: CombatForecastV2.Confidence
            switch contact.level {
            case .confirmed: confidence = .high
            case .partial: confidence = .medium
            case .suspected, .unknown: confidence = .low
            }

            let balance: CombatForecastV2.Balance
            if let enemyBand {
                let adjustedEnemy = enemyBand + resistance
                if friendlyBand >= adjustedEnemy + 2 {
                    balance = .favorable
                } else if adjustedEnemy >= friendlyBand + 2 {
                    balance = .unfavorable
                } else {
                    balance = .uncertain
                }
            } else {
                balance = .uncertain
            }

            return CombatForecastV2(
                balance: balance,
                confidence: confidence,
                friendlyStrengthBand: friendlyBand,
                enemyStrengthBand: enemyBand,
                terrainResistance: resistance,
                noteCode: enemyBand == nil ? 1 : 0
            )
        }

        private static func baseStrength(
            kind: UnitKind,
            steps: Int
        ) -> Int {
            let base: Int
            switch kind {
            case .command: base = 2
            case .infantry: base = 3
            case .cavalry: base = 4
            case .ranged: base = 3
            case .supply: base = 1
            }
            return base + max(0, steps - 1)
        }

        private static func terrainResistance(
            _ code: String
        ) -> Int {
            switch code {
            case "fortified": return 3
            case "forest": return 2
            case "wetland": return 2
            case "riverbank": return 1
            default: return 0
            }
        }
    }
}
