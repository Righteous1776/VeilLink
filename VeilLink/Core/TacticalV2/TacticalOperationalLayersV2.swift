import Foundation

extension TacticalV2 {
    enum ObjectiveSideV2: UInt8, Codable, Hashable {
        case neutral = 0
        case local = 1
        case contested = 2
        case enemyKnown = 3
    }

    struct ObjectiveDefinitionV2: Codable, Hashable, Identifiable {
        let id: String
        let title: String
        let cell: Int
        let radius: Int
        let value: Int
    }

    struct ObjectiveMarkerV2: Codable, Hashable, Identifiable {
        let id: String
        let title: String
        let cell: Int
        let side: ObjectiveSideV2
        let pressurePermille: Int16
        let value: Int
    }

    struct OperationalFieldV2: Codable, Hashable {
        let supplyPermille: [Int16]
        let threatPermille: [Int16]
        let objectives: [ObjectiveMarkerV2]

        func supply(at cell: Int) -> Int16 {
            guard supplyPermille.indices.contains(cell) else { return 0 }
            return supplyPermille[cell]
        }

        func threat(at cell: Int) -> Int16 {
            guard threatPermille.indices.contains(cell) else { return 0 }
            return threatPermille[cell]
        }
    }

    enum GuanduObjectivesV2 {
        static func definitions(map: Map) -> [ObjectiveDefinitionV2] {
            [
                make(
                    id: "objective-guandu",
                    title: "官渡",
                    x: 0.37, y: 0.63,
                    radius: 2, value: 4,
                    map: map
                ),
                make(
                    id: "objective-wuchao",
                    title: "乌巢",
                    x: 0.46, y: 0.53,
                    radius: 2, value: 4,
                    map: map
                ),
                make(
                    id: "objective-baima",
                    title: "白马",
                    x: 0.62, y: 0.35,
                    radius: 2, value: 3,
                    map: map
                ),
                make(
                    id: "objective-yangwu",
                    title: "阳武",
                    x: 0.30, y: 0.50,
                    radius: 2, value: 2,
                    map: map
                )
            ]
        }

        private static func make(
            id: String,
            title: String,
            x: Double,
            y: Double,
            radius: Int,
            value: Int,
            map: Map
        ) -> ObjectiveDefinitionV2 {
            ObjectiveDefinitionV2(
                id: id,
                title: title,
                cell: MapGeometryV2.nearestCell(
                    point: NormalizedPointV2(x: x, y: y),
                    map: map
                ) ?? 0,
                radius: radius,
                value: value
            )
        }
    }

    enum OperationalFieldBuilderV2 {
        static func build(
            map: Map,
            redacted: RedactedTacticalViewV2,
            supplyField: SupplyFieldV1?,
            objectives: [ObjectiveDefinitionV2]
        ) -> OperationalFieldV2 {
            let supply = buildSupply(
                map: map,
                field: supplyField
            )
            let threat = buildThreat(
                map: map,
                redacted: redacted
            )
            let markers = buildObjectives(
                map: map,
                redacted: redacted,
                definitions: objectives
            )

            return OperationalFieldV2(
                supplyPermille: supply,
                threatPermille: threat,
                objectives: markers
            )
        }

        static func playerVisibleSupplyField(
            map: Map,
            redacted: RedactedTacticalViewV2,
            revision: UInt64
        ) -> SupplyFieldV1? {
            let supplySources = Set(
                redacted.friendlies
                    .filter { $0.kind == .supply || $0.kind == .command }
                    .map(\.cell)
            )
            guard !supplySources.isEmpty else { return nil }

            // Only confirmed hostile positions are allowed to obstruct the player-visible field.
            // Suspected/partial contacts affect threat, but do not secretly use true state here.
            let confirmedBlocks = Set(
                redacted.enemyMarkers.compactMap { marker -> Int? in
                    guard marker.level == .confirmed else { return nil }
                    return marker.estimatedCell
                }
            )

            return SupplyFieldBuilderV1.build(
                map: map,
                sourceCells: supplySources,
                blockedCells: confirmedBlocks,
                revision: revision
            )
        }

        private static func buildSupply(
            map: Map,
            field: SupplyFieldV1?
        ) -> [Int16] {
            guard let field else {
                return Array(repeating: 0, count: map.cells.count)
            }

            let reachable = field.costMilli.filter {
                $0 != SupplyFieldV1.unreachable
            }
            guard let maxCost = reachable.max(), maxCost > 0 else {
                return field.costMilli.map {
                    $0 == 0 ? 1000 : 0
                }
            }

            return field.costMilli.map { cost in
                guard cost != SupplyFieldV1.unreachable else { return 0 }
                let normalized = 1.0 - min(
                    1.0,
                    Double(cost) / Double(maxCost)
                )
                return Int16(
                    max(80, min(1000, Int((normalized * 920.0 + 80.0).rounded())))
                )
            }
        }

        private static func buildThreat(
            map: Map,
            redacted: RedactedTacticalViewV2
        ) -> [Int16] {
            var values = Array(repeating: Int16(0), count: map.cells.count)

            for marker in redacted.enemyMarkers {
                guard marker.level != .unknown,
                      let origin = marker.estimatedCell else {
                    continue
                }

                let base: Int
                let radius: Int
                switch marker.level {
                case .confirmed:
                    base = 900
                    radius = 4
                case .partial:
                    base = 650
                    radius = 4
                case .suspected:
                    base = 420
                    radius = 5 + Int(marker.uncertaintyRadius)
                case .unknown:
                    continue
                }

                let candidates = VisibilityEngineV2.candidateCells(
                    around: origin,
                    range: radius,
                    map: map
                )

                for cell in candidates {
                    let distance = map.distance(origin, cell)
                    guard distance != Int.max else { continue }

                    let falloff = max(
                        0,
                        base - distance * max(70, base / max(1, radius + 1))
                    )
                    let confidenceScaled = (
                        falloff * max(150, Int(marker.confidencePermille))
                    ) / 1000

                    values[cell] = Int16(
                        min(1000, Int(values[cell]) + confidenceScaled)
                    )
                }
            }

            return values
        }

        private static func buildObjectives(
            map: Map,
            redacted: RedactedTacticalViewV2,
            definitions: [ObjectiveDefinitionV2]
        ) -> [ObjectiveMarkerV2] {
            definitions.map { definition in
                var friendlyPressure = 0
                var enemyKnownPressure = 0

                for unit in redacted.friendlies {
                    let distance = map.distance(unit.cell, definition.cell)
                    if distance <= definition.radius {
                        friendlyPressure += max(1, unit.steps)
                    }
                }

                for marker in redacted.enemyMarkers {
                    guard marker.level != .unknown,
                          let cell = marker.estimatedCell else {
                        continue
                    }
                    let distance = map.distance(cell, definition.cell)
                    if distance <= definition.radius + Int(marker.uncertaintyRadius) {
                        let weight: Int
                        switch marker.level {
                        case .confirmed: weight = 3
                        case .partial: weight = 2
                        case .suspected: weight = 1
                        case .unknown: weight = 0
                        }
                        enemyKnownPressure += weight
                    }
                }

                let side: ObjectiveSideV2
                if friendlyPressure > 0 && enemyKnownPressure > 0 {
                    side = .contested
                } else if friendlyPressure > 0 {
                    side = .local
                } else if enemyKnownPressure > 0 {
                    side = .enemyKnown
                } else {
                    side = .neutral
                }

                let total = max(1, friendlyPressure + enemyKnownPressure)
                let pressure = Int16(
                    min(
                        1000,
                        abs(friendlyPressure - enemyKnownPressure) * 1000 / total
                    )
                )

                return ObjectiveMarkerV2(
                    id: definition.id,
                    title: definition.title,
                    cell: definition.cell,
                    side: side,
                    pressurePermille: pressure,
                    value: definition.value
                )
            }
        }
    }

    struct CommandAssessmentV2: Codable, Hashable {
        enum SupplyStatus: UInt8, Codable, Hashable {
            case cut = 0
            case strained = 1
            case connected = 2
            case strong = 3
        }

        enum ExposureStatus: UInt8, Codable, Hashable {
            case low = 0
            case medium = 1
            case high = 2
            case severe = 3
        }

        let routeCells: Int
        let movementCostMilli: Int64
        let destinationSupplyPermille: Int16
        let peakThreatPermille: Int16
        let averageThreatPermille: Int16
        let supplyStatus: SupplyStatus
        let exposureStatus: ExposureStatus
        let nearestObjectiveTitle: String?
    }

    enum CommandAssessmentBuilderV2 {
        static func assess(
            route: RoutePlanV2?,
            field: OperationalFieldV2,
            objectives: [ObjectiveMarkerV2],
            map: Map
        ) -> CommandAssessmentV2? {
            guard let route,
                  let destination = route.cells.last else {
                return nil
            }

            let threats = route.cells.map {
                Int(field.threat(at: $0))
            }
            let peak = threats.max() ?? 0
            let average = threats.isEmpty
                ? 0
                : threats.reduce(0, +) / threats.count

            let supply = field.supply(at: destination)

            let supplyStatus: CommandAssessmentV2.SupplyStatus
            switch supply {
            case 0..<180: supplyStatus = .cut
            case 180..<420: supplyStatus = .strained
            case 420..<760: supplyStatus = .connected
            default: supplyStatus = .strong
            }

            let exposure: CommandAssessmentV2.ExposureStatus
            switch peak {
            case 0..<250: exposure = .low
            case 250..<500: exposure = .medium
            case 500..<760: exposure = .high
            default: exposure = .severe
            }

            let nearestObjective = objectives.min { lhs, rhs in
                map.distance(destination, lhs.cell)
                    < map.distance(destination, rhs.cell)
            }

            return CommandAssessmentV2(
                routeCells: route.cells.count,
                movementCostMilli: route.totalCostMilli,
                destinationSupplyPermille: supply,
                peakThreatPermille: Int16(peak),
                averageThreatPermille: Int16(average),
                supplyStatus: supplyStatus,
                exposureStatus: exposure,
                nearestObjectiveTitle: nearestObjective?.title
            )
        }
    }
}
