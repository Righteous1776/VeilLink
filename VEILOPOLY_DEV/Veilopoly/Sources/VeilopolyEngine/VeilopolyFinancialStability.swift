import Foundation

/// An honest V5 risk display: bank cash is not the same as spendable capital.
/// No stored derived values, randomness or new settlement protocol.
public enum VeilopolyRiskLevel: String, Codable {
 case stable, guarded, stressed, crisis
}

public struct VeilopolyLiquidityReport: Equatable {
 public let level: VeilopolyRiskLevel
 public let totalSupply: Int
 public let treasuryCash: Int
 public let circulatingCash: Int
 public let queuedClaims: Int
 public let depositObligations: Int
 public let investmentObligations: Int
 public let stockRedemptionExposure: Int
 public let loanPrincipalOutstanding: Int
 public let overdueLoanCount: Int
 public let protectedReserve: Int
 public let safeNewCredit: Int

 /// Conservative contingent bank payout estimate, NOT existing currency.
 public var futureObligations: Int {
  queuedClaims + depositObligations + investmentObligations + stockRedemptionExposure
 }
 public var coverageBasisPoints: Int {
  let needs = futureObligations
  return needs == 0 ? 100_000 : min(100_000, treasuryCash * 10_000 / needs)
 }
}

public enum VeilopolyFinancialStability {
 public static func inspect(_ game: GameState) -> VeilopolyLiquidityReport? {
  guard game.banking?.financeRuleVersion == VeilopolyCityLongEconomy.version,
        let ledger = game.banking, let cash = ledger.reserveCash,
        let supply = VeilopolyCityLongEconomy.supplyCeiling(game),
        (0...supply).contains(cash),
        cash + VeilopolyCityLongEconomy.circulatingCash(game) == supply else { return nil }

  let playersCash = VeilopolyCityLongEconomy.circulatingCash(game)
  let pending = (ledger.queuedClaims ?? []).reduce(0) { $0 + $1.amount }
  var deposits = 0, investments = 0, loanPrincipal = 0, overdue = 0
  for account in ledger.accounts {
   for savings in account.savings {
    deposits += savings.principal + savings.principal * savings.payoutBasisPoints / 10_000
   }
   for position in account.positions {
    let topRate = ledger.terms.payouts[position.feature]?.max() ?? 10_000
    investments += position.principal * topRate / 10_000
   }
   for loan in account.loans {
    loanPrincipal += loan.principal
    if loan.duePeriod <= ledger.completedTurns { overdue += 1 }
   }
  }
  let stockNotional: Int
  if let market = ledger.market {
   stockNotional = market.portfolios.reduce(0) { total, holdings in
    total + holdings.positions.reduce(0) { subtotal, item in
     let quote = market.quotes.first { $0.symbol == item.symbol }
     return subtotal + (quote.map { $0.currentPriceCents * item.shares / 100 } ?? 0)
    }
   }
  } else { stockNotional = 0 }

  let liabilities = pending + deposits + investments + stockNotional
  // A protected reserve is calculated from contingent bank payouts plus a
  // nominal operating buffer. It constrains ONLY NEW optional credit.
  let reserve = min(supply * 4 / 5, max(supply * 12 / 100,
                                          liabilities + supply / 20))
  let available = max(0, cash - reserve)
  let aggregateCreditCap = max(0, supply / 4 - loanPrincipal)
  // Even a cash-rich bank must halt expansion if all known exit claims
  // already exceed its available treasury. Never lend into insolvency.
  let credit = pending == 0 && overdue == 0 &&
               cash >= liabilities && cash >= reserve
    ? min(available, aggregateCreditCap) : 0
  let level: VeilopolyRiskLevel
  if cash < pending || cash < liabilities / 2 || cash < supply / 20 {
   level = .crisis
  } else if cash < liabilities || cash < supply / 8 || overdue > 0 {
   level = .stressed
  } else if cash < reserve || pending > 0 {
   level = .guarded
  } else { level = .stable }

  return .init(level: level, totalSupply: supply, treasuryCash: cash,
               circulatingCash: playersCash, queuedClaims: pending,
               depositObligations: deposits, investmentObligations: investments,
               stockRedemptionExposure: stockNotional,
               loanPrincipalOutstanding: loanPrincipal, overdueLoanCount: overdue,
               protectedReserve: reserve, safeNewCredit: credit)
 }

 public static func mayIssueCredit(_ g: GameState, amount: Int) -> Bool {
  guard let report = inspect(g) else { return true }
  return amount > 0 && amount <= report.safeNewCredit
 }
}
