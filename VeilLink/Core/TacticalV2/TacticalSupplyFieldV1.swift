import Foundation

extension TacticalV2 {
    struct SupplyFieldV1: Codable, Hashable {
        static let unreachable = Int32.max

        let width: Int
        let height: Int
        let revision: UInt64
        let costMilli: [Int32]
        let source: [Int32]
        let parent: [Int32]

        func isReachable(_ cell: Int) -> Bool {
            costMilli.indices.contains(cell) && costMilli[cell] != Self.unreachable
        }

        func cost(at cell: Int) -> Int32? {
            guard costMilli.indices.contains(cell), costMilli[cell] != Self.unreachable else {
                return nil
            }
            return costMilli[cell]
        }

        func sourceCell(at cell: Int) -> Int? {
            guard source.indices.contains(cell), source[cell] >= 0 else { return nil }
            return Int(source[cell])
        }

        func path(to cell: Int) -> [Int]? {
            guard isReachable(cell) else { return nil }
            var result: [Int] = []
            var current = cell
            var safety = 0

            while parent.indices.contains(current) && safety <= parent.count {
                result.append(current)
                let p = parent[current]
                if p < 0 { break }
                current = Int(p)
                safety += 1
            }

            guard safety <= parent.count else { return nil }
            return result.reversed()
        }

        func stableHash64() -> UInt64 {
            var data = Data()
            func appendInt32(_ value: Int32) {
                var v = UInt32(bitPattern: value).bigEndian
                withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            }
            for value in costMilli { appendInt32(value) }
            for value in source { appendInt32(value) }
            for value in parent { appendInt32(value) }
            return StableHash64.fnv1a(data)
        }
    }

    enum SupplyFieldBuilderV1 {
        private struct HeapNode {
            let cell: Int
            let cost: Int64
            let source: Int
        }

        private struct MinHeap {
            var values: [HeapNode] = []

            mutating func push(_ value: HeapNode) {
                values.append(value)
                var i = values.count - 1
                while i > 0 {
                    let p = (i - 1) / 2
                    if !less(values[i], values[p]) { break }
                    values.swapAt(i, p)
                    i = p
                }
            }

            mutating func pop() -> HeapNode? {
                guard !values.isEmpty else { return nil }
                if values.count == 1 { return values.removeLast() }
                let result = values[0]
                values[0] = values.removeLast()
                var i = 0

                while true {
                    let l = i * 2 + 1
                    let r = l + 1
                    var smallest = i

                    if l < values.count && less(values[l], values[smallest]) {
                        smallest = l
                    }
                    if r < values.count && less(values[r], values[smallest]) {
                        smallest = r
                    }
                    if smallest == i { break }
                    values.swapAt(i, smallest)
                    i = smallest
                }
                return result
            }

            private func less(_ a: HeapNode, _ b: HeapNode) -> Bool {
                if a.cost != b.cost { return a.cost < b.cost }
                if a.source != b.source { return a.source < b.source }
                return a.cell < b.cell
            }
        }

        static func build(
            map: Map,
            sourceCells: Set<Int>,
            blockedCells: Set<Int>,
            revision: UInt64
        ) -> SupplyFieldV1 {
            let count = map.cells.count
            var cost = Array(repeating: Int64.max, count: count)
            var source = Array(repeating: Int32(-1), count: count)
            var parent = Array(repeating: Int32(-1), count: count)
            var heap = MinHeap()

            for cell in sourceCells.sorted() {
                guard map.cell(cell) != nil, !blockedCells.contains(cell) else { continue }
                cost[cell] = 0
                source[cell] = Int32(cell)
                heap.push(HeapNode(cell: cell, cost: 0, source: cell))
            }

            while let node = heap.pop() {
                guard node.cost == cost[node.cell] else { continue }

                for next in map.neighbors(of: node.cell) {
                    guard !blockedCells.contains(next), let nextCell = map.cell(next) else { continue }

                    let step = Int64(nextCell.supplyTraversalCostMilli)
                    let nextCost = node.cost + step

                    let shouldReplace: Bool
                    if nextCost < cost[next] {
                        shouldReplace = true
                    } else if nextCost == cost[next] {
                        let oldSource = Int(source[next])
                        let oldParent = Int(parent[next])
                        shouldReplace = node.source < oldSource
                            || (node.source == oldSource && node.cell < oldParent)
                    } else {
                        shouldReplace = false
                    }

                    guard shouldReplace else { continue }

                    cost[next] = nextCost
                    source[next] = Int32(node.source)
                    parent[next] = Int32(node.cell)
                    heap.push(HeapNode(cell: next, cost: nextCost, source: node.source))
                }
            }

            let publicCost: [Int32] = cost.map { value in
                if value == Int64.max || value > Int64(Int32.max - 1) {
                    return SupplyFieldV1.unreachable
                }
                return Int32(value)
            }

            return SupplyFieldV1(
                width: map.width,
                height: map.height,
                revision: revision,
                costMilli: publicCost,
                source: source,
                parent: parent
            )
        }
    }

    struct SupplyFieldCacheV1 {
        private var key: Key?
        private var field: SupplyFieldV1?
        private(set) var recomputeCount = 0

        private struct Key: Hashable {
            let mapRevision: UInt64
            let supplyRevision: UInt64
            let sources: [Int]
            let blocked: [Int]
        }

        mutating func field(
            map: Map,
            sourceCells: Set<Int>,
            blockedCells: Set<Int>,
            revision: Revision
        ) -> SupplyFieldV1 {
            let nextKey = Key(
                mapRevision: revision.map,
                supplyRevision: revision.supply,
                sources: sourceCells.sorted(),
                blocked: blockedCells.sorted()
            )
            if key == nextKey, let field {
                return field
            }

            let next = SupplyFieldBuilderV1.build(
                map: map,
                sourceCells: sourceCells,
                blockedCells: blockedCells,
                revision: revision.supply
            )
            key = nextKey
            field = next
            recomputeCount += 1
            return next
        }
    }
}
