import Foundation

public enum GameFactory {
 /// PROVISIONAL standard 40-cell price/rent fixture pending rules-owner confirmation.
 public static func board() -> [Tile] {
  var tiles = (0..<40).map { Tile(i: $0, kind: .freeParking, name: "格位\($0)") }
  func special(_ i: Int, _ kind: TileKind, _ name: String) { tiles[i] = Tile(i: i, kind: kind, name: name) }
  func street(_ i: Int, _ name: String, _ color: ColorGroup, _ price: Int, _ rents: [Int], _ cost: Int) {
   tiles[i] = Tile(i: i, kind: .street, name: name, color: color, price: price, rent: rents, houseCost: cost)
  }
  special(0,.go,"起点"); special(2,.chest,"命运"); special(4,.tax,"所得税")
  special(7,.chance,"机会"); special(10,.jail,"监狱 / 探访")
  special(17,.chest,"命运"); special(20,.freeParking,"免费停车")
  special(22,.chance,"机会"); special(30,.goToJail,"前往监狱")
  special(33,.chest,"命运"); special(36,.chance,"机会"); special(38,.tax,"奢侈税")
  for i in [5,15,25,35] { tiles[i] = Tile(i: i, kind: .railroad, name: "铁路 \(i)", price: 200) }
  for i in [12,28] { tiles[i] = Tile(i: i, kind: .utility, name: "公共事业 \(i)", price: 150) }
  street(1,"地中海大道",.brown,60,[2,10,30,90,160,250],50)
  street(3,"波罗的海大道",.brown,60,[4,20,60,180,320,450],50)
  street(6,"东方大道",.lightBlue,100,[6,30,90,270,400,550],50)
  street(8,"佛蒙特大道",.lightBlue,100,[6,30,90,270,400,550],50)
  street(9,"康涅狄格大道",.lightBlue,120,[8,40,100,300,450,600],50)
  street(11,"圣查尔斯广场",.pink,140,[10,50,150,450,625,750],100)
  street(13,"州大道",.pink,140,[10,50,150,450,625,750],100)
  street(14,"弗吉尼亚大道",.pink,160,[12,60,180,500,700,900],100)
  street(16,"圣詹姆斯广场",.orange,180,[14,70,200,550,750,950],100)
  street(18,"田纳西大道",.orange,180,[14,70,200,550,750,950],100)
  street(19,"纽约大道",.orange,200,[16,80,220,600,800,1000],100)
  street(21,"肯塔基大道",.red,220,[18,90,250,700,875,1050],150)
  street(23,"印第安纳大道",.red,220,[18,90,250,700,875,1050],150)
  street(24,"伊利诺伊大道",.red,240,[20,100,300,750,925,1100],150)
  street(26,"大西洋大道",.yellow,260,[22,110,330,800,975,1150],150)
  street(27,"文特诺大道",.yellow,260,[22,110,330,800,975,1150],150)
  street(29,"马文花园",.yellow,280,[24,120,360,850,1025,1200],150)
  street(31,"太平洋大道",.green,300,[26,130,390,900,1100,1275],200)
  street(32,"北卡罗来纳大道",.green,300,[26,130,390,900,1100,1275],200)
  street(34,"宾夕法尼亚大道",.green,320,[28,150,450,1000,1200,1400],200)
  street(37,"公园大道",.darkBlue,350,[35,175,500,1100,1300,1500],200)
  street(39,"木板路",.darkBlue,400,[50,200,600,1400,1700,2000],200)
  return tiles
 }
 public static func make(seed: UInt64, humanCount: Int = 1,
                         levels: [AILevel] = [.balanced, .balanced, .balanced, .balanced],
                         cards: [CardDefinition] = SampleCards.all) -> GameState {
  let players = (0..<4).map { i in
   Player(id: i, name: i == 0 ? "玩家 1" : "玩家 \(i+1)",
          kind: i < humanCount ? .human : .ai, aiLevel: levels.isEmpty ? .balanced : levels[i % levels.count])
  }
  var state = GameState(seed: seed, board: board(), players: players, cards: cards)
  seededShuffle(&state.chanceDeck.order, seed: seed, counter: &state.rngCounter)
  seededShuffle(&state.chestDeck.order, seed: seed, counter: &state.rngCounter)
  return state
 }
}
public func seededRNG(seed: UInt64, counter: inout UInt64) -> UInt64 {
 let value = seed &+ counter &* 0x9E3779B97F4A7C15
 counter = counter &+ 1
 var z = value &+ 0x9E3779B97F4A7C15
 z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
 z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
 return z ^ (z >> 31)
}
public func seededShuffle(_ array: inout [Int], seed: UInt64, counter: inout UInt64) {
 if array.count < 2 { return }
 for i in stride(from: array.count - 1, through: 1, by: -1) {
  let j = Int(seededRNG(seed: seed, counter: &counter) % UInt64(i + 1))
  array.swapAt(i, j)
 }
}
