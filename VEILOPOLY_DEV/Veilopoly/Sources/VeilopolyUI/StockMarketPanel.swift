#if os(iOS) && canImport(SwiftUI)
import Foundation
import SwiftUI
import VeilopolyEngine

private enum StockTicketSide: String, CaseIterable, Identifiable {
 case buy = "买入"
 case sell = "卖出"
 var id: String { rawValue }
}

private enum StockTerminalPalette {
 // Deep teal instrument display within the same ivory/antique-gold board.
 static let ink = Color(red: 0.047, green: 0.17, blue: 0.18)
 static let panel = Color(red: 0.11, green: 0.26, blue: 0.27)
 static let gold = Color(red: 0.75, green: 0.59, blue: 0.34)
 static let up = Color(red: 0.94, green: 0.57, blue: 0.44)
 static let down = Color(red: 0.47, green: 0.82, blue: 0.67)
 static let flat = Color(red: 0.77, green: 0.77, blue: 0.71)
 static func direction(_ basisPoints: Int) -> Color {
  basisPoints > 0 ? up : (basisPoints < 0 ? down : flat)
 }
}

/// Compact landscape trading terminal. Every amount comes from the same engine
/// estimate used by order execution; the view never invents a display-only price.
public struct VeilopolyStockMarketPanel: View {
 public let market: StockMarketState
 public let player: Int
 public let cash: Int
 public let executions: [StockExecution]
 public let orderError: String?
 /// Authoritative game-wide restriction, separate from quote/fee math.
 public let buyRestriction: String?
 @Binding public var selectedSymbol: String
 @Binding public var shareText: String
 public let onBuy: (String, Int) -> Void
 public let onSell: (String, Int) -> Void

 @State private var ticketSide: StockTicketSide = .buy
 @State private var positionsExpanded = true
 @Environment(\.accessibilityReduceMotion) private var reduceMotion

 public init(market: StockMarketState, player: Int, cash: Int,
             selectedSymbol: Binding<String>, shareText: Binding<String>,
             executions: [StockExecution] = [], orderError: String? = nil,
             buyRestriction: String? = nil,
             onBuy: @escaping (String, Int) -> Void,
             onSell: @escaping (String, Int) -> Void) {
  self.market = market; self.player = player; self.cash = cash
  self.executions = executions; self.orderError = orderError
  self.buyRestriction = buyRestriction
  _selectedSymbol = selectedSymbol; _shareText = shareText
  self.onBuy = onBuy; self.onSell = onSell
 }

 public var body: some View {
  VStack(alignment: .leading, spacing: 10) {
   terminalHeader
   tickerStrip
   if let quote = StockMarketEngine.quote(market, symbol: selectedSymbol) ?? market.quotes.first {
    quoteHero(quote)
    if let issuer = VeilopolyMarketEditorial.issuer(for: quote) {
     HStack(alignment: .top, spacing: 6) {
      Image(systemName: "building.2.crop.circle")
       .foregroundStyle(StockTerminalPalette.gold)
       .accessibilityHidden(true)
      Text("\(issuer.subtitle) · \(issuer.summary)")
       .foregroundStyle(Color(red: 0.94, green: 0.90, blue: 0.81))
       .fixedSize(horizontal: false, vertical: true)
     }
     .font(.system(size: 10, weight: .regular, design: .serif))
     .padding(.horizontal, 8).padding(.vertical, 6)
     .frame(maxWidth: .infinity, alignment: .leading)
     .background(StockTerminalPalette.gold.opacity(0.11),
                 in: RoundedRectangle(cornerRadius: 8))
     .accessibilityElement(children: .combine)
    }
    VeilopolyStockLineChart(quote: quote).frame(height: 152)
    quoteMetrics(quote)
    Text(VeilopolyMarketEditorial.regimeNotice(market))
     .font(.system(size: 10, weight: .medium, design: .serif))
     .foregroundStyle(StockTerminalPalette.gold)
     .fixedSize(horizontal: false, vertical: true)
    Text(VeilopolyMarketEditorial.quoteNotice(quote))
     .font(.system(size: 9))
     .foregroundStyle(.white.opacity(0.75))
     .fixedSize(horizontal: false, vertical: true)
    orderTicket(quote)
    portfolioSection
    executionHistory
   } else {
    Label("行情暂不可用", systemImage: "exclamationmark.triangle")
     .font(.caption).foregroundStyle(.secondary)
   }
   Text(market.algorithmVersion == 3
    ? "城市长局行情 V3 · 更大报价与波动 · 合同级手续费 · 可存档重放"
    : market.algorithmVersion == 2
     ? "虚构行情 · 每局随机走势 V2 · 可存档重放"
     : "虚构行情 · 历史对局兼容算法 V1")
    .font(.system(size: 9, weight: .medium))
    .foregroundStyle(.white.opacity(0.42))
    .frame(maxWidth: .infinity, alignment: .center)
  }
  .padding(12)
  .background {
   LinearGradient(colors: [StockTerminalPalette.panel, StockTerminalPalette.ink],
                  startPoint: .topLeading, endPoint: .bottomTrailing)
  }
  .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  .overlay {
   RoundedRectangle(cornerRadius: 16, style: .continuous)
    .stroke(LinearGradient(colors: [StockTerminalPalette.gold.opacity(0.55), .white.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
  }
  // An ivory-gold bezel keeps the working dark-teal screen visually bonded
  // to the single classical board without reducing white-on-teal legibility.
  .padding(3)
  .background(Color(red: 0.96, green: 0.93, blue: 0.86),
              in: RoundedRectangle(cornerRadius: 19, style: .continuous))
  .overlay {
   RoundedRectangle(cornerRadius: 19, style: .continuous)
    .strokeBorder(StockTerminalPalette.gold, lineWidth: 1.5)
    .allowsHitTesting(false)
  }
  .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
  .accessibilityElement(children: .contain)
  // The terminal's existing art/price chart remains a dark instrument island;
  // its numeric sheet separately follows the selected table theme.
  .environment(\.colorScheme, .dark)
 }

 private var terminalHeader: some View {
  VStack(alignment: .leading, spacing: 5) {
   HStack(spacing: 7) {
    ZStack {
     RoundedRectangle(cornerRadius: 6).fill(StockTerminalPalette.gold.opacity(0.16))
     Image(systemName: "chart.xyaxis.line").foregroundStyle(StockTerminalPalette.gold)
    }
    .frame(width: 30, height: 30)
    VStack(alignment: .leading, spacing: 0) {
     Text("VEIL EXCHANGE").font(.system(size: 12, weight: .bold, design: .rounded))
      .tracking(1.1)
     Text("城市证券交易所 · 离线行情").font(.system(size: 9, weight: .medium))
      .foregroundStyle(.white.opacity(0.52))
    }
    Spacer(minLength: 4)
    HStack(spacing: 4) {
     Circle().fill(market.quotes.contains(where: { $0.isHalted }) ? Color.orange : StockTerminalPalette.down)
      .frame(width: 6, height: 6)
     Text(market.quotes.contains(where: { $0.isHalted }) ? "部分暂停" : "运行中")
      .font(.system(size: 9, weight: .semibold))
    }
    .padding(.horizontal, 7).padding(.vertical, 5)
    .background(.white.opacity(0.06), in: Capsule())
   }
   HStack(spacing: 7) {
    Text("T+\(market.tick)").font(.system(size: 9, weight: .bold, design: .monospaced))
    ProgressView(value: Double(market.tick % StockMarketEngine.sessionTicks),
                 total: Double(StockMarketEngine.sessionTicks))
     .tint(StockTerminalPalette.gold)
    Text(regimeName(market.regime)).font(.system(size: 9, weight: .semibold))
     .foregroundStyle(StockTerminalPalette.gold)
   }
  }
 }

 private var tickerStrip: some View {
  ScrollView(.horizontal, showsIndicators: false) {
   HStack(spacing: 7) {
    ForEach(market.quotes) { quote in
     let selected = quote.symbol == selectedSymbol
     Button { selectedSymbol = quote.symbol } label: {
      VStack(alignment: .leading, spacing: 3) {
       HStack(spacing: 5) {
        Text(quote.symbol).font(.system(size: 10, weight: .bold, design: .monospaced))
        if quote.isHalted {
         Image(systemName: "pause.fill").font(.system(size: 7)).foregroundStyle(.orange)
        }
       }
       Text(price(quote.currentPriceCents)).font(.system(size: 11, weight: .bold, design: .monospaced))
       HStack(spacing: 4) {
        StockMiniChart(quote: quote).frame(width: 38, height: 12)
        Text(percent(quote.changeBasisPoints)).font(.system(size: 8, weight: .semibold, design: .monospaced))
       }
       .foregroundStyle(StockTerminalPalette.direction(quote.changeBasisPoints))
      }
      .frame(width: 78, alignment: .leading)
      .padding(.horizontal, 8).padding(.vertical, 7)
      .background(selected ? StockTerminalPalette.gold.opacity(0.13) : .white.opacity(0.045),
                  in: RoundedRectangle(cornerRadius: 9))
      .overlay {
       RoundedRectangle(cornerRadius: 9)
        .stroke(selected ? StockTerminalPalette.gold.opacity(0.9) : .white.opacity(0.07),
                lineWidth: selected ? 1.2 : 1)
      }
     }
     .buttonStyle(.plain)
     .accessibilityLabel("\(quote.name)，\(price(quote.currentPriceCents))，\(percent(quote.changeBasisPoints))")
    }
   }
  }
 }

 private func quoteHero(_ quote: StockQuote) -> some View {
  HStack(alignment: .bottom, spacing: 8) {
   VStack(alignment: .leading, spacing: 2) {
    HStack(spacing: 6) {
     Text(quote.symbol).font(.system(size: 18, weight: .heavy, design: .rounded))
     Text(quote.name).font(.system(size: 12, weight: .semibold))
      .foregroundStyle(.white.opacity(0.72))
    }
    Text("\(quote.sector) · 成交量 \(compactNumber(quote.sessionVolume))")
     .font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.46))
   }
   Spacer(minLength: 4)
   VStack(alignment: .trailing, spacing: 1) {
    Text(price(quote.currentPriceCents))
     .font(.system(size: 24, weight: .heavy, design: .monospaced))
    Text(percent(quote.changeBasisPoints))
     .font(.system(size: 11, weight: .bold, design: .monospaced))
     .foregroundStyle(StockTerminalPalette.direction(quote.changeBasisPoints))
   }
  }
  .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: quote.currentPriceCents)
  .accessibilityElement(children: .combine)
 }

 private func quoteMetrics(_ quote: StockQuote) -> some View {
  HStack(spacing: 6) {
   metric("今开", quote.sessionOpenCents)
   metric("最高", quote.highCents)
   metric("最低", quote.lowCents)
   metric("昨收", quote.previousCloseCents)
  }
 }

 private func metric(_ title: String, _ cents: Int) -> some View {
  VStack(alignment: .leading, spacing: 2) {
   Text(title).font(.system(size: 8, weight: .medium)).foregroundStyle(.white.opacity(0.42))
   Text(price(cents)).font(.system(size: 9, weight: .semibold, design: .monospaced))
  }
  .frame(maxWidth: .infinity, alignment: .leading)
  .padding(6)
  .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
 }

 private func orderTicket(_ quote: StockQuote) -> some View {
  let quantity = max(0, Int(shareText) ?? 0)
  let portfolio = market.portfolios.indices.contains(player) ? market.portfolios[player] : StockPortfolio()
  let owned = portfolio.position(symbol: quote.symbol)?.shares ?? 0
  let maxBuy = buyRestriction == nil
   ? StockMarketEngine.maximumBuyableShares(market, player: player,
                                            symbol: quote.symbol, cash: cash)
   : 0
  let estimate: StockTradeEstimate? = {
   if ticketSide == .buy {
    return try? StockMarketEngine.estimateBuy(market, player: player,
                                              symbol: quote.symbol, shares: quantity)
   }
   return try? StockMarketEngine.estimateSell(market, player: player,
                                               symbol: quote.symbol, shares: quantity)
  }()
  let rejection = StockTerminalState.rejection(market: market, player: player,
   cash: cash, symbol: quote.symbol, shares: quantity, buying: ticketSide == .buy,
   buyRestriction: buyRestriction)
  let enabled = rejection == nil
  return VStack(alignment: .leading, spacing: 9) {
   HStack {
    Text("订单").font(.system(size: 11, weight: .bold))
    Spacer()
    Text(ticketSide == .buy ? "可买 \(maxBuy) 股" : "持有 \(owned) 股")
     .font(.system(size: 9, weight: .semibold, design: .monospaced))
     .foregroundStyle(.white.opacity(0.54))
   }
   Text("可用现金 ¥\(cash) · 市价即时成交")
    .font(.caption2).foregroundStyle(.secondary)
   Picker("交易方向", selection: $ticketSide) {
    ForEach(StockTicketSide.allCases) { side in Text(side.rawValue).tag(side) }
   }
   .pickerStyle(.segmented)
   .accessibilityLabel("交易方向")

   HStack(spacing: 7) {
    VeilopolyNumericInput(title: "股数", text: $shareText, bounds: 1...10_000, showsTitle: false)
     .font(.system(size: 15, weight: .bold, design: .monospaced))
     .padding(.horizontal, 10).frame(height: 44)
     .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 9))
     .overlay { RoundedRectangle(cornerRadius: 9).stroke(.white.opacity(0.10)) }
     .accessibilityLabel("交易股数")
    Stepper("", value: Binding(
     get: { max(1, min(10_000, Int(shareText) ?? 1)) },
     set: { shareText = String($0) }), in: 1...10_000)
     .labelsHidden().fixedSize()
   }
   // Narrow landscape drawers cannot fit five 44pt buttons in one row.
   // Wrap instead of silently shrinking quantity hit regions below 44pt.
   LazyVGrid(columns: [GridItem(.adaptive(minimum: CGFloat(VeilopolyLandscapeLayout.minimumControlTouchSide)), spacing: 5)], spacing: 5) {
    ForEach([1, 5, 10, 100], id: \.self) { preset in
     quantityButton("\(preset)") { shareText = String(preset) }
    }
    quantityButton("最大") {
     shareText = String(ticketSide == .buy ? maxBuy : min(10_000, owned))
    }
   }

   if let estimate {
    HStack {
     VStack(alignment: .leading, spacing: 2) {
      Text("成交额 ¥\(estimate.grossCash) · 手续费 ¥\(estimate.fee)")
      Text(ticketSide == .buy ? "预计支出 ¥\(-estimate.cashDelta)" : "预计到账 ¥\(estimate.cashDelta)")
       .fontWeight(.semibold).foregroundStyle(.white.opacity(0.88))
     }
     Spacer(minLength: 2)
     Text("@ \(price(estimate.priceCents))").font(.system(size: 9, design: .monospaced))
    }
    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.50))
   }
   if let rejection {
    Text(rejection)
     .font(.system(size: 9, weight: .semibold))
     .foregroundStyle(quote.isHalted ? Color.orange : StockTerminalPalette.up)
   }
   if let orderError {
    Label("上一笔订单：" + orderError, systemImage: "exclamationmark.circle")
     .font(.caption2).foregroundStyle(.orange)
   }

   Button {
    if ticketSide == .buy { onBuy(quote.symbol, quantity) }
    else { onSell(quote.symbol, quantity) }
   } label: {
    HStack {
     Image(systemName: ticketSide == .buy ? "arrow.up.right" : "arrow.down.right")
     Text("\(ticketSide.rawValue) \(quote.symbol) · \(quantity) 股")
     Spacer()
     Image(systemName: "chevron.right").font(.caption)
    }
    .font(.system(size: 12, weight: .bold))
    .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
    .background(
     LinearGradient(colors: ticketSide == .buy
      ? [StockTerminalPalette.up, StockTerminalPalette.up.opacity(0.68)]
      : [StockTerminalPalette.down, StockTerminalPalette.down.opacity(0.64)],
      startPoint: .leading, endPoint: .trailing),
     in: RoundedRectangle(cornerRadius: 10))
   }
   .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.38)
   .accessibilityHint(enabled ? "按当前模拟价格提交订单" : "当前订单不可提交")
  }
  .padding(10)
  .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
  .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.07)) }
 }

 private func quantityButton(_ title: String, action: @escaping () -> Void) -> some View {
  Button(action: action) {
   Text(title).font(.system(size: 9, weight: .semibold))
    .frame(minWidth: CGFloat(VeilopolyLandscapeLayout.minimumControlTouchSide),
           maxWidth: .infinity,
           minHeight: CGFloat(VeilopolyLandscapeLayout.minimumControlTouchSide))
    .contentShape(Rectangle())
    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
  }
  .buttonStyle(.plain)
 }

 private var portfolioSection: some View {
  let portfolio = market.portfolios.indices.contains(player) ? market.portfolios[player] : StockPortfolio()
  let value = StockMarketEngine.portfolioMarketValueCents(market, player: player)
  let unrealized = StockMarketEngine.unrealizedPnLCents(market, player: player)
  return VStack(alignment: .leading, spacing: 8) {
   Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { positionsExpanded.toggle() } } label: {
    HStack {
     Text("我的持仓").font(.system(size: 11, weight: .bold))
     Text("\(portfolio.positions.count)").font(.system(size: 9, weight: .bold))
      .padding(.horizontal, 6).padding(.vertical, 2)
      .background(StockTerminalPalette.gold.opacity(0.15), in: Capsule())
     Spacer()
     Image(systemName: positionsExpanded ? "chevron.up" : "chevron.down").font(.caption2)
    }
    .frame(minWidth: CGFloat(VeilopolyLandscapeLayout.minimumControlTouchSide),
           minHeight: CGFloat(VeilopolyLandscapeLayout.minimumControlTouchSide))
    .contentShape(Rectangle())
   }
   .buttonStyle(.plain)
   .accessibilityValue(positionsExpanded ? "已展开" : "已收起")
   HStack(spacing: 6) {
    portfolioMetric("市值", money(value), .white)
    portfolioMetric("浮动", signedMoney(unrealized), pnlColor(unrealized))
    portfolioMetric("已实现", signedMoney(portfolio.realizedPnLCents), pnlColor(portfolio.realizedPnLCents))
   }
   if positionsExpanded {
    if portfolio.positions.isEmpty {
     HStack(spacing: 7) {
      Image(systemName: "tray").foregroundStyle(.white.opacity(0.35))
      Text("暂无持仓，先选择上方标的建立仓位。")
     }
     .font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.48))
     .padding(.vertical, 5)
    } else {
     ForEach(portfolio.positions) { position in positionRow(position) }
    }
   }
  }
  .padding(10)
  .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
 }

 private func portfolioMetric(_ title: String, _ value: String, _ color: Color) -> some View {
  VStack(alignment: .leading, spacing: 2) {
   Text(title).font(.system(size: 8)).foregroundStyle(.white.opacity(0.40))
   Text(value).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(color)
  }
  .frame(maxWidth: .infinity, alignment: .leading)
 }

 private func positionRow(_ position: StockPosition) -> some View {
  let quote = StockMarketEngine.quote(market, symbol: position.symbol)
  let current = quote?.currentPriceCents ?? position.averageCostCents
  let pnl = position.shares * (current - position.averageCostCents)
  return Button { selectedSymbol = position.symbol } label: {
   HStack(spacing: 7) {
    VStack(alignment: .leading, spacing: 1) {
     Text(position.symbol).font(.system(size: 10, weight: .bold, design: .monospaced))
     Text("\(position.shares) 股").font(.system(size: 8)).foregroundStyle(.white.opacity(0.42))
    }
    VStack(alignment: .leading, spacing: 1) {
     Text("成本 \(price(position.averageCostCents))")
     Text("现价 \(price(current))")
    }
    .font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.48))
    Spacer()
    Text(signedMoney(pnl)).font(.system(size: 10, weight: .bold, design: .monospaced))
     .foregroundStyle(pnlColor(pnl))
   }
   .padding(.vertical, 6).padding(.horizontal, 7)
   .frame(minWidth: CGFloat(VeilopolyLandscapeLayout.minimumControlTouchSide),
          minHeight: CGFloat(VeilopolyLandscapeLayout.minimumControlTouchSide))
   .contentShape(Rectangle())
   .background(position.symbol == selectedSymbol ? StockTerminalPalette.gold.opacity(0.09) : .clear,
               in: RoundedRectangle(cornerRadius: 7))
  }
  .buttonStyle(.plain)
 }

 private var executionHistory: some View {
  VStack(alignment: .leading, spacing: 8) {
   Text("本局成交回执").font(.subheadline.weight(.semibold))
   if executions.isEmpty {
    Text("暂无成交。订单成功后将在此显示回执。")
     .font(.caption2).foregroundStyle(.secondary)
   }
   ForEach(Array(executions.prefix(8))) { execution in
    VStack(alignment: .leading, spacing: 3) {
     HStack {
      Text("\(execution.bought ? "买入" : "卖出") \(execution.symbol) · \(execution.shares) 股")
       .foregroundStyle(execution.bought ? StockTerminalPalette.up : StockTerminalPalette.down)
      Spacer()
      Text("#\(execution.id)").foregroundStyle(.secondary)
     }
     Text("成交价 \(price(execution.priceCents)) · 现金 \(execution.cashDelta >= 0 ? "+" : "−")¥\(abs(execution.cashDelta))")
      .foregroundStyle(.secondary)
    }
    .font(.caption2).monospacedDigit()
    .accessibilityElement(children: .combine)
   }
  }
  .padding(10)
  .frame(maxWidth: .infinity, alignment: .leading)
  .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
 }

 private func price(_ cents: Int) -> String {
  let value = max(0, cents); return "¥\(value / 100).\(String(format: "%02d", value % 100))"
 }
 private func money(_ cents: Int) -> String { price(cents) }
 private func signedMoney(_ cents: Int) -> String {
  cents < 0 ? "−\(price(-cents))" : "+\(price(cents))"
 }
 private func percent(_ basisPoints: Int) -> String {
  let sign = basisPoints > 0 ? "+" : (basisPoints < 0 ? "−" : "")
  let value = abs(basisPoints)
  return "\(sign)\(value / 100).\(String(format: "%02d", value % 100))%"
 }
 private func pnlColor(_ cents: Int) -> Color {
  cents > 0 ? StockTerminalPalette.up : (cents < 0 ? StockTerminalPalette.down : .white.opacity(0.64))
 }
 private func compactNumber(_ value: Int) -> String {
  if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
  if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
  return "\(value)"
 }
 private func regimeName(_ value: Int) -> String {
  switch value { case -2: return "深度回调"; case -1: return "偏弱"
  case 1: return "偏强"; case 2: return "强势"; default: return "震荡" }
 }
}

private struct StockMiniChart: View {
 let quote: StockQuote
 var body: some View {
  let points = Array(quote.history.suffix(18))
  let color = StockTerminalPalette.direction(quote.changeBasisPoints)
  Canvas { context, size in
   guard points.count > 1, let low = points.map(\.priceCents).min(),
         let high = points.map(\.priceCents).max() else { return }
   let spread = max(1, high - low)
   var line = Path()
   for (index, point) in points.enumerated() {
    let x = size.width * CGFloat(index) / CGFloat(points.count - 1)
    let y = size.height - CGFloat(point.priceCents - low) / CGFloat(spread) * size.height
    index == 0 ? line.move(to: CGPoint(x: x, y: y)) : line.addLine(to: CGPoint(x: x, y: y))
   }
   context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
  }
  .accessibilityHidden(true)
 }
}
#endif
