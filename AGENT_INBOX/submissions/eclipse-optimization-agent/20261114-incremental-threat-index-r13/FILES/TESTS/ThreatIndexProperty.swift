import Foundation

struct DeterministicPRNG {
    var value: UInt64
    mutating func next() -> UInt64 {
        value &+= 0x9e3779b97f4a7c15
        var z = value
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

struct IndependentRuleReference {
    static let axes = [(0, 1), (1, 0), (1, 1), (1, -1)]
    static func makesFive(_ cells: [UInt8], at index: Int, stone: UInt8) -> Bool {
        let row = index / 15, col = index % 15
        for (dr, dc) in axes {
            var n = 1
            for sign in [-1, 1] {
                var r = row + dr * sign, c = col + dc * sign
                while (0..<15).contains(r), (0..<15).contains(c), cells[r * 15 + c] == stone {
                    n += 1
                    r += dr * sign
                    c += dc * sign
                }
            }
            if n >= 5 { return true }
        }
        return false
    }

    static func winningSquares(_ cells: [UInt8], stone: UInt8) -> [Int] {
        var c = cells, results: [Int] = []
        for at in 0..<225 where cells[at] == 0 {
            c[at] = stone
            if makesFive(c, at: at, stone: stone) { results.append(at) }
            c[at] = 0
        }
        return results
    }

    static func forkSquares(_ cells: [UInt8], stone: UInt8) -> [Int] {
        var c = cells, results: [Int] = []
        for at in 0..<225 where cells[at] == 0 {
            c[at] = stone
            // A fork is exactly >=2 different winning points on the NEXT turn.
            if winningSquares(c, stone: stone).count >= 2 { results.append(at) }
            c[at] = 0
        }
        return results
    }
}

@main
struct Runner {
    static func main() {
        var checks = 0
        func check(_ ok: @autoclosure () -> Bool, _ msg: String) {
            guard ok() else { fatalError("FAIL at assertion \(checks): \(msg)") }
            checks += 1
        }
        var rng = DeterministicPRNG(value: 0x121320261114)
        var board = [UInt8](repeating: 0, count: 225)
        var accumulator = EclipseIncrementalThreatIndexR13(cells: board)!
        check(accumulator.winningSquares(stone: 1).isEmpty, "empty black")
        check(accumulator.winningSquares(stone: 2).isEmpty, "empty white")
        var records: [(Int, UInt8)] = []
        for step in 0..<850 {
            let mayUndo = step % 7 == 6 && !records.isEmpty
            if mayUndo {
                let entry = records.removeLast()
                check(accumulator.undo(entry.0, stone: entry.1), "undo")
                board[entry.0] = 0
            } else {
                if records.count >= 180 {
                    let e = records.removeLast()
                    check(accumulator.undo(e.0, stone: e.1), "safety undo")
                    board[e.0] = 0
                }
                var legal = (0..<225).filter { board[$0] == 0 }
                if step % 3 == 0 { legal = legal.filter { abs($0 / 15 - 7) <= 6 } }
                let i = legal[Int(rng.next() % UInt64(legal.count))]
                let stone: UInt8 = UInt8(records.count % 2 + 1)
                check(accumulator.place(i, stone: stone), "place")
                records.append((i, stone))
                board[i] = stone
            }
            check(accumulator.cells == board, "position parity")
            for stone: UInt8 in [1, 2] {
                let slow = IndependentRuleReference.winningSquares(board, stone: stone)
                let fast = accumulator.winningSquares(stone: stone)
                check(fast == slow, "winning completion parity step \(step), side \(stone)")
                if step % 11 == 0 {
                    let sf = IndependentRuleReference.forkSquares(board, stone: stone)
                    let ff = accumulator.forkSquares(stone: stone)
                    check(ff == sf, "exact next-turn fork parity step \(step), side \(stone)")
                }
                for index in fast { check(accumulator.winsImmediately(stone: stone, at: index), "index score") }
            }
        }
        for entry in records.reversed() {
            check(accumulator.undo(entry.0, stone: entry.1), "full reset")
            board[entry.0] = 0
        }
        check(accumulator.cells == board, "final board")
        check(accumulator.winningSquares(stone: 1).isEmpty, "final black")
        check(accumulator.winningSquares(stone: 2).isEmpty, "final white")
        check(EclipseIncrementalThreatIndexR13(cells: [UInt8](repeating: 3, count: 225)) == nil, "invalid cells")
        check(EclipseIncrementalThreatIndexR13(cells: [UInt8](repeating: 0, count: 224)) == nil, "invalid size")
        print("R13_EXACT_PROPERTY_PASS checks=\(checks) iterations=850 forkComparisons=\(2 * 78)")
    }
}
