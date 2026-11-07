import Foundation

/// Editorial layer for the provisional 16 Chance + 16 Fate cards.
/// This file NEVER changes the Engine's cash, travel or jail effects.
public struct VeilopolyCardEditorialEntry: Equatable {
 public let id: Int
 public let stableID: String
 public let deck: DeckKind
 public let category: String
 public let title: String
 public let story: String
 public let ruling: String
 public init(_ id: Int, _ stableID: String, _ deck: DeckKind,
             _ category: String, _ title: String, _ story: String, _ ruling: String) {
  self.id=id; self.stableID=stableID; self.deck=deck
  self.category=category; self.title=title; self.story=story; self.ruling=ruling
 }
}

public enum VeilopolyCardEditorial {
 public static let edition = "VEILOPOLY-IVORY-CARD-TEXT-V1"
 public static let source = "SampleCards.all / 16 + 16 provisional engine fixture"
 public static let chanceName = "机会"
 public static let fateName = "命运"
 public static let style = "象牙白纸纹 / 古金细线 / 深青绿文字"

 /// A display-only editorial catalog indexed by the stable sample-card ID.
 /// The 32 canonical gameplay effects, RNG order, persisted cards and hashes
 /// remain under GameState/Rules, not this human-readable text layer.
 public static let entries: [VeilopolyCardEditorialEntry] = [
  .init(0, "VL-TEXT-CH-000", .chance, "旅程", "晨钟再响", "钟楼传来清晨的第一声钟响。你的旅程，从最初的广场重新展开。", "立即前往起点；按现行规则领取起点奖励。"),
  .init(1, "VL-TEXT-CH-001", .chance, "旅程", "红色大道的请柬", "伊利诺伊大道送来一封烫金请柬，马车已经在街角等候。", "前往第24格「伊利诺伊大道」；经过起点按规则结算。"),
  .init(2, "VL-TEXT-CH-002", .chance, "旅程", "广场上的舞会", "圣查尔斯广场的灯火刚刚点亮，一场舞会为你留出了席位。", "前往第11格「圣查尔斯广场」；经过起点按规则结算。"),
  .init(3, "VL-TEXT-CH-003", .chance, "旅程", "城市供能巡查", "城市的灯光与水脉需要一次例行巡访，沿途的账目另有约定。", "前往最近的公共事业；若需支付租金，本次按2倍结算。"),
  .init(4, "VL-TEXT-CH-004", .chance, "旅程", "特快列车通行证", "旧车站的月台传来汽笛，一张加急车票送到了你手中。", "前往最近的铁路；若需支付租金，本次按2倍结算。"),
  .init(5, "VL-TEXT-CH-005", .chance, "收获", "银行的分红函", "银行信使递来一只封蜡信封，里面是一张本期收益通知。", "从银行领取 ¥50。"),
  .init(6, "VL-TEXT-CH-006", .chance, "特权", "自由通行文书", "法务官在一张特许证书上签下名字，为未来留下周旋余地。", "获得一张出狱卡；可留存，并依规则使用或交易。"),
  .init(7, "VL-TEXT-CH-007", .chance, "变数", "遗失的路线图", "导航员发现路书少了一页。你只得沿来时的石板路折返。", "后退3格，并依落点规则结算。"),
  .init(8, "VL-TEXT-CH-008", .chance, "变数", "法庭的传票", "一封加急传票送达，你必须立即前往司法处报到。", "直接入狱，不领取经过起点的奖励。"),
  .init(9, "VL-TEXT-CH-009", .chance, "支出", "庄园年度检修", "雨季之后，管家交来每栋建筑的维修清单。", "每栋房屋支付 ¥25；每座旅馆支付 ¥100。"),
  .init(10, "VL-TEXT-CH-010", .chance, "支出", "行政罚单", "市政厅核查了旧时的通行纪录，附上一笔应缴费用。", "向银行支付 ¥50。"),
  .init(11, "VL-TEXT-CH-011", .chance, "旅程", "海滨的邀约", "远方海岸寄来一张明信片，木板路正沐浴着金色夕阳。", "前往第39格「木板路」；经过起点按规则结算。"),
  .init(12, "VL-TEXT-CH-012", .chance, "旅程", "下一班列车", "售票员轻敲柜台：下一班列车即将离站。", "前往最近的铁路；若需支付租金，本次按2倍结算。"),
  .init(13, "VL-TEXT-CH-013", .chance, "收获", "古董鉴赏会", "一位收藏家看中了你的旧藏，交易以一纸凭证顺利落定。", "从银行领取 ¥150。"),
  .init(14, "VL-TEXT-CH-014", .chance, "支出", "庄园文书费用", "继承事务的最后一份文件需要缴纳登记费用。", "向银行支付 ¥100。"),
  .init(15, "VL-TEXT-CH-015", .chance, "收获", "报社的稿酬", "晚报刊出了你的城市随笔，编辑附上了稿费收据。", "从银行领取 ¥100。"),
  .init(16, "VL-TEXT-FT-016", .chest, "旅程", "返航的航线", "航海图上的归途被重新标记，命运引导你回到最初的港口。", "立即前往起点；按现行规则领取起点奖励。"),
  .init(17, "VL-TEXT-FT-017", .chest, "收获", "账簿中的意外", "银行的账目经过复核，发现一笔应当归还给你的款项。", "从银行领取 ¥150。"),
  .init(18, "VL-TEXT-FT-018", .chest, "支出", "医师的账单", "一份细致的诊疗账单送到府上，签收时正值雨夜。", "向银行支付 ¥100。"),
  .init(19, "VL-TEXT-FT-019", .chest, "收获", "退税通知书", "税务署寄来盖着印章的回函，先前多缴的款项现已退回。", "从银行领取 ¥150。"),
  .init(20, "VL-TEXT-FT-020", .chest, "收获", "生日的来宾", "宴会厅的钟声响起，城中的友人纷纷送来生日礼金。", "每位未破产的其他玩家向你支付 ¥50。"),
  .init(21, "VL-TEXT-FT-021", .chest, "特权", "监狱长的批文", "一份特许批文穿过厚重的铁门，为你保留一次通行机会。", "获得一张出狱卡；可留存，并依规则使用或交易。"),
  .init(22, "VL-TEXT-FT-022", .chest, "变数", "命运的传召", "司法大厅的钟声响起，你必须暂停行程，立即赴审。", "直接入狱，不领取经过起点的奖励。"),
  .init(23, "VL-TEXT-FT-023", .chest, "支出", "老宅的修缮", "风雨过后，老宅的屋瓦与旅馆的长廊都需要仔细修整。", "每栋房屋支付 ¥25；每座旅馆支付 ¥100。"),
  .init(24, "VL-TEXT-FT-024", .chest, "收获", "证券分红凭单", "一张旧日的分红凭单出现在书页之间，仍可兑付。", "从银行领取固定 ¥50；不改变当前股票持仓。"),
  .init(25, "VL-TEXT-FT-025", .chest, "支出", "药房的收据", "药剂师完成了配药，随信附来一张整洁的付款收据。", "向银行支付 ¥50。"),
  .init(26, "VL-TEXT-FT-026", .chest, "收获", "旧股票结算款", "多年前的一笔证券往来终于清账，余额已划入你的账户。", "从银行领取固定 ¥100；不出售当前股票持仓。"),
  .init(27, "VL-TEXT-FT-027", .chest, "收获", "市政荣誉奖章", "市政厅感谢你对城市建设的支持，并随奖章附上一笔奖金。", "从银行领取 ¥100。"),
  .init(28, "VL-TEXT-FT-028", .chest, "支出", "学塾的学费", "新学期的入学文书已备好，学费需在开课前缴清。", "向银行支付 ¥50。"),
  .init(29, "VL-TEXT-FT-029", .chest, "收获", "保险公司的来信", "保险人核对了你的旧保单，确认一笔应付的理赔款项。", "从银行领取 ¥100。"),
  .init(30, "VL-TEXT-FT-030", .chest, "收获", "封蜡遗嘱", "公证人拆开一封久藏的遗嘱，交付其中留给你的款项。", "从银行领取 ¥100。"),
  .init(31, "VL-TEXT-FT-031", .chest, "收获", "咨询署的回函", "你的专业建议得到采纳，事务所寄来了酬金。", "从银行领取 ¥50。"),
 ]
 /// Only show editorial copy when the loaded card EXACTLY matches a known
 /// provisional fixture. This protects historic saves, customized cards and
 /// future rule revisions against misleading UI descriptions.
 public static func presentation(for card: CardDefinition) -> VeilopolyCardEditorialEntry? {
  if let longEdition = VeilopolyCityLongCards.presentation(for: card) { return longEdition }
  guard let known = SampleCards.all.first(where: { $0.id == card.id && $0.deck == card.deck }),
        known.text == card.text, known.effects == card.effects
  else { return nil }
  return entries.first(where: { $0.id == card.id && $0.deck == card.deck })
 }
 public static func presentation(id: Int, deck: DeckKind, among cards: [CardDefinition])
   -> VeilopolyCardEditorialEntry? {
  guard let actual = cards.first(where: { $0.id == id && $0.deck == deck }) else { return nil }
  return presentation(for: actual)
 }
 public static func deckName(_ deck: DeckKind) -> String {
  deck == .chance ? chanceName : fateName
 }
}
