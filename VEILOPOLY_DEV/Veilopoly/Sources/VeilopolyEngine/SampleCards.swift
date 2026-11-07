import Foundation

/// Temporary 16+16 development fixture. GDD defines card EFFECT CATEGORIES but not exact 32-card list.
/// Not an approved commercial/gameplay card pool; replace through GameFactory.make(cards:) after spec ruling.
public enum SampleCards {
 public static let all: [CardDefinition] = {
  func c(_ i: Int, _ deck: DeckKind, _ text: String, _ effects: [CardEffect]) -> CardDefinition {
   CardDefinition(id: i, deck: deck, text: text, effects: effects)
  }
  func cash(_ n: Int) -> CardEffect { CardEffect(kind: .cash, amount: n, target: .bank) }
  func dest(_ i: Int) -> CardEffect { CardEffect(kind: .moveTo, tile: i, collectGo: true) }
  let chance: [CardDefinition] = [
   c(0,.chance,"前往起点",[dest(0)]),
   c(1,.chance,"前往伊利诺伊大道",[dest(24)]),
   c(2,.chance,"前往圣查尔斯广场",[dest(11)]),
   c(3,.chance,"前往最近的公共事业",[CardEffect(kind: .moveNearest, nearest: .utility, multiplier: 2)]),
   c(4,.chance,"前往最近的铁路",[CardEffect(kind: .moveNearest, nearest: .railroad, multiplier: 2)]),
   c(5,.chance,"银行分红 ¥50",[cash(50)]),
   c(6,.chance,"出狱卡",[CardEffect(kind: .jailCard)]),
   c(7,.chance,"后退三格",[CardEffect(kind: .moveRelative, delta: -3)]),
   c(8,.chance,"直接入狱",[CardEffect(kind: .goToJail)]),
   c(9,.chance,"修理房产",[CardEffect(kind: .repair, perHouse: 25, perHotel: 100)]),
   c(10,.chance,"银行罚款 ¥50",[cash(-50)]),
   c(11,.chance,"前往木板路",[dest(39)]),
   c(12,.chance,"前往最近的铁路",[CardEffect(kind: .moveNearest, nearest: .railroad, multiplier: 2)]),
   c(13,.chance,"获得 ¥150",[cash(150)]),
   c(14,.chance,"支付 ¥100",[cash(-100)]),
   c(15,.chance,"获得 ¥100",[cash(100)])
  ]
  let chest: [CardDefinition] = [
   c(16,.chest,"前往起点",[dest(0)]),
   c(17,.chest,"银行错误，获得 ¥150",[cash(150)]),
   c(18,.chest,"医院费用 ¥100",[cash(-100)]),
   c(19,.chest,"退税 ¥150",[cash(150)]),
   c(20,.chest,"生日，每位玩家给你 ¥50",[CardEffect(kind: .cash, amount: 50, target: .allOthers)]),
   c(21,.chest,"出狱卡",[CardEffect(kind: .jailCard)]),
   c(22,.chest,"直接入狱",[CardEffect(kind: .goToJail)]),
   c(23,.chest,"房屋修理",[CardEffect(kind: .repair, perHouse: 25, perHotel: 100)]),
   c(24,.chest,"股票分红 ¥50",[cash(50)]),
   c(25,.chest,"医疗支出 ¥50",[cash(-50)]),
   c(26,.chest,"出售股票获得 ¥100",[cash(100)]),
   c(27,.chest,"领取奖金 ¥100",[cash(100)]),
   c(28,.chest,"学校费用 ¥50",[cash(-50)]),
   c(29,.chest,"保险收益 ¥100",[cash(100)]),
   c(30,.chest,"遗产 ¥100",[cash(100)]),
   c(31,.chest,"咨询费 ¥50",[cash(50)])
  ]
  return chance + chest
 }()
}
