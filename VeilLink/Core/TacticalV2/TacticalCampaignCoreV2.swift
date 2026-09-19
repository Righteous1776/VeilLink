import Foundation

enum TacticalV2 {}

extension TacticalV2 {
    enum Faction: UInt8, Codable, Hashable {
        case cao = 0
        case yuan = 1
    }

    enum UnitKind: UInt8, Codable, Hashable {
        case command = 0
        case infantry = 1
        case cavalry = 2
        case ranged = 3
        case supply = 4
    }

    struct Cell: Codable, Hashable, Identifiable {
        let index: Int
        let row: Int
        let col: Int
        let terrainCode: String
        let movementCostMilli: Int32
        let visionOpacityPermille: Int16
        let supplyFactorPermille: Int16
        let elevationBand: Int16
        let road: Bool

        var id: Int { index }

        var supplyTraversalCostMilli: Int32 {
            let factor = max(Int32(100), Int32(supplyFactorPermille))
            let base = max(Int32(1), movementCostMilli)
            var cost = Int32((Int64(base) * 1000) / Int64(factor))
            if road {
                cost = Int32((Int64(cost) * 750) / 1000)
            }
            return max(1, cost)
        }
    }

    struct Map: Codable, Hashable {
        let mapID: String
        let width: Int
        let height: Int
        let cells: [Cell]

        init(mapID: String, width: Int, height: Int, cells: [Cell]) {
            precondition(width > 0 && height > 0)
            precondition(cells.count == width * height)
            precondition(cells.enumerated().allSatisfy { $0.offset == $0.element.index })
            self.mapID = mapID
            self.width = width
            self.height = height
            self.cells = cells
        }

        func cell(_ index: Int) -> Cell? {
            guard cells.indices.contains(index) else { return nil }
            return cells[index]
        }

        func neighbors(of index: Int) -> [Int] {
            guard cells.indices.contains(index) else { return [] }
            let row = index / width
            let col = index % width
            let even = [(-1,-1), (-1,0), (0,-1), (0,1), (1,-1), (1,0)]
            let odd  = [(-1,0), (-1,1), (0,-1), (0,1), (1,0), (1,1)]
            return (row.isMultiple(of: 2) ? even : odd).compactMap { dr, dc in
                let r = row + dr
                let c = col + dc
                guard (0..<height).contains(r), (0..<width).contains(c) else { return nil }
                return r * width + c
            }
        }

        func cube(of index: Int) -> Cube? {
            guard cells.indices.contains(index) else { return nil }
            let row = index / width
            let col = index % width
            let q = col - (row - (row & 1)) / 2
            let r = row
            let x = q
            let z = r
            let y = -x - z
            return Cube(x: x, y: y, z: z)
        }

        func index(of cube: Cube) -> Int? {
            let row = cube.z
            let col = cube.x + (row - (row & 1)) / 2
            guard (0..<height).contains(row), (0..<width).contains(col) else { return nil }
            return row * width + col
        }

        func distance(_ a: Int, _ b: Int) -> Int {
            guard let aa = cube(of: a), let bb = cube(of: b) else { return Int.max }
            return max(abs(aa.x - bb.x), abs(aa.y - bb.y), abs(aa.z - bb.z))
        }
    }

    struct Cube: Codable, Hashable {
        let x: Int
        let y: Int
        let z: Int

        init(x: Int, y: Int, z: Int) {
            precondition(x + y + z == 0)
            self.x = x
            self.y = y
            self.z = z
        }
    }

    struct Unit: Codable, Hashable, Identifiable {
        let id: String
        let faction: Faction
        let kind: UnitKind
        var cell: Int
        var steps: Int
    }

    struct Revision: Codable, Hashable {
        let map: UInt64
        let terrain: UInt64
        let unit: UInt64
        let supply: UInt64

        static let zero = Revision(map: 0, terrain: 0, unit: 0, supply: 0)
    }

    enum StableHash64 {
        static func fnv1a(_ bytes: Data) -> UInt64 {
            var hash: UInt64 = 1469598103934665603
            for byte in bytes {
                hash ^= UInt64(byte)
                hash &*= 1099511628211
            }
            return hash
        }

        static func fnv1a(_ string: String) -> UInt64 {
            fnv1a(Data(string.utf8))
        }
    }
}
