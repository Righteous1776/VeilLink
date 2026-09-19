import Foundation

extension TacticalV2 {
    struct LOSResult: Codable, Hashable {
        let visible: Bool
        let line: [Int]
        let accumulatedOpacityPermille: Int
        let blockedByCell: Int?
    }

    struct VisibilityProfile: Codable, Hashable {
        let range: Int
        let opacityBudgetPermille: Int
        let elevationClearanceBands: Int16

        static func standard(for kind: UnitKind) -> VisibilityProfile {
            switch kind {
            case .cavalry:
                return VisibilityProfile(range: 7, opacityBudgetPermille: 750, elevationClearanceBands: 1)
            case .ranged:
                return VisibilityProfile(range: 6, opacityBudgetPermille: 700, elevationClearanceBands: 1)
            case .command:
                return VisibilityProfile(range: 5, opacityBudgetPermille: 700, elevationClearanceBands: 1)
            case .infantry:
                return VisibilityProfile(range: 4, opacityBudgetPermille: 650, elevationClearanceBands: 1)
            case .supply:
                return VisibilityProfile(range: 3, opacityBudgetPermille: 550, elevationClearanceBands: 0)
            }
        }
    }

    enum VisibilityEngineV2 {
        private static func roundNearest(_ numerator: Int, _ denominator: Int) -> Int {
            precondition(denominator > 0)
            if numerator >= 0 {
                return (numerator + denominator / 2) / denominator
            } else {
                return -((-numerator + denominator / 2) / denominator)
            }
        }

        private static func interpolatedCube(
            from a: Cube,
            to b: Cube,
            step: Int,
            steps: Int
        ) -> Cube {
            if steps == 0 { return a }

            let xn = a.x * (steps - step) + b.x * step
            let yn = a.y * (steps - step) + b.y * step
            let zn = a.z * (steps - step) + b.z * step

            var rx = roundNearest(xn, steps)
            var ry = roundNearest(yn, steps)
            var rz = roundNearest(zn, steps)

            let dx = abs(rx * steps - xn)
            let dy = abs(ry * steps - yn)
            let dz = abs(rz * steps - zn)

            if dx >= dy && dx >= dz {
                rx = -ry - rz
            } else if dy >= dz {
                ry = -rx - rz
            } else {
                rz = -rx - ry
            }

            return Cube(x: rx, y: ry, z: rz)
        }

        static func lineCells(
            from start: Int,
            to end: Int,
            map: Map
        ) -> [Int] {
            guard let a = map.cube(of: start), let b = map.cube(of: end) else { return [] }
            let distance = map.distance(start, end)
            guard distance != Int.max else { return [] }
            if distance == 0 { return [start] }

            var result: [Int] = []
            result.reserveCapacity(distance + 1)

            for step in 0...distance {
                let cube = interpolatedCube(from: a, to: b, step: step, steps: distance)
                if let index = map.index(of: cube), result.last != index {
                    result.append(index)
                }
            }
            return result
        }

        static func lineOfSight(
            from observer: Int,
            to target: Int,
            map: Map,
            profile: VisibilityProfile
        ) -> LOSResult {
            let distance = map.distance(observer, target)
            guard distance <= profile.range,
                  let observerCell = map.cell(observer),
                  let targetCell = map.cell(target) else {
                return LOSResult(
                    visible: false,
                    line: [],
                    accumulatedOpacityPermille: 0,
                    blockedByCell: nil
                )
            }

            let line = lineCells(from: observer, to: target, map: map)
            guard !line.isEmpty else {
                return LOSResult(
                    visible: false,
                    line: [],
                    accumulatedOpacityPermille: 0,
                    blockedByCell: nil
                )
            }

            let elevationCeiling = max(observerCell.elevationBand, targetCell.elevationBand)
                + profile.elevationClearanceBands

            var opacity = 0

            // Intermediate cells block/attenuate; target terrain itself should not make the
            // target impossible to see simply because it occupies concealment terrain.
            if line.count > 2 {
                for index in line.dropFirst().dropLast() {
                    guard let cell = map.cell(index) else { continue }

                    if cell.elevationBand > elevationCeiling {
                        return LOSResult(
                            visible: false,
                            line: line,
                            accumulatedOpacityPermille: opacity,
                            blockedByCell: index
                        )
                    }

                    opacity += Int(max(0, cell.visionOpacityPermille))
                    if opacity > profile.opacityBudgetPermille {
                        return LOSResult(
                            visible: false,
                            line: line,
                            accumulatedOpacityPermille: opacity,
                            blockedByCell: index
                        )
                    }
                }
            }

            return LOSResult(
                visible: true,
                line: line,
                accumulatedOpacityPermille: opacity,
                blockedByCell: nil
            )
        }

        static func candidateCells(
            around origin: Int,
            range: Int,
            map: Map
        ) -> Set<Int> {
            guard map.cell(origin) != nil else { return [] }
            var visited: Set<Int> = [origin]
            var frontier: [(Int, Int)] = [(origin, 0)]
            var head = 0

            while head < frontier.count {
                let (current, depth) = frontier[head]
                head += 1
                guard depth < range else { continue }

                for next in map.neighbors(of: current) where !visited.contains(next) {
                    visited.insert(next)
                    frontier.append((next, depth + 1))
                }
            }
            return visited
        }

        static func visibleCells(
            from observer: Int,
            map: Map,
            profile: VisibilityProfile
        ) -> Set<Int> {
            let candidates = candidateCells(around: observer, range: profile.range, map: map)
            var visible: Set<Int> = []
            visible.reserveCapacity(candidates.count)

            for target in candidates.sorted() {
                if lineOfSight(from: observer, to: target, map: map, profile: profile).visible {
                    visible.insert(target)
                }
            }
            return visible
        }
    }

    struct VisibilityCacheKey: Hashable {
        let observerCell: Int
        let profile: VisibilityProfile
        let mapRevision: UInt64
        let terrainRevision: UInt64
    }

    struct VisibilityCacheV2 {
        private var entries: [String: (VisibilityCacheKey, Set<Int>)] = [:]
        private(set) var recomputeCount: Int = 0

        mutating func visibleCells(
            observerID: String,
            observerCell: Int,
            map: Map,
            profile: VisibilityProfile,
            revision: Revision
        ) -> Set<Int> {
            let key = VisibilityCacheKey(
                observerCell: observerCell,
                profile: profile,
                mapRevision: revision.map,
                terrainRevision: revision.terrain
            )

            if let cached = entries[observerID], cached.0 == key {
                return cached.1
            }

            let value = VisibilityEngineV2.visibleCells(
                from: observerCell,
                map: map,
                profile: profile
            )
            entries[observerID] = (key, value)
            recomputeCount += 1
            return value
        }

        mutating func invalidate(observerID: String) {
            entries.removeValue(forKey: observerID)
        }

        mutating func removeAll() {
            entries.removeAll(keepingCapacity: true)
        }
    }
}
