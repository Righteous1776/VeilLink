import Foundation

extension TacticalV2 {
    struct NormalizedPointV2: Codable, Hashable {
        let x: Double
        let y: Double
    }

    struct NormalizedRectV2: Codable, Hashable {
        let minX: Double
        let minY: Double
        let maxX: Double
        let maxY: Double

        init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
            self.minX = min(minX, maxX)
            self.minY = min(minY, maxY)
            self.maxX = max(minX, maxX)
            self.maxY = max(minY, maxY)
        }

        func expanded(by margin: Double) -> NormalizedRectV2 {
            NormalizedRectV2(
                minX: max(0, minX - margin),
                minY: max(0, minY - margin),
                maxX: min(1, maxX + margin),
                maxY: min(1, maxY + margin)
            )
        }

        func contains(_ p: NormalizedPointV2) -> Bool {
            p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY
        }
    }

    enum MapLODLevelV2: UInt8, Codable, Hashable {
        case campaign = 0
        case operational = 1
        case contact = 2

        static func resolve(zoom: Double) -> MapLODLevelV2 {
            if zoom < 0.85 { return .campaign }
            if zoom < 1.45 { return .operational }
            return .contact
        }
    }

    struct SectorIDV2: Codable, Hashable, Comparable {
        let row: Int
        let col: Int

        static func < (lhs: SectorIDV2, rhs: SectorIDV2) -> Bool {
            lhs.row == rhs.row ? lhs.col < rhs.col : lhs.row < rhs.row
        }
    }

    struct SectorIndexV2 {
        let mapWidth: Int
        let mapHeight: Int
        let sectorColumns: Int
        let sectorRows: Int
        private let cellIndicesBySector: [SectorIDV2: [Int]]

        init(
            map: Map,
            sectorColumns: Int = 6,
            sectorRows: Int = 3
        ) {
            precondition(sectorColumns > 0 && sectorRows > 0)
            self.mapWidth = map.width
            self.mapHeight = map.height
            self.sectorColumns = sectorColumns
            self.sectorRows = sectorRows

            var storage: [SectorIDV2: [Int]] = [:]
            for cell in map.cells {
                let c = min(
                    sectorColumns - 1,
                    (cell.col * sectorColumns) / max(1, map.width)
                )
                let r = min(
                    sectorRows - 1,
                    (cell.row * sectorRows) / max(1, map.height)
                )
                storage[SectorIDV2(row: r, col: c), default: []].append(cell.index)
            }
            self.cellIndicesBySector = storage
        }

        func sector(forCell index: Int) -> SectorIDV2? {
            guard index >= 0 && index < mapWidth * mapHeight else { return nil }
            let row = index / mapWidth
            let col = index % mapWidth
            return SectorIDV2(
                row: min(sectorRows - 1, (row * sectorRows) / max(1, mapHeight)),
                col: min(sectorColumns - 1, (col * sectorColumns) / max(1, mapWidth))
            )
        }

        func sectors(intersecting viewport: NormalizedRectV2) -> [SectorIDV2] {
            let minCol = max(0, min(sectorColumns - 1, Int(floor(viewport.minX * Double(sectorColumns)))))
            let maxCol = max(0, min(sectorColumns - 1, Int(floor(min(0.999999, viewport.maxX) * Double(sectorColumns)))))
            let minRow = max(0, min(sectorRows - 1, Int(floor(viewport.minY * Double(sectorRows)))))
            let maxRow = max(0, min(sectorRows - 1, Int(floor(min(0.999999, viewport.maxY) * Double(sectorRows)))))

            var result: [SectorIDV2] = []
            for row in minRow...maxRow {
                for col in minCol...maxCol {
                    result.append(SectorIDV2(row: row, col: col))
                }
            }
            return result.sorted()
        }

        func candidateCells(
            viewport: NormalizedRectV2,
            prefetchMargin: Double = 0.035
        ) -> [Int] {
            let expanded = viewport.expanded(by: prefetchMargin)
            var result: [Int] = []
            for sector in sectors(intersecting: expanded) {
                result.append(contentsOf: cellIndicesBySector[sector] ?? [])
            }
            return result.sorted()
        }
    }

    enum MapGeometryV2 {
        static func normalizedCenter(
            cell: Cell,
            map: Map
        ) -> NormalizedPointV2 {
            let x = (
                Double(cell.col) + 0.5 + (cell.row.isMultiple(of: 2) ? 0.0 : 0.5)
            ) / (Double(map.width) + 0.5)
            let y = (Double(cell.row) + 0.5) / Double(map.height)
            return NormalizedPointV2(x: x, y: y)
        }

        static func nearestCell(
            point: NormalizedPointV2,
            map: Map,
            candidates: [Int]? = nil
        ) -> Int? {
            let source = candidates ?? map.cells.map(\.index)
            var bestIndex: Int?
            var bestDistance = Double.greatestFiniteMagnitude

            for index in source {
                guard let cell = map.cell(index) else { continue }
                let center = normalizedCenter(cell: cell, map: map)
                let dx = center.x - point.x
                let dy = center.y - point.y
                let d2 = dx * dx + dy * dy
                if d2 < bestDistance || (d2 == bestDistance && index < (bestIndex ?? Int.max)) {
                    bestDistance = d2
                    bestIndex = index
                }
            }
            return bestIndex
        }
    }
}
