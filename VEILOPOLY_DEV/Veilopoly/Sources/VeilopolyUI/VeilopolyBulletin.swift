import Foundation
import VeilopolyEngine

public struct VeilopolyBulletin: Equatable, Identifiable {
 public enum Category: String { case event, market, city }
 public let id: String
 public let topic: String
 public let text: String
 public let category: Category
 public let priority: Int
 public init(id: String, topic: String, text: String, category: Category, priority: Int) {
  self.id = id; self.topic = topic; self.text = text
  self.category = category; self.priority = priority
 }
}

/// Presentation-only local radio. Financial notices are made exclusively from
/// committed reducer effects. City vignettes never claim rewards/rule changes.
public enum VeilopolyBulletinCopy {
 public static let cityLines = [
  "街角的咖啡馆亮起暖灯，城市又迎来一场新的相遇。",
  "晚风翻动报亭里的晨报，沿街店铺正在等待下一位顾客。",
  "钟楼响起整点钟声，广场上的行人放慢了脚步。",
  "一辆老电车穿过街口，车窗映着新修的橱窗。",
  "公园的喷泉重新亮灯，散步的人沿着石阶走向湖边。",
  "街区广播试播了一段老唱片，咖啡香从巷口飘来。",
  "城市摄影展今天开幕，展厅里挂满旧街道的照片。",
  "书店把旅行地图摆到门口，有人开始计划下一段行程。",
  "雨后的石板路泛着微光，远处传来列车进站的声音。",
  "码头的船笛轻轻响起，岸边的小店收起了遮阳棚。",
  "小剧院正在排练新节目，海报贴满了广场旁的公告栏。",
  "邻里的花市换上了新鲜盆栽，窗台多了几抹绿色。",
  "夜班邮差穿过长街，一封封来函被送到各家门前。",
  "老钟表店整理了橱窗，铜制指针映出午后的日光。",
  "广场上的街头乐队开始演奏，路人停下来听完一曲。",
  "城市档案馆展出老地契，纸页里留着街区从前的名字。",
  "中央车站换了一张新时刻表，候车厅依旧人来人往。",
  "海边吹来清凉的风，露台上的茶杯还冒着热气。",
  "小巷的面包房提前开门，第一炉面包刚刚出炉。",
  "市民读书会在图书馆集合，今天聊的是城市的旧故事。",
  "黄昏染亮屋顶的铜边，广场上又响起熟悉的钟声。",
  "街角举办小型手作集市，摊位间挂起了一串暖灯。",
  "一封没有落款的明信片，被夹在书店新到的画册里。",
  "车站旁的茶室推出新茶，窗边的位置很快坐满了人。",
  "公园小径铺满落叶，摄影师正等待一束合适的光。",
  "老港口的航海展延长开放，孩子们围着船模讨论航线。",
  "报童骑车穿过广场，把今天的城市剪影送向各条街巷。",
  "屋顶花园迎来第一批访客，远处的城市轮廓格外清晰。",
  "礼帽店换了新的门铃，每次推门都会响起清脆的一声。",
  "晚间电台收到一首点播，送给仍在路上的每一位旅人。",
  "石桥下的水面映着灯火，城市的另一场故事刚刚开篇。",
  "广场花匠给长椅刷了新漆，等风吹干后就能坐下歇脚。",
  "城市博物馆收进一枚旧车票，讲解员又多了一个故事。",
  "玻璃屋里的植物迎着晨光，洒水壶在石台上留下水痕。",
  "路边的手风琴响起轻快曲调，有人跟着节拍走向车站。",
  "旧街的招牌逐盏亮起，这座城市还没有准备入睡。"
 ]
 public static let eventTemplates: [String: [String]] = [
  "income": ["{player} 收到 ¥{amount}，新一笔收入已入账。", "城市账讯：{player} 获得 ¥{amount}。", "{player} 的账本新增收入 ¥{amount}。", "好消息，{player} 收到了 ¥{amount}。"],
  "spend": ["{player} 支付 ¥{amount}，本次款项已结算。", "城市账讯：{player} 支出 ¥{amount}。", "{player} 完成一笔 ¥{amount} 的支付。", "账本更新，{player} 划出 ¥{amount}。"],
  "rent": ["{player} 向 {other} 支付「{tile}」租金 ¥{amount}。", "租约结算：{other} 收到来自 {player} 的 ¥{amount}。", "「{tile}」完成收租，{other} 收入 ¥{amount}。", "街区账讯：{player} 支付租金 ¥{amount}，收款人为 {other}。"],
  "purchase": ["{player} 以 ¥{amount} 获得「{tile}」。", "新地契落款，「{tile}」归入 {player} 名下。", "地产快讯：{player} 登记了「{tile}」的产权。", "「{tile}」迎来新主人：{player}。"],
  "auction": ["拍卖落槌，{player} 以 ¥{amount} 拍得「{tile}」。", "「{tile}」竞拍结束，成交价 ¥{amount}。", "公开竞价成交：{player} 获得「{tile}」。", "拍卖行快讯：{player} 为「{tile}」签下地契。"],
  "build": ["「{tile}」的新建筑已登记，{player} 完成本次建设。", "工务快讯：{player} 提升了「{tile}」的建筑等级。", "「{tile}」传来工务回执，新建筑已建成。", "{player} 的「{tile}」换上了新的建筑轮廓。"],
  "mortgage": ["{player} 抵押了「{tile}」，该地产暂不收租。", "银号登记：「{tile}」进入抵押状态。", "「{tile}」产权仍在，抵押期间暂停收租。"],
  "redeem": ["{player} 赎回「{tile}」，地产恢复收租。", "赎回手续办结，「{tile}」恢复正常状态。", "「{tile}」的抵押记录已解除。"],
  "trade": ["{player} 与 {other} 完成交割，地产与款项已更新。", "契约签署，{player} 与 {other} 达成交易。", "交易所收到一份新契约，双方已完成交割。"],
  "buy": ["{player} 买入 {symbol} ×{shares}，支出 ¥{amount}。", "证券回执：{player} 完成 {symbol} 买入。", "{player} 新增 {symbol} 持仓 {shares} 股。"],
  "sell": ["{player} 卖出 {symbol} ×{shares}，到账 ¥{amount}。", "证券回执：{player} 完成 {symbol} 卖出。", "{player} 出售 {symbol} {shares} 股，资金已结算。"],
  "halt": ["交易所公告：{symbol} 暂停交易，请等待恢复。", "{symbol} 触及模拟涨跌幅限制，交易暂歇。"],
  "bank": ["银号快讯：{player} 有一笔账目进入到期处理期。", "{player} 的银行账本有了到期提醒，可前往柜台查看。"],
  "card": ["{player} 收到一封新的{deck}来函。", "城市邮局：一份{deck}来函已送达 {player}。", "{player} 打开了本轮的{deck}来函。"],
  "win": ["终局公报：{player} 成为本局胜者。", "本局落幕，城市为 {player} 留下胜者落款。"],
  "bankrupt": ["清算公报：{player} 已按本局规则退出。", "{player} 完成破产清算，本局由其余玩家继续。"]
 ]
 private static func pick(_ lines: [String], seed: UInt64, sequence: Int, salt: UInt64 = 0) -> String {
  var counter: UInt64 = 0
  let s = seed ^ UInt64(max(0, sequence)) &* 0x9E3779B97F4A7C15 ^ salt
  return lines[Int(seededRNG(seed: s, counter: &counter) % UInt64(lines.count))]
 }
 public static func city(seed: UInt64, sequence: Int) -> VeilopolyBulletin {
  .init(id: "city-\(sequence)", topic: "city-\(sequence)",
        text: "城市剪影 · " + pick(cityLines, seed: seed, sequence: sequence, salt: 0x43495459),
        category: .city, priority: 0)
 }
 public static func event(_ effects: [Effect], state: GameState, sequence: Int) -> VeilopolyBulletin? {
  func name(_ id: Int?) -> String? {
   guard let id, state.players.indices.contains(id) else { return nil }; return state.players[id].name
  }
  var choices: [VeilopolyBulletin] = []
  for effect in effects {
   guard let player = name(effect.player) else { continue }
   let tile = effect.tile.flatMap { state.board.indices.contains($0) ? state.board[$0].name : nil }
   var key: String; var priority = 40
   switch effect.kind {
   case .gameWon: key = "win"; priority = 100
   case .bankrupt: key = "bankrupt"; priority = 95
   case .rentPaid:
    guard name(effect.to) != nil, let amount = effect.amount, amount > 0,
          state.pendingDebt?.player != effect.player else { continue }
    key = "rent"; priority = 70
   case .bought: key = "purchase"; priority = 65
   case .auctionWon: key = "auction"; priority = 75
   case .built: key = "build"; priority = 60
   case .mortgaged: key = "mortgage"; priority = 55
   case .redeemed: key = "redeem"; priority = 55
   case .traded: key = "trade"; priority = 65
   case .stockBought, .stockSold:
    guard effect.stockSymbol != nil, let shares = effect.stockShares, shares > 0,
          let delta = effect.amount, delta != 0 else { continue }
    key = effect.kind == .stockBought ? "buy" : "sell"; priority = 45
   case .passedGo, .cashChanged:
    guard let amount = effect.amount, amount != 0 else { continue }
    key = amount > 0 ? "income" : "spend"; priority = amount > 0 ? 40 : 20
   case .bankMatured: key = "bank"; priority = 50
   case .cardDrawn: key = "card"; priority = 15
   default: continue
   }
   if ["purchase", "auction", "build", "mortgage", "redeem"].contains(key) && tile == nil { continue }
   let tokens = ["{player}": player, "{other}": name(effect.to) ?? "对方",
                 "{tile}": tile ?? "", "{amount}": String((effect.amount ?? 0).magnitude),
                 "{symbol}": effect.stockSymbol ?? "", "{shares}": String(effect.stockShares ?? 0),
                 "{deck}": effect.deck == .chest ? "命运" : "机会"]
   let lines = eventTemplates[key] ?? []
   guard !lines.isEmpty else { continue }
   let salt = key.utf8.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1) }
   var text = pick(lines, seed: state.seed, sequence: sequence, salt: salt)
   for (token, value) in tokens { text = text.replacingOccurrences(of: token, with: value) }
   choices.append(.init(id: "event-\(sequence)-\(key)", topic: "\(key)-\(effect.player ?? -1)-\(effect.tile ?? -1)",
                        text: text, category: .event, priority: priority))
  }
  return choices.enumerated().max {
   $0.element.priority == $1.element.priority ? $0.offset < $1.offset : $0.element.priority < $1.element.priority
  }?.element
 }
 public static func market(before: StockMarketState?, after: StockMarketState?, sequence: Int) -> VeilopolyBulletin? {
  guard let before, let after else { return nil }
  if let quote = after.quotes.first(where: { q in q.isHalted && before.quotes.first { $0.symbol == q.symbol }?.isHalted == false }) {
   let text = pick(eventTemplates["halt"]!, seed: after.seed, sequence: sequence)
    .replacingOccurrences(of: "{symbol}", with: quote.symbol)
   return .init(id: "halt-\(sequence)", topic: "halt-\(quote.symbol)", text: text, category: .market, priority: 80)
  }
  guard before.regime != after.regime else { return nil }
  let moods = [-2: "深度回调", -1: "偏弱", 0: "震荡", 1: "偏强", 2: "强势"]
  return .init(id: "market-\(sequence)", topic: "market-mood", text: "交易所快讯 · 盘面转为\(moods[after.regime] ?? "震荡")，各标的价格继续变动。",
               category: .market, priority: 35)
 }
}

public struct VeilopolyBulletinFeed {
 public private(set) var current: VeilopolyBulletin?
 public private(set) var queued: [VeilopolyBulletin] = []
 public static let capacity = 6
 public static let displaySeconds = 14.0
 private var now = 0.0
 private var currentEnds = 0.0
 private var nextAllowed = 0.0
 private var lastCity = -45.0
 private var citySequence = 0
 private var seen: [String: Double] = [:]
 public init() {}
 public mutating func enqueue(_ notice: VeilopolyBulletin) {
  guard !notice.text.isEmpty, notice.text.count <= 120,
        seen[notice.id] == nil,
        !queued.contains(where: { $0.topic == notice.topic }),
        !seen.contains(where: { $0.key == "topic:" + notice.topic && now - $0.value < 60 }) else { return }
  seen[notice.id] = now; seen["topic:" + notice.topic] = now
  if seen.count > 64 {
   for key in seen.keys.sorted(by: { seen[$0]! < seen[$1]! }).prefix(seen.count - 64) { seen.removeValue(forKey: key) }
  }
  if notice.priority >= 90 && current?.category == .city { current = nil; nextAllowed = now }
  queued.append(notice)
  queued = queued.enumerated().sorted {
   $0.element.priority == $1.element.priority ? $0.offset < $1.offset : $0.element.priority > $1.element.priority
  }.map(\.element)
  queued = Array(queued.prefix(Self.capacity))
  presentIfPossible()
 }
 public mutating func advance(by seconds: Double, seed: UInt64) {
  guard seconds.isFinite, seconds > 0 else { return }
  now += min(seconds, 30)
  if current != nil && now >= currentEnds { current = nil; nextAllowed = now + 8 }
  if current == nil && queued.isEmpty && now - lastCity >= 45 && now >= nextAllowed {
   let notice = VeilopolyBulletinCopy.city(seed: seed, sequence: citySequence)
   citySequence += 1; lastCity = now; enqueue(notice)
  }
  presentIfPossible()
 }
 private mutating func presentIfPossible() {
  guard current == nil, now >= nextAllowed, !queued.isEmpty else { return }
  current = queued.removeFirst(); currentEnds = now + Self.displaySeconds
 }
}
