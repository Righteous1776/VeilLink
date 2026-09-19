import Foundation

extension TacticalV2 {
    struct RoutePlanV2: Codable, Hashable {
        let cells: [Int]
        let totalCostMilli: Int64
        let expandedNodes: Int

        var isEmpty: Bool { cells.isEmpty }
    }

    enum RoutePlannerV2 {
        private struct Node {
            let cell: Int
            let f: Int64
            let g: Int64
        }

        private struct Heap {
            var values: [Node] = []

            mutating func push(_ n: Node) {
                values.append(n)
                var i = values.count - 1
                while i > 0 {
                    let p = (i - 1) / 2
                    if !less(values[i], values[p]) { break }
                    values.swapAt(i, p)
                    i = p
                }
            }

            mutating func pop() -> Node? {
                guard !values.isEmpty else { return nil }
                if values.count == 1 { return values.removeLast() }
                let out = values[0]
                values[0] = values.removeLast()
                var i = 0

                while true {
                    let l = i * 2 + 1
                    let r = l + 1
                    var best = i
                    if l < values.count && less(values[l], values[best]) { best = l }
                    if r < values.count && less(values[r], values[best]) { best = r }
                    if best == i { break }
                    values.swapAt(i, best)
                    i = best
                }
                return out
            }

            private func less(_ a: Node, _ b: Node) -> Bool {
                if a.f != b.f { return a.f < b.f }
                if a.g != b.g { return a.g < b.g }
                return a.cell < b.cell
            }
        }

        static func plan(
            map: Map,
            from start: Int,
            to goal: Int,
            blocked: Set<Int> = [],
            maxExpandedNodes: Int = 4096
        ) -> RoutePlanV2? {
            guard map.cell(start) != nil, map.cell(goal) != nil else { return nil }
            if start == goal {
                return RoutePlanV2(cells: [start], totalCostMilli: 0, expandedNodes: 0)
            }

            var open = Heap()
            var gScore: [Int: Int64] = [start: 0]
            var parent: [Int: Int] = [:]
            var expanded = 0

            let minStep = Int64(max(1, map.cells.map(\.movementCostMilli).min() ?? 1))

            func heuristic(_ cell: Int) -> Int64 {
                Int64(map.distance(cell, goal)) * minStep
            }

            open.push(Node(cell: start, f: heuristic(start), g: 0))

            while let node = open.pop() {
                if node.g != gScore[node.cell] { continue }
                if node.cell == goal {
                    var path = [goal]
                    var cursor = goal
                    while let p = parent[cursor] {
                        path.append(p)
                        cursor = p
                    }
                    path.reverse()
                    return RoutePlanV2(
                        cells: path,
                        totalCostMilli: node.g,
                        expandedNodes: expanded
                    )
                }

                expanded += 1
                if expanded > maxExpandedNodes { return nil }

                for next in map.neighbors(of: node.cell).sorted() {
                    if blocked.contains(next) && next != goal { continue }
                    guard let cell = map.cell(next) else { continue }
                    let step = Int64(max(1, cell.movementCostMilli))
                    let nextG = node.g + step

                    if nextG < gScore[next, default: Int64.max] {
                        gScore[next] = nextG
                        parent[next] = node.cell
                        open.push(Node(
                            cell: next,
                            f: nextG + heuristic(next),
                            g: nextG
                        ))
                    }
                }
            }

            return nil
        }
    }

    struct RouteDragPlannerV2 {
        private(set) var originCell: Int?
        private(set) var lastTargetCell: Int?
        private(set) var preview: RoutePlanV2?
        private(set) var recomputeCount = 0

        mutating func begin(originCell: Int) {
            self.originCell = originCell
            lastTargetCell = originCell
            preview = RoutePlanV2(cells: [originCell], totalCostMilli: 0, expandedNodes: 0)
        }

        mutating func update(
            targetCell: Int,
            map: Map,
            blocked: Set<Int> = []
        ) -> RoutePlanV2? {
            guard let originCell else { return nil }

            // UI may emit drag updates at screen refresh rate. Do not rerun A* until
            // the finger snaps into a different logical cell.
            if lastTargetCell == targetCell {
                return preview
            }

            lastTargetCell = targetCell
            preview = RoutePlannerV2.plan(
                map: map,
                from: originCell,
                to: targetCell,
                blocked: blocked
            )
            recomputeCount += 1
            return preview
        }

        mutating func cancel() {
            originCell = nil
            lastTargetCell = nil
            preview = nil
        }

        mutating func finish() -> RoutePlanV2? {
            defer { cancel() }
            return preview
        }
    }
}
