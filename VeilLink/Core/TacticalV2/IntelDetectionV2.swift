import Foundation

extension TacticalV2 {
    struct DetectionResultV2: Hashable {
        let level: IntelLevel
        let confidencePermille: Int16
    }

    enum IntelDetectionV2 {
        static func observe(
            enemy: Unit,
            friendlies: [Unit],
            visibleCells: Set<Int>,
            map: Map
        ) -> DetectionResultV2 {
            guard visibleCells.contains(enemy.cell) else {
                return DetectionResultV2(level: .unknown, confidencePermille: 0)
            }

            let nearest = friendlies
                .map { map.distance($0.cell, enemy.cell) }
                .min() ?? Int.max

            guard nearest != Int.max else {
                return DetectionResultV2(level: .unknown, confidencePermille: 0)
            }

            let terrain = map.cell(enemy.cell)
            let obscurity = Int(terrain?.visionOpacityPermille ?? 0)

            // Close contact becomes confirmed unless the target sits in very dense concealment.
            if nearest <= 1 {
                if obscurity >= 800 {
                    return DetectionResultV2(level: .partial, confidencePermille: 780)
                }
                return DetectionResultV2(level: .confirmed, confidencePermille: 1000)
            }

            // Mid-range: terrain reduces identification quality without altering LOS itself.
            if nearest <= 3 {
                if obscurity >= 600 {
                    return DetectionResultV2(level: .suspected, confidencePermille: 420)
                }
                return DetectionResultV2(level: .partial, confidencePermille: 700)
            }

            // Long-range LOS exposes presence, but not reliable unit classification.
            if obscurity >= 450 {
                return DetectionResultV2(level: .suspected, confidencePermille: 300)
            }
            return DetectionResultV2(level: .suspected, confidencePermille: 380)
        }

        static func contactID(
            viewer: Faction,
            sourceKey: UInt64
        ) -> String {
            let value = StableHash64.fnv1a("contact|\(viewer.rawValue)|\(sourceKey)")
            return "C" + String(value, radix: 16)
        }
    }

    enum IntelDecayV2 {
        static func decay(
            _ contact: IntelContact,
            toTurn turn: Int32
        ) -> IntelContact {
            guard turn > contact.lastObservedTurn else { return contact }
            let age = Int(turn - contact.lastObservedTurn)

            var next = contact

            if age >= 7 {
                next.level = .unknown
                next.estimatedCell = nil
                next.uncertaintyRadius = 0
                next.kindEstimate = nil
                next.stepsEstimate = nil
                next.confidencePermille = 0
                return next
            }

            if age >= 3 {
                next.level = .suspected
                next.kindEstimate = nil
                next.stepsEstimate = nil
                next.uncertaintyRadius = UInt8(min(6, 2 + age / 2))
                next.confidencePermille = Int16(max(200, 520 - age * 45))
                return next
            }

            // age 1...2
            if contact.level == .confirmed {
                next.level = .partial
            } else if contact.level == .partial {
                next.level = .suspected
            }
            next.stepsEstimate = nil
            next.uncertaintyRadius = UInt8(min(3, age))
            next.confidencePermille = Int16(max(300, Int(contact.confidencePermille) - age * 180))
            return next
        }
    }
}
