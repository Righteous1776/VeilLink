import Foundation

@main
struct NativeKernelTestRunner {
    static func assertTest(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            FileHandle.standardError.write(Data(("FAIL " + message + "\n").utf8))
            exit(2)
        }
    }

    static func rotate(_ old: Int, steps: Int) -> Int {
        var x = old
        if steps >= 4 {
            let row = x / 15, col = x % 15
            x = row * 15 + (14 - col)
        }
        for _ in 0..<(steps % 4) {
            let row = x / 15, col = x % 15
            x = col * 15 + (14 - row)
        }
        return x
    }
    static func board(_ black: [Int], _ white: [Int], toMove: UInt8) -> VeilGomokuUnifiedSearch.Position {
        var cells = [UInt8](repeating: 0, count: 225)
        for x in black { cells[x] = 1 }
        for x in white { cells[x] = 2 }
        return VeilGomokuUnifiedSearch.Position(cells: cells, toMove: toMove)!
    }
    static func main() throws {
        typealias K = VeilGomokuUnifiedSearch
        var limits = K.Limits()
        limits.maxDepth = 3
        limits.maxNodes = 15_000
        limits.maxMilliseconds = 250
        limits.forcedLineDepth = 3

        let blank = board([], [], toMove: 1)
        let opening = K.decide(blank, limits: limits)
        assertTest(opening?.index == 112, "empty center")
        print("PASS center opener")

        let selfWin = board([112,113,114,115], [100,101,102], toMove: 1)
        let win = K.decide(selfWin, limits: limits)
        assertTest([111,116].contains(win?.index ?? -1), "immediate five")
        assertTest(win?.rule == "immediate-win", "immediate five proof label")
        print("PASS own immediate win")

        let mustBlock = board([112,113,114,115], [111,95,96], toMove: 2)
        let block = K.decide(mustBlock, limits: limits)
        assertTest(block?.index == 116, "forced block")
        assertTest(block?.rule == "mandatory-block", "forced block label")
        print("PASS unique forced defense")

        let oppositeWin = board([112,113,114,115], [125,126,127,128], toMove: 2)
        let winFirst = K.decide(oppositeWin, limits: limits)
        assertTest(winFirst?.rule == "immediate-win", "own win before block")
        print("PASS winning move outranks blocking")

        var events: [K.Trace] = []
        let regular = board([112,113,129], [96,97,130], toMove: 1)
        let choice = K.decide(regular, limits: limits) { events.append($0) }
        assertTest(choice != nil, "a move exists")
        assertTest(events.first?.phase == .validating, "telemetry start")
        assertTest(events.last?.phase == .complete, "telemetry final")
        assertTest(events.last?.selectedIndex == choice?.index, "telemetry aligned")
        print("PASS actual-only progress events (\(events.count) events)")

        assertTest(K.Position(cells: [0,1], toMove: 1) == nil, "invalid board length")
        assertTest(K.Position(cells: [UInt8](repeating: 0, count: 225), toMove: 3) == nil, "invalid side")
        print("PASS invalid input validation")

        if CommandLine.arguments.count >= 2 {
            let url = URL(fileURLWithPath: CommandLine.arguments[1])
            let cases = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [[String: Any]]
            var total = 0, covered = 0, rejected = 0, timed = 0
            var failures: [(Int, Int, Int, [Int], String)] = []
            for raw in cases {
                let human = raw["human"] as! [Int]
                let ai = raw["ai"] as! [Int]
                let safe = raw["safe"] as! [Int]
                for turns in 0..<8 {
                    total += 1
                    let state = board(human.map { rotate($0, steps: turns) },
                                      ai.map { rotate($0, steps: turns) }, toMove: 2)
                    let acceptable = Set(safe.map { rotate($0, steps: turns) })
                    var compact = K.Limits()
                    compact.maxDepth = 2
                    compact.maxMilliseconds = 35
                    compact.maxNodes = 3_000
                    compact.forcedLineDepth = 1
                    let reply = K.decide(state, limits: compact)
                    if let reply, acceptable.contains(reply.index) {
                        covered += 1
                    } else {
                        if reply == nil { rejected += 1 }
                        if (reply?.completedDepth ?? 0) == 0 { timed += 1 }
                        if failures.count < 16 {
                            failures.append((raw["uid"] as? Int ?? -1, turns, reply?.index ?? -1,
                                             safe, reply?.rule ?? "nil"))
                        }
                    }
                }
            }
            print("FORK_MATRIX total=\(total) passed=\(covered) failed=\(total-covered) nil=\(rejected) zeroDepthFailures=\(timed)")
            for (id, rot, chosen, safe, reason) in failures {
                print("FORK_FAIL uid=\(id) rotation=\(rot) move=\(chosen) safe=\(safe) rule=\(reason)")
            }
            assertTest(covered == total, "history fork safety matrix")
        }
        print("ALL TESTS PASSED")
    }
}
