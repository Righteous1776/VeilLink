import Foundation

/// Owner-requested City Long V3 event deck: "机遇" is a thematic subcategory
/// of Chance, not a third wire/save DeckKind. Exactly 16 Chance + 16 Fate cards.
/// Each ruling quotes the EXACT credited/debited amount; no implicit cash x3.
public struct VeilopolyCityLongCardBlueprint {
 public let id: Int
 public let deck: DeckKind
 public let category: String
 public let title: String
 public let story: String
 public let ruling: String
 public let effects: [CardEffect]

 public var canonical: CardDefinition {
  CardDefinition(id: id, deck: deck, text: "\(title) · \(ruling)", effects: effects)
 }
 public var editorial: VeilopolyCardEditorialEntry {
  VeilopolyCardEditorialEntry(
   id, String(format: "VL-CITY-V3-%@-%03d", deck == .chance ? "CH" : "FT", id),
   deck, category, title, story, ruling)
 }
}

public enum VeilopolyCityLongCards {
 /// Source of truth for the live ruling AND the narrative seen in the UI.
 /// The old SampleCards fixture and its exact historical messages stay intact.
 public static let blueprints: [VeilopolyCityLongCardBlueprint] = {
  func c(_ id: Int, _ deck: DeckKind, _ category: String, _ title: String,
         _ story: String, _ ruling: String, _ effects: [CardEffect])
    -> VeilopolyCityLongCardBlueprint {
   VeilopolyCityLongCardBlueprint(id: id, deck: deck, category: category,
                                  title: title, story: story, ruling: ruling, effects: effects)
  }
  func cash(_ amount: Int) -> [CardEffect] {
   [CardEffect(kind: .cash, amount: amount, target: .bank)]
  }
  func move(_ tile: Int) -> [CardEffect] {
   [CardEffect(kind: .moveTo, tile: tile, collectGo: true)]
  }
  func nearest(_ set: NearestSet) -> [CardEffect] {
   [CardEffect(kind: .moveNearest, nearest: set, multiplier: 1)]
  }
  let chance: [VeilopolyCityLongCardBlueprint] = [
   c(0,.chance,"旅程","晨钟归航","古老的钟楼再次为旅行者敲响。","前往起点，按本局规则领取经过起点收入。",move(0)),
   c(1,.chance,"机遇","红色大道的请柬","城市商会邀请你出席一次红色街区的商业交流。","前往第24格伊利诺伊大道，按落点结算。",move(24)),
   c(2,.chance,"旅程","广场改造巡礼","夜色中的广场正在举办城市更新展。","前往第11格圣查尔斯广场，按落点结算。",move(11)),
   c(3,.chance,"机遇","公共事业实地考察","供能公司的工程师邀请你参观下一处设施。","前往最近的公共事业，按正常租金结算。",nearest(.utility)),
   c(4,.chance,"机遇","城际铁路通行证","一张新的铁路换乘券寄到了你的邮箱。","前往最近的铁路，按正常租金结算。",nearest(.railroad)),
   c(5,.chance,"机遇","城市创新基金","你设计的技术方案获得了城市创新资助。","从银行领取 ¥650。",cash(650)),
   c(6,.chance,"特权","司法豁免文书","审理官签发了一份仅用于本局的特别通行文书。","获得一张出狱卡；如已有同类卡，改领 ¥250。",[CardEffect(kind:.jailCard)]),
   c(7,.chance,"旅程","意外的捷径","一条旧地图标记的道路迫使你折返。","后退3格，按落点结算。",[CardEffect(kind:.moveRelative,delta:-3)]),
   c(8,.chance,"变数","法庭紧急传票","城市法院要求你暂时停止所有行程。","直接入狱，不领取经过起点收入。",[CardEffect(kind:.goToJail)]),
   c(9,.chance,"支出","物业安全检修","建筑审核员完成了消防与结构检查。","每座房屋支付 ¥90，每座旅馆支付 ¥320。",[CardEffect(kind:.repair,perHouse:90,perHotel:320)]),
   c(10,.chance,"支出","通行资质更新","年度商用道路资质需要重新登记。","向银行支付 ¥350。",cash(-350)),
   c(11,.chance,"旅程","海港商业洽谈","一场新航线合作谈判将在木板路举行。","前往第39格木板路，按落点结算。",move(39)),
   c(12,.chance,"机遇","午夜特快列车","你得到一次免费的远程会议铁路通行机会。","前往最近的铁路，按正常租金结算。",nearest(.railroad)),
   c(13,.chance,"机遇","原创专利授权","一家企业获得了你的原创设计使用许可。","从银行领取 ¥800。",cash(800)),
   c(14,.chance,"支出","供应链合同清算","延迟交付导致你必须支付一笔协议结算费。","向银行支付 ¥500。",cash(-500)),
   c(15,.chance,"机遇","技术顾问签约","城市实验室认可了你的咨询方案。","从银行领取 ¥400。",cash(400))
  ]
  let fate: [VeilopolyCityLongCardBlueprint] = [
   c(16,.chest,"旅程","风向归港","经历一段起伏旅途，船只终于归航。","前往起点，按本局规则领取经过起点收入。",move(0)),
   c(17,.chest,"收获","市政公共项目补助","年度项目审议通过，城市拨付你一笔建设补贴。","从银行领取 ¥550。",cash(550)),
   c(18,.chest,"支出","健康管理账单","年度健康保障计划送来了服务费用清单。","向银行支付 ¥280。",cash(-280)),
   c(19,.chest,"收获","年度税务核算","会计师审核了去年的文件，发现一笔退税。","从银行领取 ¥420。",cash(420)),
   c(20,.chest,"互动","生日宴会的来客","四方友人齐聚宴会，送来了一份份礼金。","每名未破产的其他玩家向你支付 ¥100。",[CardEffect(kind:.cash,amount:100,target:.allOthers)]),
   c(21,.chest,"特权","监狱长的特别函件","一份守护自由的手写许可将被妥善保管。","获得一张出狱卡；如已有同类卡，改领 ¥250。",[CardEffect(kind:.jailCard)]),
   c(22,.chest,"变数","命运的传召","一次司法听证改变了你原定的行程。","直接入狱，不领取经过起点收入。",[CardEffect(kind:.goToJail)]),
   c(23,.chest,"支出","旧屋修缮工程","连续降雨使你的房产需要重新维护。","每座房屋支付 ¥80，每座旅馆支付 ¥280。",[CardEffect(kind:.repair,perHouse:80,perHotel:280)]),
   c(24,.chest,"收获","证券历史分红凭单","一张上一年度的结算凭证被核实有效。","从银行领取固定 ¥420；不改动本局股票持仓。",cash(420)),
   c(25,.chest,"支出","设备维护支出","城市设施的例行保养产生了一项费用。","向银行支付 ¥250。",cash(-250)),
   c(26,.chest,"收获","旧资产结算","多年前的一项设备转让终于完成付款。","从银行领取 ¥300；不出售本局资产。",cash(300)),
   c(27,.chest,"收获","项目年度奖励","团队完成了一项长期城市规划项目。","从银行领取 ¥600。",cash(600)),
   c(28,.chest,"支出","继续教育费用","你报名了一个管理与建筑课程。","向银行支付 ¥180。",cash(-180)),
   c(29,.chest,"收获","保险理赔审核","保险公司核对了旧合同，确认理赔条件。","从银行领取 ¥350。",cash(350)),
   c(30,.chest,"收获","家族财产结算","公证人交付了已经完成审验的继承款项。","从银行领取 ¥580。",cash(580)),
   c(31,.chest,"支出","合同争议和解","双方同意通过一笔固定费用结束争端。","向银行支付 ¥300。",cash(-300))
  ]
  return chance + fate
 }()

 public static let all: [CardDefinition] = blueprints.map(\.canonical)
 /// Future only: the two special building grants use existing card IDs.
 public static let blueprintsV4: [VeilopolyCityLongCardBlueprint] = blueprints.map { old in
  if old.id == 13 {
   return .init(id: 13, deck: .chance, category: "机遇", title: "城市建设特许令",
    story: "市政厅批准在你的街区免费建设一栋住宅。",
    ruling: "在合法自有完整街区免费建一栋房屋；无合法位置或银行无房时领取 ¥800。",
    effects: [CardEffect(kind: .grantHouse, amount: 800)])
  }
  if old.id == 27 {
   return .init(id: 27, deck: .chest, category: "命运", title: "旧城复兴工程",
    story: "城市建设局决定无偿资助一栋街区住宅。",
    ruling: "在合法自有完整街区免费建一栋房屋；无合法位置或银行无房时领取 ¥600。",
    effects: [CardEffect(kind: .grantHouse, amount: 600)])
  }
  return old
 }
 public static let allV4: [CardDefinition] = blueprintsV4.map(\.canonical)

 /// New V5 card denominations track the larger circulation scale, with EXACT
 /// printed amounts. Old V3/V4 card arrays remain untouched for saved replay.
 public static let blueprintsV5: [VeilopolyCityLongCardBlueprint] = blueprintsV4.map { original in
  var effects = original.effects
  var ruling = original.ruling
  for i in effects.indices {
   var effect = effects[i]
   if (effect.kind == .cash || effect.kind == .grantHouse),
      let amount = effect.amount {
    let adjusted = amount * 4
    ruling = ruling.replacingOccurrences(of: "¥\(abs(amount))",
                                         with: "¥\(abs(adjusted))")
    effect.amount = adjusted
   }
   if effect.kind == .repair {
    if let price = effect.perHouse {
     ruling = ruling.replacingOccurrences(of: "¥\(price)",
                                          with: "¥\(price * 4)")
     effect.perHouse = price * 4
    }
    if let price = effect.perHotel {
     ruling = ruling.replacingOccurrences(of: "¥\(price)",
                                          with: "¥\(price * 4)")
     effect.perHotel = price * 4
    }
   }
   effects[i] = effect
  }
  if effects.contains(where: { $0.kind == .jailCard }) {
   ruling = ruling.replacingOccurrences(of: "¥250", with: "¥1,000")
  }
  return .init(id: original.id, deck: original.deck, category: original.category,
               title: original.title, story: original.story,
               ruling: ruling, effects: effects)
 }
 public static let allV5: [CardDefinition] = blueprintsV5.map(\.canonical)

 /// Editorial is only displayed for an exact canonical match. Custom cards,
 /// legacy saves and modified effect arrays cannot masquerade as V3 copy.
 public static func presentation(for card: CardDefinition) -> VeilopolyCardEditorialEntry? {
  if let blueprint = blueprintsV5.first(where: {
   $0.id == card.id && $0.deck == card.deck &&
   $0.canonical == card && $0.canonical != allV4[$0.id]
  }) {
   let marker = String(format: "VL-CITY-V5-%@-%03d",
    blueprint.deck == .chance ? "CH" : "FT", blueprint.id)
   return VeilopolyCardEditorialEntry(blueprint.id, marker, blueprint.deck,
    blueprint.category, blueprint.title, blueprint.story, blueprint.ruling)
  }
  if (card.id == 13 || card.id == 27),
     let blueprint = blueprintsV4.first(where: {
   $0.id == card.id && $0.deck == card.deck && $0.canonical == card
  }) {
   let marker = String(format: "VL-CITY-V4-%@-%03d",
     blueprint.deck == .chance ? "CH" : "FT", blueprint.id)
   return VeilopolyCardEditorialEntry(blueprint.id, marker, blueprint.deck,
      blueprint.category, blueprint.title, blueprint.story, blueprint.ruling)
  }
  guard let blueprint = blueprints.first(where: { $0.id == card.id && $0.deck == card.deck }),
        blueprint.canonical == card else { return nil }
  return blueprint.editorial
 }

 /// Decks reshuffle after every complete 16-card cycle, using a separate
 /// deterministic local stream. No mutation of the dice or market RNG.
 public static func reshuffleOnCycle(_ deck: inout DeckState, kind: DeckKind, seed: UInt64) {
  guard deck.order.count > 1, deck.cursor > 0,
        deck.cursor % deck.order.count == 0 else { return }
  var localCounter: UInt64 = 0
  let domain: UInt64 = kind == .chance ? 0x4348414E43455F33 : 0x464154455F56335F
  let cycle = UInt64(deck.cursor / deck.order.count)
  seededShuffle(&deck.order,
                seed: seed ^ domain ^ (cycle &* 0x9E3779B97F4A7C15),
                counter: &localCounter)
 }
}
