import Foundation

@MainActor private var assertionCount = 0
@MainActor private func check(_ value: @autoclosure () -> Bool, _ reason: String) {
    assertionCount += 1
    precondition(value(), "#\(assertionCount): \(reason)")
}

@main struct R11ConsoleTests {
    @MainActor static func main() {
        typealias C = VeilEclipseConsoleStream
        let zero = C.lines(elapsedSeconds: 0, visibleRows: 2)
        let same = C.lines(elapsedSeconds: 0, visibleRows: 2)
        check(zero == same, "deterministic output")
        check(zero.count == 2, "2 compact rows")
        check(C.lines(elapsedSeconds: 0, visibleRows: 0).count == 1, "minimum rows clamp")
        check(C.lines(elapsedSeconds: 0, visibleRows: 999).count == 10, "max row bound")
        check(C.lines(elapsedSeconds: 0, visibleRows: -999).count == 1, "negative row bound")
        check(C.lines(elapsedSeconds: -99, visibleRows: 2) == zero, "negative time clamps")
        check(C.lines(elapsedSeconds: .nan, visibleRows: 2) == zero, "NaN resets")
        check(C.lines(elapsedSeconds: .infinity, visibleRows: 2) == zero, "positive infinity resets")
        check(C.lines(elapsedSeconds: -.infinity, visibleRows: 2) == zero, "negative infinity resets")
        check(C.scrollPosition(elapsedSeconds: 1) == 14, "normal 14 lines/second")
        check(C.scrollPosition(elapsedSeconds: 1, lowPower: true) == 6, "low power 6 lines/second")
        check(C.scrollPosition(elapsedSeconds: -10) == 0, "scroll clamps negative time")
        check(C.scrollPosition(elapsedSeconds: .nan) == 0, "scroll clamps NaN")
        check(C.scrollPosition(elapsedSeconds: 0.2) > C.scrollPosition(elapsedSeconds: 0.1), "scroll advances")
        check(C.lines(elapsedSeconds: 0.01, visibleRows: 7) == C.lines(elapsedSeconds: 0.02, visibleRows: 7), "stable between rows")
        check(C.lines(elapsedSeconds: 0, visibleRows: 7) != C.lines(elapsedSeconds: 0.1, visibleRows: 7), "updates after row boundary")
        check(C.lines(elapsedSeconds: 0, visibleRows: 7, lowPower: true) == C.lines(elapsedSeconds: 0, visibleRows: 7), "initial state stable")
        check(C.lines(elapsedSeconds: 1.0, visibleRows: 8, lowPower: true) != C.lines(elapsedSeconds: 1.0, visibleRows: 8), "lower rate in low power")
        check(!C.disclosure.isEmpty, "has visual disclaimer")
        check(C.disclosure.contains("非真实"), "not actual reasoning")
        check(C.disclosure.contains("落点"), "no hint disclosure")
        for seconds in stride(from: 0.0, through: 12.0, by: 0.25) {
            let rows = C.lines(elapsedSeconds: seconds, visibleRows: 9)
            check(rows.count == 9, "bounded visible rows")
            check(rows.allSatisfy { $0.text.hasPrefix("vis.") }, "clearly decorative")
            check(rows.allSatisfy { (0...3).contains($0.tone) }, "theme tone bounds")
            check(rows.allSatisfy { $0.text.count < 80 }, "short line")
            check(rows.allSatisfy { !$0.text.lowercased().contains("candidate") }, "no candidates")
            check(rows.allSatisfy { !$0.text.lowercased().contains("board") }, "no board data")
            check(rows.allSatisfy { !$0.text.lowercased().contains("pv") }, "no private variation")
            check(rows.allSatisfy { !$0.text.contains("胜率") }, "no fabricated probabilities")
        }
        print("PASS: R11 console \(assertionCount) assertions")
    }
}
