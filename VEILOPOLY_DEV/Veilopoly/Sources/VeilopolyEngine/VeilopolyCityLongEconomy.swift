import Foundation

/// Explicit new-match-only economic profile. Older games retain original terms.
public enum VeilopolyCityLongEconomy {
 public static let legacyVersion = 3
 public static let finiteVersion = 4
 public static let version = 5
 /// 4 x ¥7,200 player cash + 160,000 city-bank cash = fixed 188,800 units.
 public static let initialTreasuryCash = 160_000
 public static let totalMoneySupply = initialTreasuryCash + 4 * 7_200
 public static let startingCash = 7_200
 public static let passingStartSalary = 1_100
 public static let jailBail = 150
 public static let incomeTax = 600
 public static let luxuryTax = 300
 // V5 expanded denomination; all V4 constants above remain frozen.
 public static let expandedTreasuryCash = 2_000_000
 public static let expandedStartingCash = 25_000
 public static let expandedTotalMoneySupply = 2_100_000
 public static let expandedSalary = 3_200
 public static let expandedBail = 600
 public static let expandedIncomeTax = 2_200
 public static let expandedLuxuryTax = 1_100
 public static func supplyCeiling(forVersion v: Int) -> Int? {
  if v == finiteVersion { return totalMoneySupply }
  if v == version { return expandedTotalMoneySupply }
  return nil
 }
 public static func supplyCeiling(_ g: GameState) -> Int? {
  supplyCeiling(forVersion: g.banking?.financeRuleVersion ?? 0)
 }
 public static func circulatingCash(_ g: GameState) -> Int {
  g.players.reduce(0) { $0 + $1.cash }
 }
 public static func isExpanded(_ g: GameState) -> Bool {
  g.banking?.financeRuleVersion == version
 }
 public static func isActive(_ game: GameState) -> Bool {
  (game.banking?.financeRuleVersion ?? 0) >= legacyVersion
 }
 public static func salary(_ game: GameState) -> Int {
  isExpanded(game) ? expandedSalary : (isActive(game) ? passingStartSalary : 200)
 }
 public static func bail(_ game: GameState) -> Int {
  isExpanded(game) ? expandedBail : (isActive(game) ? jailBail : 50)
 }
 public static func tax(_ game: GameState, tile: Int) -> Int {
  isExpanded(game) ? (tile == 4 ? expandedIncomeTax : expandedLuxuryTax) :
   (isActive(game) ? (tile == 4 ? incomeTax : luxuryTax) : (tile == 4 ? 200 : 100))
 }
 /// CardDefinition amounts are exact in V3; do not secretly triple visible text.
 public static func cardCash(_ game: GameState, amount: Int) -> Int { amount }
 public static func repairCost(_ game: GameState, amount: Int) -> Int { amount }
 /// Early rent protection grows with ordinary completed game turns. Late-game
 /// developments remain potent, but an early hotel cannot end a 7200-cash run.
 public static func rentCeiling(_ game: GameState) -> Int {
  guard isActive(game) else { return Int.max }
  let clock = min(70, max(0, game.banking?.completedTurns ?? 0))
  return isExpanded(game) ? min(24_000, 3_200 + 300 * clock) : min(6500, 900 + 80 * clock)
 }
 public static func chargedRent(_ game: GameState, base: Int, tileKind: TileKind) -> Int {
  guard isActive(game) else { return base }
  let adjusted = tileKind == .railroad || tileKind == .utility ? base * 3 : base
  return min(adjusted, rentCeiling(game))
 }
 /// Signal derived ONLY from committed current GameState, no clock/network/RNG:
 /// purchases, building and bank repayments withdraw player liquidity, loans
 /// release it, and development raises the productive-city component.
 /// Direct transfers also alter concentration. Clamped to ±1.4%/tick.
 public static func marketPressure(_ game: GameState) -> Int {
  guard let v = game.banking?.financeRuleVersion, v >= finiteVersion else { return 0 }
  let cash = circulatingCash(game)
  let buildings = game.board.reduce(0) { $0 + $1.houses + ($1.hotel ? 5 : 0) }
  let richest = game.players.map(\.cash).max() ?? 0
  let poorest = game.players.filter { !$0.bankrupt }.map(\.cash).min() ?? 0
  if v == finiteVersion {
   let signal = (cash - 4 * startingCash) / 90 + min(80, buildings * 7)
    - min(50, max(0, richest - poorest) / 600)
   return max(-140, min(140, signal))
  }
  let credit = game.banking?.accounts.reduce(0) {
   $0 + $1.loans.reduce(0) { $0 + $1.principal }
  } ?? 0
  let signal = (cash - 4 * expandedStartingCash) / 500 +
   min(75, buildings * 5) + min(32, credit / 2_000)
   - min(55, max(0, richest - poorest) / 1_600)
  return max(-140, min(140, signal))
 }
 public static func terms() -> FinanceSandboxPolicy {
  var p = FinanceSandboxPolicy()
  // The percentage is charged ONCE per contract, not again for every period.
  p.loanInterestBasisPoints = [800, 1_100, 1_400, 1_700]
  p.loanCapsByProperties = [1_500, 3_000, 6_000, 9_500]
  // One period before withdrawing demand deposits prevents instant arbitrage.
  p.demandYieldBasisPoints = 150
  p.fixedYieldBasisPoints = 850
  p.fixedLockPeriods = 4
  p.payouts[.managedFund] = [8_000,9_500,10_500,11_500,12_500,13_500]
  p.payouts[.ventureSimulation] = [4_500,7_000,9_000,12_000,16_000,21_000]
  p.payouts[.stockSimulation] = [6_500,8_500,10_000,12_000,14_500,18_000]
  return p
 }
 /// No change to GameState schema. New games carry V3 terms in the existing ledger.
 public static func makeV4(seed: UInt64, humanCount: Int = 1,
                         levels: [AILevel] = [.balanced,.balanced,.balanced,.balanced],
                         cards: [CardDefinition] = VeilopolyCityLongCards.allV4) -> GameState {
  var g = GameFactory.make(seed: seed, humanCount: humanCount,
                           levels: levels, cards: cards)
  for i in g.players.indices { g.players[i].cash = startingCash }
  for i in g.board.indices where g.board[i].purchasable {
   g.board[i].price *= 3
   g.board[i].houseCost *= 3
   g.board[i].rent = g.board[i].rent.map { $0 * 2 }
  }
  g.banking = IntegratedBankLedger(terms: terms(),
                                   market: StockMarketEngine.initial(seed: seed, enhanced: true),
                                   financeRuleVersion: finiteVersion,
                                   reserveCash: initialTreasuryCash)
  return g
 }
 public static func expandedTerms() -> FinanceSandboxPolicy {
  var policy = terms()
  policy.loanInterestBasisPoints = [650, 850, 1_100, 1_450]
  policy.loanCapsByProperties = [6_000, 12_000, 24_000, 40_000]
  return policy
 }
 /// New solo only; no retroactive V4 revaluation.
 public static func make(seed: UInt64, humanCount: Int = 1,
                         levels: [AILevel] = [.balanced,.balanced,.balanced,.balanced],
                         cards: [CardDefinition] = VeilopolyCityLongCards.allV5) -> GameState {
  var g = GameFactory.make(seed: seed, humanCount: humanCount,
                           levels: levels, cards: cards)
  for i in g.players.indices { g.players[i].cash = expandedStartingCash }
  for i in g.board.indices where g.board[i].purchasable {
   g.board[i].price *= 12
   g.board[i].houseCost *= 12
   g.board[i].rent = g.board[i].rent.map { $0 * 8 }
  }
  g.banking = IntegratedBankLedger(terms: expandedTerms(),
   market: StockMarketEngine.initial(seed: seed, enhanced: true, quoteScale: 24),
   financeRuleVersion: version, reserveCash: expandedTreasuryCash)
  return g
 }

}
