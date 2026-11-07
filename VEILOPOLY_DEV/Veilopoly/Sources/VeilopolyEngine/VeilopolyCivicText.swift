import Foundation

/// Render-only, snapshot-based classical ivory paperwork. It never changes
/// GameState, move execution, RNG, saved snapshots or network message hashes.
public struct VeilopolyCivicField: Equatable {
 public let label: String
 public let value: String
 public init(_ label: String, _ value: String) {
  self.label = label
  self.value = value
 }
}
public struct VeilopolyCivicDocument: Equatable {
 public let id: String
 public let title: String
 public let subtitle: String
 public let fields: [VeilopolyCivicField]
 public let note: String
 public init(id: String, title: String, subtitle: String,
             fields: [VeilopolyCivicField], note: String) {
  self.id = id; self.title = title; self.subtitle = subtitle
  self.fields = fields; self.note = note
 }
}

/// Read-only copy contract for six native Astra document surfaces.
/// Each field is built from an authoritative GameState snapshot only.
public enum VeilopolyCivicText {
 public static let edition = "VEILOPOLY-IVORY-CIVIC-R1"
 public static let minimumIOS = 15
 public static let styles = "象牙纸张 · 古金细边 · 深青绿印墨"

 private static func money(_ amount: Int) -> String { "¥\(amount)" }
 private static func playerName(_ state: GameState, _ index: Int?) -> String {
  guard let index, state.players.indices.contains(index) else { return "银行／未指定" }
  return state.players[index].name
 }
 private static func deedType(_ type: TileKind) -> String {
  switch type {
  case .street: return "街区地产"
  case .railroad: return "铁路产权"
  case .utility: return "公共事业"
  default: return "非产权地块"
  }
 }
 public static func deed(_ state: GameState, tileIndex: Int) -> VeilopolyCivicDocument? {
  guard state.board.indices.contains(tileIndex) else { return nil }
  let tile = state.board[tileIndex]
  guard tile.purchasable else { return nil }
  let ownership = tile.owner.flatMap { state.players.indices.contains($0) ? state.players[$0].name : nil }
  var fields = [
   VeilopolyCivicField("位置", "第\(tile.i)格 · \(tile.name)"),
   VeilopolyCivicField("产权种类", deedType(tile.kind)),
   VeilopolyCivicField("登记价", money(tile.price)),
   VeilopolyCivicField("当前所有者", ownership ?? "尚未登记")
  ]
  if tile.kind == .street {
   fields.append(VeilopolyCivicField("建筑状况",
    tile.hotel ? "旅馆 ×1" : (tile.houses > 0 ? "房屋 ×\(tile.houses)" : "未建造")))
   if let baseRent = tile.rent.first {
    fields.append(VeilopolyCivicField("基础租金", money(baseRent)))
   }
  }
  fields.append(VeilopolyCivicField("抵押状态", tile.mortgaged ? "已抵押" : "未抵押"))
  if let lore = VeilopolyWorldEditorial.page(for: tile) {
   fields.append(VeilopolyCivicField("城市札记", lore.story))
  }
  return VeilopolyCivicDocument(id: "VL-CIVIC-DEED-\(tile.i)",
   title: "地契登记簿", subtitle: "城市不动产登记 · 本局即时副本",
   fields: fields, note: "租金及可执行操作以本局引擎裁定为准；此文书不构成购买指令。")
 }

 public static func auction(_ state: GameState) -> VeilopolyCivicDocument? {
  guard let a = state.auction, state.board.indices.contains(a.tile) else { return nil }
  let name = state.board[a.tile].name
  let bidder = a.bidder.flatMap { state.players.indices.contains($0) ? state.players[$0].name : nil }
  return VeilopolyCivicDocument(id: "VL-CIVIC-AUCTION-\(a.tile)",
   title: "公开竞价公告", subtitle: "城市资产拍卖所 · 竞价尚未落槌",
   fields: [
    .init("拍卖标的", "#\(a.tile) · \(name)"),
    .init("当前最高价", money(a.currentBid)),
    .init("最高出价人", bidder ?? "暂未出现"),
    .init("下一位竞价者", playerName(state, a.turn)),
    .init("仍在竞价", "\(a.active.count) 位")
   ], note: "只有引擎确认成交后才发生产权转移；本公告不会自动出价。")
 }

 private static func transferDetails(_ transfer: TradeTransfer, board: [Tile]) -> String {
  let properties = transfer.tiles.map { index -> String in
   guard board.indices.contains(index) else { return "#\(index)（待核对）" }
   return board[index].name
  }
  let assets = properties.isEmpty ? "无地产" : properties.joined(separator: "、")
  return "现金\(money(transfer.cash))；地产：\(assets)；机会出狱卡\(transfer.chanceCards)张；命运出狱卡\(transfer.chestCards)张"
 }

 public static func trade(_ state: GameState) -> VeilopolyCivicDocument? {
  guard let t = state.trade, state.players.indices.contains(t.from),
        state.players.indices.contains(t.to) else { return nil }
  return VeilopolyCivicDocument(id: "VL-CIVIC-TRADE-\(t.from)-\(t.to)",
   title: "产权交换协议", subtitle: "双边议约 · 等待对方确认",
   fields: [
    .init("甲方", state.players[t.from].name),
    .init("乙方", state.players[t.to].name),
    .init("甲方提出", transferDetails(t.offer, board: state.board)),
    .init("向乙方请求", transferDetails(t.request, board: state.board))
   ], note: "本件为待决议提案，并非成交证明。还价、接受或拒绝以实时操作结果为准。")
 }

 public static func banking(_ state: GameState, player: Int) -> VeilopolyCivicDocument? {
  guard state.players.indices.contains(player) else { return nil }
  let ledger = state.banking
  let account: IntegratedBankAccount? = ledger.flatMap {
   $0.accounts.indices.contains(player) ? $0.accounts[player] : nil
  }
  var fields: [VeilopolyCivicField] = [
   .init("户名", state.players[player].name),
   .init("手持现金", money(state.players[player].cash))
  ]
  if let ledger {
   let savings = account?.savings.reduce(0) { $0 + $1.principal } ?? 0
   let loans = account?.loans.reduce(0) { $0 + $1.totalDue } ?? 0
   let investments = account?.positions.reduce(0) { $0 + $1.principal } ?? 0
   fields.append(contentsOf: [
    .init("存款本金", money(savings)),
    .init("贷款待偿总额", money(loans)),
    .init("投资本金", money(investments)),
    .init("账本期次", "\(ledger.completedTurns)")
   ])
  } else {
   fields.append(.init("账本状态", "尚未启用银行账本"))
  }
  return VeilopolyCivicDocument(id: "VL-CIVIC-BANK-\(player)",
   title: "银号往来存根", subtitle: "本局账本 · 当前账户快照",
   fields: fields, note: "本金、待偿金额与投资本金分列记录，不能直接相加为现金；以真实银行规则结算。")
 }

 public static func debt(_ state: GameState) -> VeilopolyCivicDocument? {
  guard let debt = state.pendingDebt, state.players.indices.contains(debt.player) else { return nil }
  return VeilopolyCivicDocument(id: "VL-CIVIC-DEBT-\(debt.player)",
   title: "债务清算通知", subtitle: "市政清算处 · 待偿还事项",
   fields: [
    .init("债务人", state.players[debt.player].name),
    .init("待支付", money(debt.amount)),
    .init("现有现金", money(state.players[debt.player].cash)),
    .init("债权人", debt.creditor == nil ? "银行／公共账户" : playerName(state, debt.creditor))
   ], note: "本通知不代表已宣告破产。最终清算和资产去向取决于玩家确认后的引擎处理。")
 }

 public static func settlement(_ state: GameState) -> VeilopolyCivicDocument? {
  guard let id = state.winner, state.players.indices.contains(id),
        state.turn.phase == .finished else { return nil }
  let victor = state.players[id]
  let holdings = state.board.filter { $0.owner == id }.count
  let eliminated = state.players.filter { $0.bankrupt }.count
  return VeilopolyCivicDocument(id: "VL-CIVIC-SETTLEMENT-\(id)",
   title: "终局结算公报", subtitle: "本局游戏结束 · 最终结果",
   fields: [
    .init("本局胜者", victor.name),
    .init("胜者持有现金", money(victor.cash)),
    .init("已登记产权", "\(holdings) 项"),
    .init("已破产玩家", "\(eliminated) 位"),
    .init("最终行动编号", "#\(state.nextSeq)")
   ], note: "胜负由引擎的破产淘汰规则确定；净资产排名请以完整结算面板为准。")
 }
}
