import VeilopolyEngine

/// Explainable, deterministic AI liquidity guard for the single Veilopoly rule set.
/// Cash, financial dates and legal actions remain authoritative in GameState.
/// This adapter never updates balances, rolls dice, or invents investment yields.
public enum FinancePolicyAdvisor {
 public struct Report: Equatable {
  public let reserve: Int
  public let dueWithinHorizon: Int
  public let dueNow: Int
  public let availableCash: Int
  public let nextLegalBankMove: Move?
  public let shortfall: Int

  public init(reserve: Int, dueWithinHorizon: Int, dueNow: Int,
              availableCash: Int, nextLegalBankMove: Move?, shortfall: Int) {
   self.reserve = reserve
   self.dueWithinHorizon = dueWithinHorizon
   self.dueNow = dueNow
   self.availableCash = availableCash
   self.nextLegalBankMove = nextLegalBankMove
   self.shortfall = shortfall
  }
 }

 /// A fixed one-turn lookahead for known loan liabilities. Both limits and
 /// tie-breaking are integer-only; the result is identical across client/host.
 public static func analyze(_ g: GameState, player: Int,
                            baseReserve: Int, lookahead: Int = 1) -> Report {
  let floor = max(0, baseReserve)
  guard g.players.indices.contains(player) else {
   return Report(reserve: floor, dueWithinHorizon: 0, dueNow: 0,
                 availableCash: 0, nextLegalBankMove: nil, shortfall: 0)
  }
  let cash = g.players[player].cash
  guard let bank = g.banking, bank.accounts.indices.contains(player) else {
   return Report(reserve: floor, dueWithinHorizon: 0, dueNow: 0,
                 availableCash: cash, nextLegalBankMove: nil, shortfall: 0)
  }
  let now = bank.completedTurns
  let horizon = now + max(0, min(lookahead, 8))
  // Saturate to the same bounded cash range used by the game state.
  func sumDue(until cutoff: Int) -> Int {
   bank.accounts[player].loans
    .filter { $0.duePeriod <= cutoff }
    .reduce(0) { partial, loan in
     let amount = max(0, min(1_000_000_000, loan.totalDue))
     return partial >= 1_000_000_000 - amount ? 1_000_000_000 : partial + amount
    }
  }
  let due = sumDue(until: horizon)
  let nowDue = sumDue(until: now)
  let reserve = max(floor, due)
  return Report(reserve: reserve, dueWithinHorizon: due,
                dueNow: nowDue, availableCash: cash,
                nextLegalBankMove: FinancialRuleJudge.recommendation(g, player: player),
                shortfall: max(0, due - cash))
 }
}
