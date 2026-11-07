import Foundation

@main
enum EmotionRuntimeHarness {
    static func main() {
        let all = VeilEmotionGardenEngine.rituals
        precondition(all.count == 1_000)
        precondition(Set(all.map(\.id)).count == 1_000)
        precondition(Set(all.map(\.prompt)).count == 1_000)
        precondition(Set(all.map { $0.steps.joined(separator: "|") }).count == 1_000)
        precondition(Set(all.map(\.completionNote)).count == 1_000)
        precondition(all.allSatisfy { $0.steps.count == 3 })
        precondition(all.first?.id == "EV-0001")
        precondition(all.last?.id == "EV-1000")

        for tone in VeilEmotionTone.allCases {
            precondition(VeilEmotionGardenEngine.rituals(for: tone).count == 100)
            for context in VeilEmotionContext.allCases {
                let reachable = VeilEmotionGardenEngine.rituals(for: tone, context: context)
                precondition(reachable.count == 10)
                precondition(Set(reachable.map(\.kind)).count == 10)
            }
        }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_704_067_200)
        let first = VeilEmotionGardenEngine.dailyPath(for: .uncertain, context: .night, date: date, calendar: utc)
        let second = VeilEmotionGardenEngine.dailyPath(for: .uncertain, context: .night, date: date, calendar: utc)
        precondition(first == second && first.count == 3)
        precondition(VeilEmotionGardenEngine.ritual(id: "ev-1000")?.id == "EV-1000")
        precondition(VeilEmotionGardenEngine.search("EV-0001").map(\.id) == ["EV-0001"])
        let rainy = VeilEmotionGardenEngine.search("雨天", limit: 100)
        precondition(rainy.count == 100 && rainy.allSatisfy { $0.context == .rainyDay })
        precondition(VeilEmotionGardenEngine.search("不存在的情绪条目").isEmpty)

        let benchmarkStart = Date()
        for index in 1...10_000 {
            let id = String(format: "EV-%04d", (index % 1_000) + 1)
            precondition(VeilEmotionGardenEngine.ritual(id: id) != nil)
        }
        let lookupMilliseconds = Int(Date().timeIntervalSince(benchmarkStart) * 1_000)
        print("INDEXED_LOOKUP_10000_MS=\(lookupMilliseconds)")
        print("EMOTION_RUNTIME_1000_PASS")
    }
}
