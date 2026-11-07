#if os(iOS) && canImport(SwiftUI)
import Foundation
import SwiftUI
import VeilopolyEngine

/// Separate from the decision drawer: no order callbacks, Move construction or
/// editable finance fields. Live GameState remains owned by GameSessionModel.
struct VeilopolyAssetBrowser: View {
 let game: GameState
 @State private var selectedPlayer: Int
 @State private var section: VeilopolyManagementSection = .property
 @State private var showAllTiles = false
 @State private var selectedSymbol = "VTL"
 @State private var showAchievementJournal = false
 @Environment(\.dismiss) private var dismiss

 init(game: GameState, initialPlayer: Int) {
  self.game = game
  _selectedPlayer = State(initialValue: initialPlayer)
 }

 private var snapshot: VeilopolyAssetBrowserSnapshot? {
  VeilopolyAssetBrowserSnapshot(game: game, player: selectedPlayer)
 }

 var body: some View {
  VStack(spacing: 8) {
   header
   HStack(spacing: 4) {
    ForEach(VeilopolyManagementSection.allCases) { item in
     Button { section = item } label: {
      Label(item.rawValue, systemImage: item.symbol)
       .font(.caption.weight(.semibold))
       .frame(maxWidth: .infinity, minHeight: 44)
       .contentShape(Rectangle())
       .background(section == item ? Color.accentColor.opacity(0.16) : Color.clear,
                   in: RoundedRectangle(cornerRadius: 8))
     }
     .buttonStyle(.plain)
     .accessibilityAddTraits(section == item ? .isSelected : [])
    }
   }
   ScrollView {
    if let snapshot {
     VStack(alignment: .leading, spacing: 14) {
      summary(snapshot)
      sectionContent(snapshot)
     }
     .frame(maxWidth: .infinity, alignment: .leading)
     .padding(.bottom, 12)
    } else {
     Text("请选择有效席位").padding()
    }
   }
   // Price ticks and animation ACKs must not throw the reader back to the top.
   .id("\(game.seed)-\(selectedPlayer)-\(section.rawValue)")
  }
  .padding(12)
  .background(Color(uiColor: .systemBackground).ignoresSafeArea())
  .foregroundColor(.primary)
  .sheet(isPresented: $showAchievementJournal) {
   VeilopolyAchievementJournal(game: game, player: selectedPlayer)
  }
 }

 private var header: some View {
  VStack(alignment: .leading, spacing: 4) {
   HStack {
    Text("资产资料 · 只读").font(.headline)
    Spacer()
    Button { dismiss() } label: {
     Text("返回对局").frame(minWidth: 88, minHeight: 44).contentShape(Rectangle())
    }
     .accessibilityHint("关闭资料，回到原来的购买、竞价或回合操作")
   }
   HStack {
    Picker("查看席位", selection: $selectedPlayer) {
     ForEach(Array(game.players.enumerated()), id: \.offset) { index, player in
      Text(player.name + (player.bankrupt ? "（已破产）" : "")).tag(index)
     }
    }
    .pickerStyle(.menu)
    .frame(minWidth: 88, minHeight: 44)
    Spacer(minLength: 4)
    Button { showAchievementJournal = true } label: {
     Label("成就档案", systemImage: "rosette")
      .font(.caption.weight(.semibold))
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.bordered)
    .accessibilityHint("查看本局累计行动里程碑和当前资产目标，不会提交游戏操作")
   }
   Text("仅查看，不提交操作；对局与行情继续更新")
    .font(.caption2).foregroundColor(.secondary)
    .fixedSize(horizontal: false, vertical: true)
  }
 }

 private func summary(_ data: VeilopolyAssetBrowserSnapshot) -> some View {
  VStack(alignment: .leading, spacing: 5) {
   Text("\(data.player.name) · 现金 ¥\(data.summary.cash)")
    .font(.headline).monospacedDigit()
   Text("账面净资产 ¥\(data.summary.netWorth) · 贷款应还 ¥\(data.summary.liabilities)")
    .font(.subheadline).monospacedDigit()
   Text("账面净资产不是可用现金；查看资料不会购买、拍卖、借款或成交。")
    .font(.caption).foregroundColor(.secondary)
   if let bankCash = game.banking?.reserveCash {
    Text("城市银行 ¥\(bankCash) / 总货币量 ¥\(VeilopolyCityLongEconomy.supplyCeiling(game) ?? 0) · 宏观股市信号 \(VeilopolyCityLongEconomy.marketPressure(game)) bp")
     .font(.caption2).foregroundColor(.secondary)
     .fixedSize(horizontal: false, vertical: true)
   }
   if VeilopolyCityLongEconomy.isActive(game) {
    Text("城市长局 · 本期单次地块租金上限 ¥\(VeilopolyCityLongEconomy.rentCeiling(game))；随有效结算期逐渐上调。铁路及公用事业基础租金按长局规模调整。")
     .font(.caption2).foregroundColor(.secondary)
     .fixedSize(horizontal: false, vertical: true)
   }
  }
  .accessibilityElement(children: .combine)
 }

 @ViewBuilder
 private func sectionContent(_ data: VeilopolyAssetBrowserSnapshot) -> some View {
  switch section {
  case .property: propertySection(data)
  case .bank: bankSection(data)
  case .market: marketSection(data)
  case .trade: tradeSection
  }
 }

 private func propertySection(_ data: VeilopolyAssetBrowserSnapshot) -> some View {
  VStack(alignment: .leading, spacing: 12) {
   Toggle("查看全部 40 格（含其他玩家地产）", isOn: $showAllTiles)
    .frame(minHeight: 44)
   if !showAllTiles && data.properties.isEmpty { Text("该席位尚无地产。可切换查看全部棋盘。") }
   ForEach(showAllTiles ? game.board : data.properties, id: \.i) { tile in
    VStack(alignment: .leading, spacing: 5) {
     Text("\(tile.i) · \(tile.name)").font(.headline)
     Text("持有人：\(tile.owner.map(playerName) ?? "无主")")
     if tile.purchasable {
      Text("牌面价格 ¥\(tile.price) · \(tile.mortgaged ? "已抵押" : "未抵押")")
      Text("房屋 \(tile.houses) · 旅馆 \(tile.hotel ? "有" : "无") · 建造单价 ¥\(tile.houseCost)")
      Text("牌面租金表：" + tile.rent.map { String($0) }.joined(separator: " / "))
       .font(.caption).foregroundColor(.secondary)
      Text("实际租金由当前色组、建筑及骰子规则裁定，不等同于上述全部档位。")
       .font(.caption2).foregroundColor(.secondary)
     }
    }
    .accessibilityElement(children: .combine)
    Divider()
   }
  }
 }

 private func bankSection(_ data: VeilopolyAssetBrowserSnapshot) -> some View {
  VStack(alignment: .leading, spacing: 10) {
   Text("存款本金 ¥\(data.summary.savings) · 投资本金 ¥\(data.summary.investments)")
   if let account = data.account {
    Text("账本期数 \(data.completedTurns ?? 0) · 仅显示已签订合同")
     .font(.caption).foregroundColor(.secondary)
    if account.savings.isEmpty && account.loans.isEmpty && account.positions.isEmpty {
     Text("暂无存款、贷款或待结算投资合同。")
    }
    ForEach(account.savings, id: \.id) { saving in
     Text("存款 #\(saving.id)：本金 ¥\(saving.principal)，第 \(saving.unlockPeriod) 期可取")
      .accessibilityElement(children: .combine)
    }
    ForEach(account.loans, id: \.id) { loan in
     Text("贷款 #\(loan.id)：本金 ¥\(loan.principal)，约定应还 ¥\(loan.totalDue)，第 \(loan.duePeriod) 期到期")
      .accessibilityElement(children: .combine)
    }
    ForEach(account.positions, id: \.id) { position in
     Text("投资 #\(position.id)：本金 ¥\(position.principal)，第 \(position.duePeriod) 期待结算；非保证收益")
    }
   } else {
    Text("该局尚未建立银行账本。查看资料不会创建账户或改变对局。")
   }
  }
 }

 @ViewBuilder
 private func marketSection(_ data: VeilopolyAssetBrowserSnapshot) -> some View {
  if let market = data.market {
   VStack(alignment: .leading, spacing: 10) {
    Text("离线虚构行情 · Tick \(market.tick) · 只读，不含下单控件")
     .font(.caption).foregroundColor(.secondary)
    ScrollView(.horizontal) {
     HStack {
      ForEach(market.quotes) { quote in
       Button { selectedSymbol = quote.symbol } label: {
        Text(quote.symbol).frame(minWidth: 60, minHeight: 44)
       }
       .buttonStyle(.bordered)
       .accessibilityAddTraits(selectedSymbol == quote.symbol ? .isSelected : [])
      }
     }
    }
    if let quote = market.quotes.first(where: { $0.symbol == selectedSymbol }) ?? market.quotes.first {
     Text("\(quote.name) · ¥\(price(quote.currentPriceCents)) · \(quote.isHalted ? "暂停交易" : "交易中")")
      .font(.headline).monospacedDigit()
     VeilopolyStockLineChart(quote: quote)
      .frame(height: 152).padding(8)
      .background(Color(red: 0.047, green: 0.17, blue: 0.18), in: RoundedRectangle(cornerRadius: 10))
    }
    if market.portfolios.indices.contains(selectedPlayer) {
     let portfolio = market.portfolios[selectedPlayer]
     Text("当前持仓市值 ¥\(data.summary.stocks)")
     if portfolio.positions.isEmpty { Text("暂无股票持仓") }
     ForEach(portfolio.positions) { position in
      Text("\(position.symbol)：\(position.shares) 股 · 每股成本 ¥\(price(position.averageCostCents))")
     }
    }
   }
  } else {
   Text("该局尚未建立模拟行情。只读浏览不会初始化市场或消耗随机数。")
  }
 }

 private var tradeSection: some View {
  VStack(alignment: .leading, spacing: 10) {
   if let trade = game.trade {
    Text("待响应交易：\(playerName(trade.from)) → \(playerName(trade.to))").font(.headline)
    Text("提出方交付：" + transferDescription(trade.offer))
    Text("对方交付：" + transferDescription(trade.request))
    Text("接受、拒绝或反报价请返回原决策面板；本页不会改变合同。")
     .font(.caption).foregroundColor(.secondary)
   } else { Text("当前没有待响应交易。") }
   Divider()
   ForEach(game.players, id: \.id) { player in
    Text("\(player.name)：现金 ¥\(player.cash)，地产 \(game.board.filter { $0.owner == player.id }.count) 块\(player.bankrupt ? "（已破产）" : "")")
   }
   Text("仅供查看公开资产，不会发起或接受交易。")
    .font(.caption).foregroundColor(.secondary)
  }
 }

 private func playerName(_ index: Int) -> String {
  game.players.indices.contains(index) ? game.players[index].name : "未知席位"
 }
 private func transferDescription(_ transfer: TradeTransfer) -> String {
  let tiles = transfer.tiles.map { index in
   game.board.first { $0.i == index }?.name ?? "未知地块"
  }.joined(separator: "、")
  return "¥\(transfer.cash)；地产：\(tiles.isEmpty ? "无" : tiles)；机会出狱卡 \(transfer.chanceCards)，命运出狱卡 \(transfer.chestCards)"
 }
 private func price(_ cents: Int) -> String { String(format: "%.2f", Double(cents) / 100) }
}
#endif
