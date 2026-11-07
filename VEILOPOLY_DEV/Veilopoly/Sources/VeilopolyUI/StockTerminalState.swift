import VeilopolyEngine
import VeilopolyPersistence

/// A bounded, session-local view of actual reducer executions, not submitted orders.
public struct StockExecution: Equatable, Identifiable {
 public let id: Int
 public let symbol: String
 public let shares: Int
 public let priceCents: Int
 public let cashDelta: Int
 public let bought: Bool
 public let player: Int
 public init?(sequence: Int, effect: Effect) {
  guard effect.kind == .stockBought || effect.kind == .stockSold,
        let symbol = effect.stockSymbol, let shares = effect.stockShares,
        let price = effect.stockPriceCents, let delta = effect.amount,
        let player = effect.player else { return nil }
  self.id = sequence; self.symbol = symbol; self.shares = shares
  self.priceCents = price; self.cashDelta = delta; self.bought = effect.kind == .stockBought
  self.player = player
 }
 /// The full receipt survives relaunch in the SAME A/B checkpoint as GameState.
 public var persisted: VeilopolyStockExecutionRecord {
  VeilopolyStockExecutionRecord(id: id, symbol: symbol, shares: shares,
   priceCents: priceCents, cashDelta: cashDelta, bought: bought, player: player)
 }
 public init(record: VeilopolyStockExecutionRecord) {
  self.id=record.id; self.symbol=record.symbol; self.shares=record.shares
  self.priceCents=record.priceCents; self.cashDelta=record.cashDelta
  self.bought=record.bought; self.player=record.player
 }
}

public enum StockTerminalState {
 /// Human-readable rejection reason for the exact current order, including
 /// cash overflow on sales and fractional-price minimum-fee edge cases.
 public static func rejection(market: StockMarketState, player: Int, cash: Int,
                              symbol: String, shares: Int, buying: Bool,
                              buyRestriction: String? = nil) -> String? {
  if buying, let buyRestriction { return buyRestriction }
  guard (1...10_000).contains(shares) else { return "单笔股数需在 1…10,000 之间" }
  do {
   let estimate = try buying
    ? StockMarketEngine.estimateBuy(market, player: player, symbol: symbol, shares: shares)
    : StockMarketEngine.estimateSell(market, player: player, symbol: symbol, shares: shares)
   if buying && -estimate.cashDelta > cash { return "可用现金不足（含手续费）" }
   if !buying && cash > 1_000_000_000 - estimate.cashDelta { return "到账后将超过现金上限" }
   return nil
  } catch let error as GameError {
   switch error {
   case .stockTradingHalted: return "该标的暂停交易，请等待恢复"
   case .insufficientShares: return "可卖数量不足"
   case .stockNotFound: return "标的不存在"
   default: return buying ? "超过持仓上限或订单无效" : "成交额不足以覆盖最低手续费"
   }
  } catch { return "订单暂不可提交" }
 }

 public static func chartIndex(fraction: Double, count: Int) -> Int? {
  guard count > 0, fraction.isFinite else { return nil }
  return Int((max(0, min(1, fraction)) * Double(count - 1)).rounded())
 }
}
