import Foundation
func check(_ yes: @autoclosure () -> Bool, _ label: String) {
    guard yes() else { fatalError("FAIL: \(label)") }
    print("PASS: \(label)")
}
func board(_ black: [Int], _ white: [Int]) -> GomokuState {
    var s = GomokuState()
    for i in 0..<max(black.count,white.count) {
        if black.indices.contains(i) { check(s.apply(index:black[i],actor:.host),"legal black \(i)") }
        if white.indices.contains(i) { check(s.apply(index:white[i],actor:.guest),"legal white \(i)") }
    }
    return s
}
let empty = GomokuState()
check(VeilEclipseThreatReadout.instantWins(on:empty,for:.host) == 0,"empty black")
check(VeilEclipseThreatReadout.instantWins(on:empty,for:.guest) == 0,"empty white")
let b = board([7*15+5,7*15+6,7*15+7,7*15+8], [0,2,4,6])
check(VeilEclipseThreatReadout.instantWins(on:b,for:.host) == 2,"black two open endings")
check(VeilEclipseThreatReadout.instantWins(on:b,for:.guest) == 0,"white no false threat")
func rotate(_ i:Int)->Int { let row=i/15,col=i%15;return col*15 + 14-row }
let br=board([5,6,7,8].map{rotate(7*15+$0)}, [0,2,4,6].map{rotate($0)})
check(VeilEclipseThreatReadout.instantWins(on:br,for:.host) == 2,"rotated black threat invariance")
let w = board([14*15+0,14*15+2,14*15+4,14*15+6], [8*15+4,8*15+5,8*15+6,8*15+7])
check(VeilEclipseThreatReadout.instantWins(on:w,for:.guest) == 2,"white two open endings")
check(VeilEclipseThreatReadout.instantWins(on:w,for:.host) == 0,"black no false threat")
print("PASS: all 7 threat scenarios")
