import Foundation

/// Explicit new-match-only economic profile. Older games retain original terms.
public enum VeilopolyCityLongEconomy {
 public static let legacyVersion = 3
 public static let version = 4
 /// 4 x ¥7,200 player cash + 160,000 city-bank cash = fixed 188,800 units.
 public static let initialTreasuryCash = 160_000
 public static let totalMoneySupply = initialTreasuryCash + 4 * 7_200
 public static let startingCash = 7_200
 public static let passingStartSalary = 1_100
 public static let jailBail = 150
 public static let incomeTax = 600
 public static let luxuryTax = 300
 public static func isActive(_ game: GameState) -> Bool {
  (game.banking?.financeRuleVersion ?? 0) >= legacyVersion
 }
 public static func salary(_ game: GameState) -> Int { isActive(game) ? passingStartSalary : 200 }
 public static func bail(_ game: GameState) -> Int { isActive(game) ? jailBail : 50 }
 public static func tax(_ game: GameState, tile: Int) -> Int {
  isActive(game) ? (tile == 4 ? incomeTax : luxuryTax) : (tile == 4 ? 200 : 100)
 }
 /// CardDefinition amounts are exact in V3; do not secretly triple visible text.
 public static func cardCash(_ game: GameState, amount: Int) -> Int { amount }
 public static func repairCost(_ game: GameState, amount: Int) -> Int { amount }
 /// Early rent protection grows with ordinary completed game turns. Late-game
 /// developments remain potent, but an early hotel cannot end a 7200-cash run.
 public static func rentCeiling(_ game: GameState) -> Int {
  guard isActive(game) else { return Int.max }
  let clock = min(70, max(0, game.banking?.completedTurns ?? 0))
  return min(6500, 900 + 80 * clock)
 }
 public static func chargedRent(_ game: GameState, base: Int, tileKind: TileKind) -> Int {
  guard isActive(game) else { return base }
  let adjusted = tileKind == .railroad || tileKind == .utility ? base * 3 : base
  return min(adjusted, rentCeiling(game))
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
 public static func make(seed: UInt64, humanCount: Int = 1,
                         levels: [AILevel] = [.balanced,.balanced,.balanced,.balanced],
                         cards: [CardDefinition] = VeilopolyCityLongCards.all) -> GameState {
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
                                   financeRuleVersion: version,
                                   reserveCash: initialTreasuryCash)
  return g
 }
}
