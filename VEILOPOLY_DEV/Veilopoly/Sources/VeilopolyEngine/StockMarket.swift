import Foundation

/// One deterministic point in the local simulated tape. Prices are integer cents;
/// volume is a fictional share count and never represents a real exchange feed.
public struct StockPricePoint: Codable, Equatable {
 public var tick: Int
 public var priceCents: Int
 public var volume: Int
 public init(tick: Int, priceCents: Int, volume: Int) {
  self.tick = tick; self.priceCents = priceCents; self.volume = volume
 }
}

public struct StockQuote: Codable, Equatable, Identifiable {
 public var id: String { symbol }
 public var symbol: String
 public var name: String
 public var sector: String
 public var basePriceCents: Int
 public var volatilityBasisPoints: Int
 public var driftBasisPoints: Int
 public var previousCloseCents: Int
 public var sessionOpenCents: Int
 public var currentPriceCents: Int
 public var highCents: Int
 public var lowCents: Int
 public var sessionVolume: Int
 public var haltedTicks: Int
 public var history: [StockPricePoint]

 public init(symbol: String, name: String, sector: String, basePriceCents: Int,
             volatilityBasisPoints: Int, driftBasisPoints: Int) {
  self.symbol = symbol; self.name = name; self.sector = sector
  self.basePriceCents = basePriceCents
  self.volatilityBasisPoints = volatilityBasisPoints
  self.driftBasisPoints = driftBasisPoints
  self.previousCloseCents = basePriceCents; self.sessionOpenCents = basePriceCents
  self.currentPriceCents = basePriceCents; self.highCents = basePriceCents
  self.lowCents = basePriceCents; self.sessionVolume = 0; self.haltedTicks = 0
  self.history = [StockPricePoint(tick: 0, priceCents: basePriceCents, volume: 0)]
 }

 public var changeBasisPoints: Int {
  guard previousCloseCents > 0 else { return 0 }
  return (currentPriceCents - previousCloseCents) * 10_000 / previousCloseCents
 }
 public var isHalted: Bool { haltedTicks > 0 }
}

public struct StockPosition: Codable, Equatable, Identifiable {
 public var id: String { symbol }
 public var symbol: String
 public var shares: Int
 public var averageCostCents: Int
 public init(symbol: String, shares: Int, averageCostCents: Int) {
  self.symbol = symbol; self.shares = shares; self.averageCostCents = averageCostCents
 }
}

public struct StockPortfolio: Codable, Equatable {
 public var positions: [StockPosition]
 public var realizedPnLCents: Int
 public var feesPaid: Int
 public init(positions: [StockPosition] = [], realizedPnLCents: Int = 0, feesPaid: Int = 0) {
  self.positions = positions; self.realizedPnLCents = realizedPnLCents; self.feesPaid = feesPaid
 }
 public func position(symbol: String) -> StockPosition? { positions.first { $0.symbol == symbol } }
}

public struct StockMarketState: Codable, Equatable {
 public var seed: UInt64
 public var rngCounter: UInt64
 public var tick: Int
 /// -2...2: deep bear, bear, neutral, bull, strong bull.
 public var regime: Int
 public var quotes: [StockQuote]
 public var portfolios: [StockPortfolio]
 /// 1 = original predictable 24-tick regime, 2 = variable-event seeded regime.
 /// Missing in historical JSON means 1. NEVER silently upgrade a saved match.
 public var algorithmVersion: Int
 public init(seed: UInt64, quotes: [StockQuote], playerCount: Int = 4,
             algorithmVersion: Int = 1) {
  self.seed = seed; self.rngCounter = 0; self.tick = 0; self.regime = 0
  self.quotes = quotes
  self.portfolios = Array(repeating: StockPortfolio(), count: playerCount)
  self.algorithmVersion = algorithmVersion
 }
 private enum CodingKeys: String, CodingKey {
  case seed, rngCounter, tick, regime, quotes, portfolios, algorithmVersion
 }
 public init(from decoder: Decoder) throws {
  let c = try decoder.container(keyedBy: CodingKeys.self)
  seed = try c.decode(UInt64.self, forKey: .seed)
  rngCounter = try c.decode(UInt64.self, forKey: .rngCounter)
  tick = try c.decode(Int.self, forKey: .tick)
  regime = try c.decode(Int.self, forKey: .regime)
  quotes = try c.decode([StockQuote].self, forKey: .quotes)
  portfolios = try c.decode([StockPortfolio].self, forKey: .portfolios)
  algorithmVersion = try c.decodeIfPresent(Int.self, forKey: .algorithmVersion) ?? 1
 }
 public func encode(to encoder: Encoder) throws {
  var c = encoder.container(keyedBy: CodingKeys.self)
  try c.encode(seed, forKey: .seed)
  try c.encode(rngCounter, forKey: .rngCounter)
  try c.encode(tick, forKey: .tick)
  try c.encode(regime, forKey: .regime)
  try c.encode(quotes, forKey: .quotes)
  try c.encode(portfolios, forKey: .portfolios)
  // Omitting the key for v1 keeps legacy sealed-save JSON and hash bit-for-bit.
  if algorithmVersion != 1 {
   try c.encode(algorithmVersion, forKey: .algorithmVersion)
  }
 }
}

public struct StockTradeReceipt: Equatable {
 public var symbol: String
 public var shares: Int
 public var priceCents: Int
 public var cashDelta: Int
 public var fee: Int
 public var realizedPnLCents: Int
}

/// Exact pre-trade cash calculation shared by the reducer and order-ticket UI.
/// Game cash is an integer credit; share prices and P&L retain cent precision.
public struct StockTradeEstimate: Equatable {
 public var symbol: String
 public var shares: Int
 public var priceCents: Int
 public var grossCash: Int
 public var fee: Int
 public var cashDelta: Int
 public init(symbol: String, shares: Int, priceCents: Int, grossCash: Int,
             fee: Int, cashDelta: Int) {
  self.symbol = symbol; self.shares = shares; self.priceCents = priceCents
  self.grossCash = grossCash; self.fee = fee; self.cashDelta = cashDelta
 }
}

/// Offline market micro-simulator. It borrows familiar market primitives—regime,
/// common factor, idiosyncratic volatility, mean reversion and a 10% session limit—
/// but contains no network call, wall clock, real company, recommendation or wager.
public enum StockMarketEngine {
 public static let sessionTicks = 60
 public static let maximumHistoryPoints = 96
 public static let feeBasisPoints = 50 // 0.50%, minimum one game-credit unit.

 public static func initial(seed: UInt64, enhanced: Bool = false) -> StockMarketState {
  let instruments = [
   StockQuote(symbol: "VTL", name: "维尔交通", sector: "交通", basePriceCents: 1_850,
              volatilityBasisPoints: 115, driftBasisPoints: 2),
   StockQuote(symbol: "AUR", name: "极光能源", sector: "能源", basePriceCents: 2_640,
              volatilityBasisPoints: 145, driftBasisPoints: 1),
   StockQuote(symbol: "MNT", name: "薄荷港湾", sector: "消费", basePriceCents: 1_180,
              volatilityBasisPoints: 90, driftBasisPoints: 2),
   StockQuote(symbol: "NOV", name: "新星工坊", sector: "工业", basePriceCents: 3_920,
              volatilityBasisPoints: 175, driftBasisPoints: 3),
   StockQuote(symbol: "ORB", name: "轨道系统", sector: "科技", basePriceCents: 5_200,
              volatilityBasisPoints: 210, driftBasisPoints: 4)
  ]
  let quotes = enhanced ? instruments.map { quote in
   StockQuote(symbol: quote.symbol, name: quote.name, sector: quote.sector,
              basePriceCents: quote.basePriceCents * 8,
              volatilityBasisPoints: min(500, quote.volatilityBasisPoints * 3 / 2),
              driftBasisPoints: quote.driftBasisPoints)
  } : instruments
  return StockMarketState(seed: seed ^ 0x5354_4F43_4B5F_4D4B,
                          quotes: quotes, algorithmVersion: enhanced ? 3 : 2)
 }

 public static func validate(_ market: StockMarketState) -> Bool {
  guard (1...3).contains(market.algorithmVersion),
        (0...1_000_000).contains(market.tick), (-2...2).contains(market.regime),
        market.portfolios.count == 4, (0...100_000_000).contains(market.rngCounter),
        market.quotes.count == 5,
        Set(market.quotes.map(\.symbol)).count == market.quotes.count else { return false }
  let symbols = Set(market.quotes.map(\.symbol))
  guard market.quotes.allSatisfy({ quote in
   !quote.symbol.isEmpty && !quote.name.isEmpty && (50...1_000_000).contains(quote.basePriceCents) &&
   (20...500).contains(quote.volatilityBasisPoints) && (-50...50).contains(quote.driftBasisPoints) &&
   (50...1_000_000).contains(quote.previousCloseCents) &&
   (50...1_000_000).contains(quote.sessionOpenCents) &&
   (50...1_000_000).contains(quote.currentPriceCents) &&
   quote.lowCents <= quote.currentPriceCents && quote.currentPriceCents <= quote.highCents &&
   (0...10_000_000).contains(quote.sessionVolume) && (0...2).contains(quote.haltedTicks) &&
   !quote.history.isEmpty && quote.history.count <= maximumHistoryPoints &&
   quote.history.last?.priceCents == quote.currentPriceCents &&
   quote.history.allSatisfy { (0...market.tick).contains($0.tick) &&
      (50...1_000_000).contains($0.priceCents) && (0...100_000).contains($0.volume) }
  }) else { return false }
  return market.portfolios.allSatisfy { portfolio in
   (-100_000_000_000...100_000_000_000).contains(portfolio.realizedPnLCents) &&
   (0...1_000_000_000).contains(portfolio.feesPaid) &&
   portfolio.positions.count <= symbols.count &&
   Set(portfolio.positions.map(\.symbol)).count == portfolio.positions.count &&
   portfolio.positions.allSatisfy { symbols.contains($0.symbol) &&
      (1...100_000).contains($0.shares) && (50...1_005_000).contains($0.averageCostCents) }
  }
 }

 public static func quote(_ market: StockMarketState, symbol: String) -> StockQuote? {
  market.quotes.first { $0.symbol == symbol }
 }

 public static func portfolioMarketValueCents(_ market: StockMarketState, player: Int) -> Int {
  guard market.portfolios.indices.contains(player) else { return 0 }
  return market.portfolios[player].positions.reduce(0) { total, position in
   guard let price = quote(market, symbol: position.symbol)?.currentPriceCents else { return total }
   return total + position.shares * price
  }
 }

 public static func unrealizedPnLCents(_ market: StockMarketState, player: Int) -> Int {
  guard market.portfolios.indices.contains(player) else { return 0 }
  return market.portfolios[player].positions.reduce(0) { total, position in
   guard let price = quote(market, symbol: position.symbol)?.currentPriceCents else { return total }
   return total + position.shares * (price - position.averageCostCents)
  }
 }

 public static func estimateBuy(_ market: StockMarketState, player: Int,
                                symbol: String, shares: Int) throws -> StockTradeEstimate {
  guard validate(market), market.portfolios.indices.contains(player),
        (1...10_000).contains(shares) else { throw GameError.invalidPayload }
  guard let quote = quote(market, symbol: symbol) else { throw GameError.stockNotFound }
  guard !quote.isHalted else { throw GameError.stockTradingHalted }
  let owned = market.portfolios[player].position(symbol: symbol)?.shares ?? 0
  guard owned <= 100_000 - shares else { throw GameError.invalidPayload }
  let grossCents = quote.currentPriceCents * shares
  let grossCash = (grossCents + 99) / 100
  let rate = market.algorithmVersion == 3 ? 25 : feeBasisPoints
  let fee = max(1, grossCash * rate / 10_000)
  guard grossCash <= 1_000_000_000 - fee else { throw GameError.invalidPayload }
  return StockTradeEstimate(symbol: symbol, shares: shares,
                            priceCents: quote.currentPriceCents,
                            grossCash: grossCash, fee: fee,
                            cashDelta: -(grossCash + fee))
 }

 public static func estimateSell(_ market: StockMarketState, player: Int,
                                 symbol: String, shares: Int) throws -> StockTradeEstimate {
  guard validate(market), market.portfolios.indices.contains(player),
        (1...10_000).contains(shares) else { throw GameError.invalidPayload }
  guard let quote = quote(market, symbol: symbol) else { throw GameError.stockNotFound }
  guard !quote.isHalted else { throw GameError.stockTradingHalted }
  let owned = market.portfolios[player].position(symbol: symbol)?.shares ?? 0
  guard owned >= shares else { throw GameError.insufficientShares }
  let grossCash = quote.currentPriceCents * shares / 100
  let rate = market.algorithmVersion == 3 ? 25 : feeBasisPoints
  let fee = max(1, grossCash * rate / 10_000)
  guard grossCash > fee else { throw GameError.invalidPayload }
  return StockTradeEstimate(symbol: symbol, shares: shares,
                            priceCents: quote.currentPriceCents,
                            grossCash: grossCash, fee: fee,
                            cashDelta: grossCash - fee)
 }

 /// Largest legal one-order purchase at the current quote. A binary search
 /// keeps the answer exact even around integer-credit rounding and min fees.
 public static func maximumBuyableShares(_ market: StockMarketState, player: Int,
                                         symbol: String, cash: Int) -> Int {
  guard cash > 0, market.portfolios.indices.contains(player),
        let quote = quote(market, symbol: symbol), !quote.isHalted else { return 0 }
  let owned = market.portfolios[player].position(symbol: symbol)?.shares ?? 0
  var low = 0
  var high = max(0, min(10_000, 100_000 - owned))
  while low < high {
   let middle = (low + high + 1) / 2
   guard let estimate = try? estimateBuy(market, player: player, symbol: symbol, shares: middle) else {
    high = middle - 1; continue
   }
   if -estimate.cashDelta <= cash { low = middle } else { high = middle - 1 }
  }
  return low
 }

 /// A failed tick never commits a half-advanced market (including RNG, quotes,
 /// volume, chart history and circuit breaker state).
 public static func advance(_ market: inout StockMarketState) throws -> [String] {
  var next = market
  let halted = try advanceChecked(&next)
  market = next
  return halted
 }

 private static func advanceChecked(_ market: inout StockMarketState) throws -> [String] {
  guard validate(market), market.tick < 1_000_000 else { throw GameError.invalidState }
  market.tick += 1
  var halted: [String] = []
  let isVariableMarket = market.algorithmVersion >= 2
  if isVariableMarket {
   // Seeded irregular transitions: no fixed tick teaches the next reversal.
   // The same stored seed/counter yields an identical replay and recovery.
   if random(in: 0...17, market: &market) == 0 {
    let step = random(in: -2...2, market: &market)
    market.regime = max(-2, min(2, market.regime + step))
   }
  } else if market.tick % 24 == 0 {
   // v1 legacy behavior and RNG consumption are intentionally untouched.
   market.regime = random(in: -2...2, market: &market)
  }
  let commonFactor = random(in: -45...45, market: &market)
  var sectorWinds = Array(repeating: 0, count: market.quotes.count)
  var headlineShock = 0
  if isVariableMarket {
   // One simulated macro news impulse plus distinct sector surprises, all
   // drawn from the MARKET RNG rather than the game's dice stream.
   for index in sectorWinds.indices {
    sectorWinds[index] = random(in: -38...38, market: &market)
   }
   if random(in: 0...61, market: &market) == 0 {
    headlineShock = random(in: -110...110, market: &market)
   }
  }
  for index in market.quotes.indices {
   if market.tick % sessionTicks == 1 && market.tick > 1 {
    let close = market.quotes[index].currentPriceCents
    market.quotes[index].previousCloseCents = close
    market.quotes[index].sessionOpenCents = close
    market.quotes[index].highCents = close; market.quotes[index].lowCents = close
    market.quotes[index].sessionVolume = 0
   }
   if market.quotes[index].haltedTicks > 0 {
    market.quotes[index].haltedTicks -= 1
    appendPoint(&market.quotes[index], tick: market.tick, volume: 0)
    continue
   }
   let quote = market.quotes[index]
   let idiosyncratic = random(in: -1_000...1_000, market: &market) * quote.volatilityBasisPoints / 1_000
   let deviation = (quote.basePriceCents - quote.currentPriceCents) * 10_000 / quote.basePriceCents
   let meanReversion = deviation / 32
   var eventShock = 0
   if random(in: 0...159, market: &market) == 0 {
    let magnitude = random(in: 300...720, market: &market)
    eventShock = random(in: 0...1, market: &market) == 0 ? -magnitude : magnitude
   }
   let baseMove = quote.driftBasisPoints + market.regime * 14 +
     commonFactor + idiosyncratic + meanReversion + eventShock +
     sectorWinds[index] + headlineShock
   let adjusted = market.algorithmVersion == 3 ? baseMove * 3 / 2 : baseMove
   let basisPoints = max(-900, min(900, adjusted))
   var delta = quote.currentPriceCents * basisPoints / 10_000
   if delta == 0 && basisPoints != 0 { delta = basisPoints > 0 ? 1 : -1 }
   let lowerLimit = max(50, quote.sessionOpenCents * 90 / 100)
   let upperLimit = min(1_000_000, quote.sessionOpenCents * 110 / 100)
   let candidate = max(lowerLimit, min(upperLimit, quote.currentPriceCents + delta))
   let volume = 50 + random(in: 0...450, market: &market) + abs(basisPoints) * 2
   market.quotes[index].currentPriceCents = candidate
   market.quotes[index].highCents = max(market.quotes[index].highCents, candidate)
   market.quotes[index].lowCents = min(market.quotes[index].lowCents, candidate)
   market.quotes[index].sessionVolume = min(10_000_000, market.quotes[index].sessionVolume + volume)
   if candidate == lowerLimit || candidate == upperLimit {
    market.quotes[index].haltedTicks = 2
    halted.append(quote.symbol)
   }
   appendPoint(&market.quotes[index], tick: market.tick, volume: volume)
  }
  guard validate(market) else { throw GameError.invalidState }
  return halted
 }

 public static func buy(_ market: inout StockMarketState, player: Int, symbol: String,
                        shares: Int, cash: inout Int) throws -> StockTradeReceipt {
  let estimate = try estimateBuy(market, player: player, symbol: symbol, shares: shares)
  var nextMarket = market
  var nextCash = cash
  let grossCents = estimate.priceCents * shares
  let totalCash = -estimate.cashDelta
  guard nextCash >= totalCash else { throw GameError.noCash }
  var portfolio = nextMarket.portfolios[player]
  if let index = portfolio.positions.firstIndex(where: { $0.symbol == symbol }) {
   let old = portfolio.positions[index]
   let combinedCost = old.averageCostCents * old.shares + grossCents + estimate.fee * 100
   portfolio.positions[index].shares += shares
   portfolio.positions[index].averageCostCents = combinedCost / portfolio.positions[index].shares
  } else {
   portfolio.positions.append(StockPosition(symbol: symbol, shares: shares,
                                             averageCostCents: (grossCents + estimate.fee * 100) / shares))
  }
  portfolio.positions.sort { $0.symbol < $1.symbol }
  portfolio.feesPaid += estimate.fee
  nextCash -= totalCash
  nextMarket.portfolios[player] = portfolio
  guard validate(nextMarket) else { throw GameError.invalidState }
  market = nextMarket
  cash = nextCash
  return StockTradeReceipt(symbol: symbol, shares: shares, priceCents: estimate.priceCents,
                           cashDelta: estimate.cashDelta, fee: estimate.fee, realizedPnLCents: 0)
 }

 public static func sell(_ market: inout StockMarketState, player: Int, symbol: String,
                         shares: Int, cash: inout Int) throws -> StockTradeReceipt {
  let estimate = try estimateSell(market, player: player, symbol: symbol, shares: shares)
  var nextMarket = market
  var nextCash = cash
  var portfolio = nextMarket.portfolios[player]
  guard let index = portfolio.positions.firstIndex(where: { $0.symbol == symbol }) else {
   throw GameError.insufficientShares
  }
  let position = portfolio.positions[index]
  let netCash = estimate.cashDelta
  guard nextCash <= 1_000_000_000 - netCash else { throw GameError.invalidState }
  let realized = netCash * 100 - position.averageCostCents * shares
  nextCash += netCash
  portfolio.realizedPnLCents += realized; portfolio.feesPaid += estimate.fee
  portfolio.positions[index].shares -= shares
  if portfolio.positions[index].shares == 0 { portfolio.positions.remove(at: index) }
  nextMarket.portfolios[player] = portfolio
  guard validate(nextMarket) else { throw GameError.invalidState }
  market = nextMarket
  cash = nextCash
  return StockTradeReceipt(symbol: symbol, shares: shares, priceCents: estimate.priceCents,
                           cashDelta: netCash, fee: estimate.fee, realizedPnLCents: realized)
 }

 private static func random(in range: ClosedRange<Int>, market: inout StockMarketState) -> Int {
  let width = UInt64(range.upperBound - range.lowerBound + 1)
  return range.lowerBound + Int(seededRNG(seed: market.seed, counter: &market.rngCounter) % width)
 }

 private static func appendPoint(_ quote: inout StockQuote, tick: Int, volume: Int) {
  quote.history.append(StockPricePoint(tick: tick, priceCents: quote.currentPriceCents, volume: volume))
  if quote.history.count > maximumHistoryPoints {
   quote.history.removeFirst(quote.history.count - maximumHistoryPoints)
  }
 }
}
