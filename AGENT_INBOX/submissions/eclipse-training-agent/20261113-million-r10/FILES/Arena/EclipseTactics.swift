import Foundation

@main
struct EclipseTactics {
    typealias K = VeilGomokuUnifiedSearch
    static func transform(_ index: Int, _ t: Int) -> Int {
        var r = index / 15, c = index % 15
        if t >= 4 { c = 14 - c }
        for _ in 0..<(t % 4) { let nr = c; c = 14 - r; r = nr }
        return r * 15 + c
    }
    static func main() throws {
        var limits = K.Limits()
        limits.maxDepth = 2; limits.width = 8
        limits.maxNodes = 1_000; limits.maxMilliseconds = 2_000
        limits.forcedLineDepth = 0
        var count = 0
        // Fixtures are board geometry checks; legal actor counts are retained.
        let fixtures: [(name: String, black: [Int], white: [Int], side: UInt8, accepted: [Int], rule: String)] = [
            ("own-five", [112,113,114,115], [0,2,4,6], 1, [111,116], "immediate-win"),
            ("forced-block", [112,113,114,115], [111,95,96], 2, [116], "mandatory-block"),
            ("win-before-block", [112,113,114,115], [125,126,127,128], 1, [111,116], "immediate-win"),
            ("fork-defense", [109,110,111,67,82,97], [0,2,4,30,32], 2, [112], ""),
            ("winning-counterattack", [109,110,111,67,82,97], [0,2,4,6,8], 2, [3,5], "double-completion-win")
        ]
        for fixture in fixtures {
            for t in 0..<8 {
                for trained in [false, true] {
                    var cells = [UInt8](repeating: 0, count: 225)
                    for idx in fixture.black { cells[transform(idx,t)] = 1 }
                    for idx in fixture.white { cells[transform(idx,t)] = 2 }
                    let position = K.Position(cells: cells, toMove: fixture.side)!
                    guard let decision = K.decide(position, limits: limits, trainedPolicy: trained),
                          fixture.accepted.map({ transform($0,t) }).contains(decision.index),
                          fixture.rule.isEmpty || decision.rule == fixture.rule else {
                        fatalError("Tactical regression \(fixture.name) transform=\(t) trained=\(trained)")
                    }
                    count += 1
                }
            }
        }
        var blankLimits = limits
        blankLimits.maxNodes = 1; blankLimits.maxMilliseconds = 1
        for trained in [false,true] {
            let position = K.Position(cells: [UInt8](repeating: 0, count: 225), toMove: 1)!
            guard K.decide(position, limits: blankLimits, trainedPolicy: trained)?.index == 112 else { fatalError("empty fallback") }
            count += 1
        }
        print("ECLIPSE_TACTICS_PASS checks=\(count)")
        if CommandLine.arguments.count >= 2 {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
            var changed = 0, total = 0, baselineDepth = 0, trainedDepth = 0
            for line in lines {
                let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
                let cells = (object["cells"] as! [Int]).map(UInt8.init)
                let side = UInt8(object["side"] as! Int)
                let position = K.Position(cells: cells, toMove: side)!
                let baseline = K.decide(position, limits: limits, trainedPolicy: false)
                let trained = K.decide(position, limits: limits, trainedPolicy: true)
                guard let b = baseline, let t = trained, cells[b.index] == 0, cells[t.index] == 0 else { fatalError("illegal historical probe") }
                if b.index != t.index { changed += 1 }
                baselineDepth += b.completedDepth; trainedDepth += t.completedDepth; total += 1
            }
            print("ECLIPSE_DECISION_AB total=\(total) changed=\(changed) baselineDepthTotal=\(baselineDepth) trainedDepthTotal=\(trainedDepth)")
        }
    }
}
