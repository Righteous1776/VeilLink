import Foundation

func makeBoard(host: [Int], guest: [Int]) -> GomokuState {
    var board = GomokuState()
    for i in host.indices {
        precondition(board.apply(index: host[i], actor: .host), "host i=\(i)")
        if i < guest.count {
            precondition(board.apply(index: guest[i], actor: .guest), "guest i=\(i)")
        }
    }
    return board
}
func transformed(_ index: Int, symmetry: Int) -> Int {
    var r = index / 15, c = index % 15
    for _ in 0..<(symmetry % 4) { (r,c) = (c,14-r) }
    if symmetry >= 4 { c = 14 - c }
    return r*15+c
}
func pattern(_ x: [Int], _ symmetry: Int) -> [Int] {
    x.map { transformed($0,symmetry:symmetry) }
}
func check(_ label: String, host: [Int], guest: [Int],
           attacker: MiniGamePlayer, root: Int,
           choices: [Int], shouldProve: Bool) {
    for sym in 0..<8 {
        let b = makeBoard(host: pattern(host,sym), guest: pattern(guest,sym))
        let proof = GomokuForcingSearchV9.provenMove(
            in: b, for: attacker, candidates: pattern(choices,sym),
            maxAttackerMoves: 4, nodeCap: 500,
            deadline: Date.timeIntervalSinceReferenceDate + 2
        )
        if shouldProve {
            precondition(proof?.index == transformed(root,symmetry:sym),
                         "\(label) symmetry=\(sym) actual=\(String(describing:proof))")
        } else {
            precondition(proof == nil, "\(label) symmetry=\(sym) unexpected proof")
        }
    }
    print("PASS: \(label) × 8")
}
check("R8 synthetic double threat",
      host:[109,110,111,67,82,97], guest:[0,2,4,6,8,10],
      attacker:.host, root:52, choices:[52], shouldProve:true)
check("R8 synthetic counterattack",
      host:[109,110,111,67,82,97,0], guest:[158,159,160,116,131,146],
      attacker:.guest, root:101, choices:[101], shouldProve:true)
check("defender has own immediate winning reply",
      host:[109,110,111,67,82,97], guest:[0,1,2,3,8,10],
      attacker:.host, root:52, choices:[52], shouldProve:false)
check("single stone cannot force win",
      host:[112], guest:[],
      attacker:.guest, root:111, choices:[111,97,113], shouldProve:false)
let capped = makeBoard(host:[109,110,111,67,82,97], guest:[0,2,4,6,8,10])
precondition(GomokuForcingSearchV9.provenMove(
    in:capped,for:.host,candidates:[52],maxAttackerMoves:4,nodeCap:0,
    deadline:Date.timeIntervalSinceReferenceDate+3
) == nil)
precondition(GomokuForcingSearchV9.provenMove(
    in:capped,for:.host,candidates:[52],maxAttackerMoves:4,nodeCap:10,
    deadline:Date.timeIntervalSinceReferenceDate-1
) == nil)
print("PASS: exhausted budget × 2")
print("34 standalone tactical checks PASS")
