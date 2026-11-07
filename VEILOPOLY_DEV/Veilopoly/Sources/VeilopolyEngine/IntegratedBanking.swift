import Foundation

/// One banking ledger in the authoritative GameState. Currency lives ONLY in Player.cash;
/// there is no parallel cash account, independent seq, clock, or random stream.
/// Historic FinanceSandbox is retained as a comparison oracle, not a second game engine.
public struct IntegratedBankAccount: Codable, Equatable {
 public var borrowCount: Int = 0
 public var savings: [SandboxSaving] = []
 public var loans: [SandboxLoan] = []
 public var positions: [SandboxPosition] = []
 public init() {}
}

public struct IntegratedBankLedger: Codable, Equatable {
 public var completedTurns: Int
 public var terms: FinanceSandboxPolicy
 public var accounts: [IntegratedBankAccount]
 /// Optional keeps snapshots from before the live simulator backward compatible.
 public var market: StockMarketState?
 /// Missing in historical JSON means V1 voluntary repayment. Only new ledgers
 /// use V2 automatic maturity settlement; never rewrite a saved game's terms.
 public var financeRuleVersion: Int
 /// Liquid treasury backing the finite-currency V4 city. Nil in V1/V2/V3 saves.
 public var reserveCash: Int?
 public init(completedTurns: Int = 0, terms: FinanceSandboxPolicy = FinanceSandboxPolicy(),
             market: StockMarketState? = nil, financeRuleVersion: Int = 2,
             reserveCash: Int? = nil) {
  self.completedTurns = completedTurns
  self.terms = terms
  self.accounts = Array(repeating: IntegratedBankAccount(), count: 4)
  self.market = market
  self.financeRuleVersion = financeRuleVersion
  self.reserveCash = reserveCash
 }

 // FinanceSandboxPolicy has enum-keyed dictionaries. Swift encodes these as
 // unkeyed key/value arrays, whose iteration order is unstable between runs.
 // Explicit string-keyed DTOs make the entire GameState hash reproducible.
 private enum CodingKeys: String, CodingKey { case completedTurns, terms, accounts, market, financeRuleVersion, reserveCash }
 private struct CanonicalTerms: Codable {
  var loanInterestBasisPoints: [Int]
  var loanCapsByProperties: [Int]
  var demandYieldBasisPoints: Int?
  var fixedYieldBasisPoints: Int?
  var fixedLockPeriods: Int?
  var payouts: [String: [Int]]
  var draftDurations: [String: Int]
  init(_ p: FinanceSandboxPolicy) {
   loanInterestBasisPoints = p.loanInterestBasisPoints
   loanCapsByProperties = p.loanCapsByProperties
   demandYieldBasisPoints = p.demandYieldBasisPoints
   fixedYieldBasisPoints = p.fixedYieldBasisPoints
   fixedLockPeriods = p.fixedLockPeriods
   payouts = Dictionary(uniqueKeysWithValues: p.payouts.map { ($0.key.rawValue, $0.value) })
   draftDurations = Dictionary(uniqueKeysWithValues: p.draftDurations.map { ($0.key.rawValue, $0.value) })
  }
  func policy() throws -> FinanceSandboxPolicy {
   var p = FinanceSandboxPolicy()
   p.loanInterestBasisPoints = loanInterestBasisPoints
   p.loanCapsByProperties = loanCapsByProperties
   p.demandYieldBasisPoints = demandYieldBasisPoints
   p.fixedYieldBasisPoints = fixedYieldBasisPoints
   p.fixedLockPeriods = fixedLockPeriods
   p.payouts = [:]; p.draftDurations = [:]
   for (name, schedule) in payouts {
    guard let key = FinancialFeature(rawValue: name) else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown finance feature")) }
    p.payouts[key] = schedule
   }
   for (name, duration) in draftDurations {
    guard let key = FinancialFeature(rawValue: name) else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown finance feature")) }
    p.draftDurations[key] = duration
   }
   guard p.isWellFormed() else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid finance terms")) }
   return p
  }
 }
 public func encode(to encoder: Encoder) throws {
  var c = encoder.container(keyedBy: CodingKeys.self)
  try c.encode(completedTurns, forKey: .completedTurns)
  try c.encode(CanonicalTerms(terms), forKey: .terms)
  try c.encode(accounts, forKey: .accounts)
  try c.encodeIfPresent(market, forKey: .market)
  // Nil is omitted, preserving exact old checkpoint hash/JSON.
  try c.encodeIfPresent(reserveCash, forKey: .reserveCash)
  // Omitting the v1 key preserves its historical sealed checkpoint checksum.
  if financeRuleVersion != 1 {
   try c.encode(financeRuleVersion, forKey: .financeRuleVersion)
  }
 }
 public init(from decoder: Decoder) throws {
  let c = try decoder.container(keyedBy: CodingKeys.self)
  completedTurns = try c.decode(Int.self, forKey: .completedTurns)
  terms = try c.decode(CanonicalTerms.self, forKey: .terms).policy()
  accounts = try c.decode([IntegratedBankAccount].self, forKey: .accounts)
  market = try c.decodeIfPresent(StockMarketState.self, forKey: .market)
  reserveCash = try c.decodeIfPresent(Int.self, forKey: .reserveCash)
  financeRuleVersion = try c.decodeIfPresent(Int.self, forKey: .financeRuleVersion) ?? 1
 }
}

public enum IntegratedBanking {
 public static func ledger(_ g: GameState) -> IntegratedBankLedger {
  var result = g.banking ?? IntegratedBankLedger(completedTurns: g.moveLog.filter { $0.type == .endTurn }.count)
  if result.market == nil {
   result.market = StockMarketEngine.initial(seed: g.seed,
    enhanced: result.financeRuleVersion >= VeilopolyCityLongEconomy.legacyVersion)
  }
  return result
 }

 /// Deterministic and auditable policy injection. To ratify a yield/market table,
 /// store it in this state before the very first banking action; it then enters stateHash.
 public static func configured(_ g: GameState, terms: FinanceSandboxPolicy) -> GameState? {
  guard terms.isWellFormed(), g.banking == nil else { return nil }
  var updated = g
  updated.banking = IntegratedBankLedger(completedTurns: g.moveLog.filter { $0.type == .endTurn }.count,
                                         terms: terms, market: StockMarketEngine.initial(seed: g.seed))
  return updated
 }

 public static func validate(_ ledger: IntegratedBankLedger) -> Bool {
  (1...4).contains(ledger.financeRuleVersion) &&
  (ledger.financeRuleVersion == VeilopolyCityLongEconomy.version
   ? (ledger.reserveCash.map { (0...VeilopolyCityLongEconomy.totalMoneySupply).contains($0) } ?? false)
   : ledger.reserveCash == nil) &&
  (0...1_000_000).contains(ledger.completedTurns) && ledger.accounts.count == 4 &&
  ledger.terms.isWellFormed() && (ledger.market.map(StockMarketEngine.validate) ?? true) &&
  ledger.accounts.allSatisfy { acc in
   (0...4).contains(acc.borrowCount) && acc.savings.count <= 1000 &&
   acc.loans.count <= 4 && acc.positions.count <= 1000 &&
   Set(acc.savings.map(\.id)).count == acc.savings.count &&
   Set(acc.loans.map(\.id)).count == acc.loans.count &&
   Set(acc.positions.map(\.id)).count == acc.positions.count &&
   acc.savings.allSatisfy {
    $0.id >= 0 && [.demandDeposit, .fixedDeposit].contains($0.feature) &&
    (1...1_000_000).contains($0.principal) && (0...1_000_000).contains($0.unlockPeriod) &&
    (0...10_000).contains($0.payoutBasisPoints)
   } &&
   acc.loans.allSatisfy {
    $0.id >= 0 && (1...1_000_000).contains($0.principal) &&
    (0...10_000).contains($0.interestBasisPoints) &&
    (1...12).contains($0.periods) && (0...1_000_000).contains($0.duePeriod) &&
    ($0.principal...1_000_000_000).contains($0.totalDue)
   } &&
   acc.positions.allSatisfy {
    $0.id >= 0 && [.managedFund, .ventureSimulation, .stockSimulation].contains($0.feature) &&
    (1...1_000_000).contains($0.principal) && (0...1_000_000).contains($0.duePeriod)
   }
  }
 }

 /// Shared UI / Engine eligibility. Do not keep a second independent
 /// interpretation of loan-due trading restrictions in SwiftUI.
 public static func hasOverdueLoan(_ ledger: IntegratedBankLedger, player p: Int) -> Bool {
  guard ledger.financeRuleVersion >= 2,
        ledger.accounts.indices.contains(p) else { return false }
  return ledger.accounts[p].loans.contains { $0.duePeriod <= ledger.completedTurns }
 }

 public static func apply(_ g: inout GameState, move m: Move, effects: inout [Effect]) throws {
  let p = m.player
  guard (0..<4).contains(p), (0...1_000_000_000).contains(g.players[p].cash) else { throw GameError.invalidState }
  var ledger = ledger(g)
  guard validate(ledger) else { throw GameError.invalidState }
  let period = ledger.completedTurns
  let policy = ledger.terms
  let id = g.nextSeq
  // A matured unpaid contract cannot coexist with new high-risk purchases.
  // Repayment, liquidation sales and withdrawals remain permitted.
  if hasOverdueLoan(ledger, player: p) &&
     [.bankDeposit, .bankBorrow, .bankInvest, .stockBuy].contains(m.type) {
   throw GameError.financeOverdue
  }
  switch m.type {
  case .bankDeposit:
   guard let feature = m.financeProduct, [.demandDeposit, .fixedDeposit].contains(feature),
         let amount = m.amount, (1...1_000_000).contains(amount) else { throw GameError.invalidPayload }
   let rate: Int
   let duration: Int
   if feature == .demandDeposit {
    // The Owner's demand-yield bracket is crossed out. Preserve principal, not invented yield.
    rate = policy.demandYieldBasisPoints ?? 0
    duration = ledger.financeRuleVersion >= VeilopolyCityLongEconomy.legacyVersion ? 1 : 0
   } else {
    guard let fixedRate = policy.fixedYieldBasisPoints, let fixedDuration = policy.fixedLockPeriods else {
     throw GameError.financeTermsPending
    }
    rate = fixedRate; duration = fixedDuration
   }
   guard g.players[p].cash >= amount else { throw GameError.noCash }
   guard period <= 1_000_000 - duration else { throw GameError.invalidState }
   g.players[p].cash -= amount
   ledger.accounts[p].savings.append(.init(id: id, feature: feature, principal: amount,
                                           unlockPeriod: period + duration, payoutBasisPoints: rate))
   effects.append(Effect(.bankDeposited, player: p, amount: -amount, text: feature.rawValue))
  case .bankWithdraw:
   guard let reference = m.financeID,
         let ix = ledger.accounts[p].savings.firstIndex(where: { $0.id == reference }) else {
    throw GameError.invalidPayload
   }
   let item = ledger.accounts[p].savings[ix]
   guard period >= item.unlockPeriod else { throw GameError.financePositionLocked }
   let payout = item.principal + item.principal * item.payoutBasisPoints / 10_000
   guard g.players[p].cash <= 1_000_000_000 - payout else { throw GameError.invalidState }
   g.players[p].cash += payout
   ledger.accounts[p].savings.remove(at: ix)
   effects.append(Effect(.bankWithdrawn, player: p, amount: payout, text: item.feature.rawValue))
  case .bankBorrow:
   guard let principal = m.amount, let periods = m.financePeriods else { throw GameError.invalidPayload }
   let ordinal = ledger.accounts[p].borrowCount
   guard ordinal < 4 else { throw GameError.financeTermsPending }
   let lots = g.board.filter { $0.owner == p && !$0.mortgaged && $0.purchasable }.count
   let total: Int
   if ledger.financeRuleVersion >= VeilopolyCityLongEconomy.legacyVersion {
    guard (1...12).contains(periods), principal > 0,
          principal <= policy.loanCapsByProperties[min(lots, 3)] else {
     throw GameError.invalidPayload
    }
    let interest = (principal * policy.loanInterestBasisPoints[ordinal] + 9_999) / 10_000
    total = principal + interest
   } else {
    let quote = FinanceSandbox.loanQuote(principal: principal, periods: periods, ownedLots: lots,
                                         ordinal: ordinal, policy: policy)
    switch quote {
    case .success(let value): total = value
    case .failure(.termsAwaitOwnerRuling): throw GameError.financeTermsPending
    case .failure(.collateralCapExceeded): throw GameError.invalidPayload
    default: throw GameError.invalidPayload
    }
   }
   guard period <= 1_000_000 - periods && g.players[p].cash <= 1_000_000_000 - principal else {
    throw GameError.invalidState
   }
   ledger.accounts[p].borrowCount += 1
   ledger.accounts[p].loans.append(.init(id: id, principal: principal,
                                         interestBasisPoints: policy.loanInterestBasisPoints[ordinal],
                                         duePeriod: period + periods, periods: periods, totalDue: total))
   g.players[p].cash += principal
   effects.append(Effect(.bankBorrowed, player: p, amount: principal, text: "due:\(total)"))
  case .bankRepay:
   guard let reference = m.financeID,
         let ix = ledger.accounts[p].loans.firstIndex(where: { $0.id == reference }) else {
    throw GameError.invalidPayload
   }
   let loan = ledger.accounts[p].loans[ix]
   // Early repayment is allowed, with originally agreed simple interest (no refinancing).
   guard g.players[p].cash >= loan.totalDue else { throw GameError.noCash }
   g.players[p].cash -= loan.totalDue
   ledger.accounts[p].loans.remove(at: ix)
   effects.append(Effect(.bankRepaid, player: p, amount: -loan.totalDue))
  case .bankInvest:
   guard let feature = m.financeProduct,
         [.managedFund, .ventureSimulation, .stockSimulation].contains(feature),
         let amount = m.amount, (1...1_000_000).contains(amount) else { throw GameError.invalidPayload }
   guard let table = policy.payouts[feature], table.count == 6,
         let duration = policy.draftDurations[feature], duration > 0 else { throw GameError.financeTermsPending }
   guard g.players[p].cash >= amount else { throw GameError.noCash }
   guard period <= 1_000_000 - duration else { throw GameError.invalidState }
   g.players[p].cash -= amount
   ledger.accounts[p].positions.append(.init(id: id, feature: feature, principal: amount,
                                             duePeriod: period + duration))
   effects.append(Effect(.bankInvestmentOpened, player: p, amount: -amount, text: feature.rawValue))
  case .bankSettle:
   guard let reference = m.financeID,
         let ix = ledger.accounts[p].positions.firstIndex(where: { $0.id == reference }) else {
    throw GameError.invalidPayload
   }
   let position = ledger.accounts[p].positions[ix]
   guard period >= position.duePeriod else { throw GameError.financePositionLocked }
   guard let schedule = policy.payouts[position.feature], schedule.count == 6 else {
    throw GameError.financeTermsPending
   }
   let rolled: Int
   if ledger.financeRuleVersion >= 2 {
    // Independent, contract-scoped offline draw. Repeated settlement attempts,
    // delaying the claim or consuming dice elsewhere cannot reroll the outcome.
    // Domain separation preserves the main dice and market RNG streams.
    var counter: UInt64 = 0
    let outcomeSeed = g.seed ^ 0x5645_494C_494E_5653 ^
      (UInt64(position.id) &* 0x9E3779B97F4A7C15)
    rolled = Int(seededRNG(seed: outcomeSeed, counter: &counter) % 6) + 1
   } else {
    // Historical V1 replay remains bit-for-bit, including RNG consumption.
    rolled = Int(seededRNG(seed: g.seed, counter: &g.rngCounter) % 6) + 1
   }
   let payout = position.principal * schedule[rolled - 1] / 10_000
   guard g.players[p].cash <= 1_000_000_000 - payout else { throw GameError.invalidState }
   g.players[p].cash += payout
   ledger.accounts[p].positions.remove(at: ix)
   effects.append(Effect(.bankInvestmentSettled, player: p, amount: payout, dice: [rolled], text: position.feature.rawValue))
  case .stockTick:
   guard var market = ledger.market else { throw GameError.invalidState }
   let halted = try StockMarketEngine.advance(&market)
   ledger.market = market
   effects.append(Effect(.stockTicked, amount: market.tick,
                         text: "regime:\(market.regime)"))
   for symbol in halted {
    effects.append(Effect(.stockHalted, text: symbol, stockSymbol: symbol))
   }
  case .stockBuy:
   guard var market = ledger.market, let symbol = m.stockSymbol,
         let shares = m.stockShares else { throw GameError.invalidPayload }
   let receipt = try StockMarketEngine.buy(&market, player: p, symbol: symbol,
                                           shares: shares, cash: &g.players[p].cash)
   ledger.market = market
   effects.append(Effect(.stockBought, player: p, amount: receipt.cashDelta,
                         text: "fee:\(receipt.fee)", stockSymbol: receipt.symbol,
                         stockShares: receipt.shares, stockPriceCents: receipt.priceCents))
  case .stockSell:
   guard var market = ledger.market, let symbol = m.stockSymbol,
         let shares = m.stockShares else { throw GameError.invalidPayload }
   let receipt = try StockMarketEngine.sell(&market, player: p, symbol: symbol,
                                            shares: shares, cash: &g.players[p].cash)
   ledger.market = market
   effects.append(Effect(.stockSold, player: p, amount: receipt.cashDelta,
                         text: "fee:\(receipt.fee);pnlCents:\(receipt.realizedPnLCents)",
                         stockSymbol: receipt.symbol, stockShares: receipt.shares,
                         stockPriceCents: receipt.priceCents))
  default: throw GameError.invalidPayload
  }
  g.banking = ledger
 }

 /// No Date() and no independent timer: one completed ordinary player turn = one period.
 /// Extra rolls do not advance financial maturity. The effect is for Kimi's UI only.
 public static func advanceTurn(_ g: inout GameState, effects: inout [Effect]) {
  guard var ledger = g.banking, ledger.completedTurns < 1_000_000 else { return }
  ledger.completedTurns += 1
  let now = ledger.completedTurns
  if ledger.financeRuleVersion >= 2 {
   // Prioritize the oldest matured loans, with stable contract-ID tie break.
   // Never overdraw, add a new penalty, or force-sell collateral here.
   for p in ledger.accounts.indices where !g.players[p].bankrupt {
    let matured = ledger.accounts[p].loans
     .filter { $0.duePeriod <= now }
     .sorted { a,b in
      a.duePeriod == b.duePeriod ? a.id < b.id : a.duePeriod < b.duePeriod
     }
    for loan in matured {
     guard g.players[p].cash >= loan.totalDue else { break }
     g.players[p].cash -= loan.totalDue
     ledger.accounts[p].loans.removeAll { $0.id == loan.id }
     effects.append(Effect(.bankRepaid, player: p, amount: -loan.totalDue,
                           text: "automaticMaturity"))
    }
   }
  }
  if var market = ledger.market, let halted = try? StockMarketEngine.advance(&market) {
   ledger.market = market
   effects.append(Effect(.stockTicked, amount: market.tick, text: "turnClose"))
   for symbol in halted { effects.append(Effect(.stockHalted, text: symbol, stockSymbol: symbol)) }
  }
  for p in ledger.accounts.indices where !g.players[p].bankrupt {
   let due = ledger.accounts[p].savings.contains { $0.unlockPeriod == now } ||
             ledger.accounts[p].loans.contains { $0.duePeriod == now } ||
             ledger.accounts[p].positions.contains { $0.duePeriod == now }
   if due { effects.append(Effect(.bankMatured, player: p, amount: now)) }
  }
  g.banking = ledger
 }

 /// Automatic liquidation is deterministic: withdraw only unlocked savings,
 /// in original deposit order, before touching property. Never break fixed-term locks.
 public static func releaseAvailableSavingsForDebt(_ g: inout GameState,
                                                   debtor p: Int, amount: Int,
                                                   effects: inout [Effect]) {
  guard amount > 0, g.players.indices.contains(p), g.players[p].cash < amount,
        var ledger = g.banking, ledger.accounts.indices.contains(p) else { return }
  var i = 0
  while i < ledger.accounts[p].savings.count && g.players[p].cash < amount {
   let item = ledger.accounts[p].savings[i]
   if ledger.completedTurns < item.unlockPeriod { i += 1; continue }
   let payout = item.principal + item.principal * item.payoutBasisPoints / 10_000
   guard payout <= 1_000_000_000 - g.players[p].cash else { break }
   g.players[p].cash += payout
   ledger.accounts[p].savings.remove(at: i)
   effects.append(Effect(.bankWithdrawn, player: p, amount: payout,
                         text: "automaticDebtCover"))
  }
  // A liquid portfolio may cover debt after unlocked cash savings. Trading
  // halts are honored, and sales use the same fee/cost basis as manual orders.
  if g.players[p].cash < amount, var market = ledger.market,
     market.portfolios.indices.contains(p) {
   let symbols = market.portfolios[p].positions.map(\.symbol).sorted()
   for symbol in symbols where g.players[p].cash < amount {
    while g.players[p].cash < amount,
          let position = market.portfolios[p].position(symbol: symbol), position.shares > 0,
          let quote = StockMarketEngine.quote(market, symbol: symbol), !quote.isHalted {
     let shortfall = amount - g.players[p].cash
     let needed = max(1, min(position.shares, min(10_000,
       (shortfall * 100 + quote.currentPriceCents - 1) / quote.currentPriceCents + 1)))
     guard let receipt = try? StockMarketEngine.sell(&market, player: p, symbol: symbol,
                                                     shares: needed, cash: &g.players[p].cash) else { break }
     effects.append(Effect(.stockSold, player: p, amount: receipt.cashDelta,
                           text: "automaticDebtCover", stockSymbol: symbol,
                           stockShares: receipt.shares, stockPriceCents: receipt.priceCents))
    }
   }
   ledger.market = market
  }
  g.banking = ledger
 }

 /// Bankruptcy safety: accessible savings and the last quoted stock value enter
 /// the estate before normal creditor distribution. Outstanding loans are archived
 /// pending the Owner's priority decision.
 public static func closeBankruptAccount(_ g: inout GameState, player p: Int,
                                         effects: inout [Effect]) throws {
  guard var ledger = g.banking, ledger.accounts.indices.contains(p),
        g.players.indices.contains(p) else { return }
  let savings = ledger.accounts[p].savings.reduce(0) { $0 + $1.principal }
  let proceeds = ledger.market.flatMap { market in
   market.portfolios.indices.contains(p)
    ? StockMarketEngine.portfolioMarketValueCents(market, player:p) / 100
    : nil
  } ?? 0
  // PRE-FLIGHT the entire estate before clearing any savings or shares.
  // Previously overflowing items were discarded without crediting their value.
  let headroom = 1_000_000_000 - g.players[p].cash
  guard savings >= 0, proceeds >= 0, savings <= headroom,
        proceeds <= headroom - savings else { throw GameError.invalidState }
  if savings > 0 {
   g.players[p].cash += savings
   effects.append(Effect(.bankWithdrawn, player:p, amount:savings,
                         text:"estatePrincipal"))
  }
  if var market = ledger.market, market.portfolios.indices.contains(p) {
   if proceeds > 0 {
    g.players[p].cash += proceeds
    effects.append(Effect(.stockSold, player:p, amount:proceeds,
                          text:"estateLiquidation"))
   }
   market.portfolios[p] = StockPortfolio()
   ledger.market = market
  }
  ledger.accounts[p] = IntegratedBankAccount()
  g.banking = ledger
 }
}

/// A reproducible, explainable rule-adjudication advisor rather than an untrained
/// neural network. Both AI and a human-facing hint can use this pure function.
public enum FinancialRuleJudge {
 public static func recommendation(_ g: GameState, player p: Int) -> Move? {
  guard g.turn.phase == .manage, g.turn.player == p, (0..<4).contains(p),
        !g.players[p].bankrupt, let bank = g.banking,
        bank.accounts.indices.contains(p) else { return nil }
  let account = bank.accounts[p]
  if let item = account.loans.first(where: { $0.duePeriod <= bank.completedTurns && $0.totalDue <= g.players[p].cash }) {
   return Move(.bankRepay, player: p, seq: g.nextSeq, financeID: item.id)
  }
  if let item = account.savings.first(where: { $0.unlockPeriod <= bank.completedTurns }) {
   return Move(.bankWithdraw, player: p, seq: g.nextSeq, financeID: item.id)
  }
  if let item = account.positions.first(where: { $0.duePeriod <= bank.completedTurns && bank.terms.payouts[$0.feature]?.count == 6 }) {
   return Move(.bankSettle, player: p, seq: g.nextSeq, financeID: item.id)
  }
  return nil
 }
}
