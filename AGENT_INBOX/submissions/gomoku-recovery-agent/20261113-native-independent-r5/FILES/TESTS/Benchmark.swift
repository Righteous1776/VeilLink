import Foundation

@main
struct Benchmark {
    static func main() throws {
        let arr = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [[String: Any]]
        var times: [Double] = [], depths: [Int] = [], nodes: [Int] = [], missing = 0
        for caseItem in arr {
            let cells = (caseItem["cells"] as! [Int]).map { UInt8($0) }
            let side = UInt8(caseItem["toMove"] as! Int)
            guard let board = VeilGomokuUnifiedSearch.Position(cells:cells,toMove:side) else { continue }
            var opts=VeilGomokuUnifiedSearch.Limits()
            opts.maxDepth=5
            opts.maxNodes=35_000
            opts.maxMilliseconds=160
            opts.width=12
            opts.forcedLineDepth=4
            let started=Date.timeIntervalSinceReferenceDate
            let decision=VeilGomokuUnifiedSearch.decide(board,limits:opts)
            let millis=(Date.timeIntervalSinceReferenceDate-started)*1000
            times.append(millis)
            depths.append(decision?.completedDepth ?? 0)
            nodes.append(decision?.nodes ?? 0)
            if decision==nil { missing+=1 }
        }
        let count=max(1,times.count)
        print("BENCHMARK n=\(times.count) missing=\(missing) avg_ms=\(Int(times.reduce(0,+)/Double(count))) max_ms=\(Int(times.max() ?? 0)) avg_completed_depth=\(String(format:"%.2f",Double(depths.reduce(0,+))/Double(count))) depth_0=\(depths.filter{$0==0}.count) avg_nodes=\(nodes.reduce(0,+)/count)")
    }
}
