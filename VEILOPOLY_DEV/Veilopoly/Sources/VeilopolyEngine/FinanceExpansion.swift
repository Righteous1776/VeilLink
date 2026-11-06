import Foundation

/// Nonredeemable game-credit sandbox for the Owner's photographed financial rules.
/// This reducer is deliberately independent of GameState until conflicting rule
/// variants, saving migrations and end-turn settlement are approved.
public enum FinancialFeature: String, Codable, CaseIterable {
 case demandDeposit, fixedDeposit, managedFund, ventureSimulation, stockSimulation, diceChallenge
}

public struct PrintedTabletopProfile: Codable, Equatable {
 public let salaryWhenPassingStart = 1000
 public let salaryOnExactStart = 0
 public let specialLandPurchasePrice = 2000
 public let housesBeforeHotel = 2
 public let communalStarSupply = 8
 public let timedVictoryChoicesMinutes = [60, 90]
 public init() {}
}

public struct FinanceSandboxPolicy: Codable, Equatable {
 /// Rates for borrowing first, second, third and fourth time, from handwritten sheet.
 public var loanInterestBasisPoints: [Int] = [2000, 3000, 4000, 4500]
 /// Caps for 0, 1, 2 or exactly 3 owned unmortgaged lots; 4+ requires Owner ruling.
 public var loanCapsByProperties: [Int] = [500, 1000, 4000, 7000]
 /// Yield and deposit maturity remain absent pending owner clarification.
 public var demandYieldBasisPoints: Int? = nil
 public var fixedYieldBasisPoints: Int? = nil
 public var fixedLockPeriods: Int? = nil
 /// Simulation-only payout tables are intentionally absent until ratified.
 public var payouts: [FinancialFeature: [Int]] = [:]
 public var draftDurations: [FinancialFeature: Int] = [
  .managedFund: 5, .ventureSimulation: 4, .stockSimulation: 3
 ]
 public init() {}
 public func isWellFormed() -> Bool {
  loanInterestBasisPoints.count == 4 && loanCapsByProperties.count == 4 &&
  loanInterestBasisPoints.allSatisfy { (0...10_000).contains($0) } &&
  loanCapsByProperties.allSatisfy { (0...1_000_000).contains($0) } &&
  [demandYieldBasisPoints, fixedYieldBasisPoints].allSatisfy { $0 == nil || (0...10_000).contains($0!) } &&
  (fixedLockPeriods == nil || (1...100).contains(fixedLockPeriods!)) &&
  draftDurations.allSatisfy { key, periods in
   [.managedFund, .ventureSimulation, .stockSimulation].contains(key) && (1...100).contains(periods)
  } &&
  payouts.allSatisfy { key, table in
   [.managedFund, .ventureSimulation, .stockSimulation].contains(key) &&
   table.count == 6 && table.allSatisfy { (0...30_000).contains($0) }
  }
 }
}

public struct SandboxSaving: Codable, Equatable {
 public var id: Int
 public var feature: FinancialFeature
 public var principal: Int
 public var unlockPeriod: Int
 public var payoutBasisPoints: Int
}
public struct SandboxLoan: Codable, Equatable {
 public var id: Int
 public var principal: Int
 public var interestBasisPoints: Int
 public var duePeriod: Int
 public var periods: Int
 public var totalDue: Int
}
public struct SandboxPosition: Codable, Equatable {
 public var id: Int
 public var feature: FinancialFeature
 public var principal: Int
 public var duePeriod: Int
}
public struct SandboxAccount: Codable, Equatable {
 public var cash: Int
 public var ownedLots: Int
 public var borrowCount: Int = 0
 public var savings: [SandboxSaving] = []
 public var loans: [SandboxLoan] = []
 public var positions: [SandboxPosition] = []
 public var diceChallengeWins: Int = 0
 public init(cash: Int = 1500, ownedLots: Int = 0) {
  self.cash = cash; self.ownedLots = ownedLots
 }
}
public struct FinancialSandboxState: Codable, Equatable {
 public var seed: UInt64
 public var rngCounter: UInt64 = 0
 public var period: Int = 0
 public var nextSeq: Int = 0
 public var accounts: [SandboxAccount]
 public var moveLog: [FinancialSandboxMove] = []
 public init(seed: UInt64, accounts: [SandboxAccount] = Array(repeating: SandboxAccount(), count: 4)) {
  self.seed = seed; self.accounts = accounts
 }
}
public enum FinancialSandboxAction: String, Codable {
 case deposit, withdraw, borrow, repayLoan, openInvestment, settleInvestment, advancePeriod, rollNoStakeChallenge
}
public struct FinancialSandboxMove: Codable, Equatable {
 public var action: FinancialSandboxAction
 public var player: Int
 public var seq: Int
 public var amount: Int?
 public var periods: Int?
 public var feature: FinancialFeature?
 public var targetID: Int?
 public init(_ action: FinancialSandboxAction, player: Int, seq: Int,
             amount: Int? = nil, periods: Int? = nil,
             feature: FinancialFeature? = nil, targetID: Int? = nil) {
  self.action = action; self.player = player; self.seq = seq
  self.amount = amount; self.periods = periods; self.feature = feature; self.targetID = targetID
 }
}
public struct FinancialSandboxEffect: Codable, Equatable {
 public var label: String
 public var player: Int
 public var amount: Int
 public var rolled: Int?
 public init(_ label: String, player: Int, amount: Int = 0, rolled: Int? = nil) {
  self.label = label; self.player = player; self.amount = amount; self.rolled = rolled
 }
}
public enum FinancialSandboxError: String, Error, Equatable {
 case invalidState, invalidSequence, invalidPlayer, invalidAmount, insufficientCash
 case termsAwaitOwnerRuling, collateralCapExceeded, loanLimitExceeded
 case positionNotFound, positionLocked, insufficientFundsForRepayment
}

public enum FinanceSandbox {
 /// Read-only projection of the real Monopoly state for subsequent rule review.
 /// It intentionally does NOT write back into GameState, MoveLog or stateHash.
 public static func shadowFromGame(_ g: GameState) -> FinancialSandboxState {
  let accounts = g.players.map { player in
   SandboxAccount(cash: player.cash,
                  ownedLots: g.board.filter { $0.owner == player.id && !$0.mortgaged }.count)
  }
  return FinancialSandboxState(seed: g.seed, accounts: accounts)
 }
 public typealias Transition = Result<(FinancialSandboxState, [FinancialSandboxEffect]), FinancialSandboxError>

 public static func loanQuote(principal: Int, periods: Int, ownedLots: Int, ordinal: Int,
                              policy: FinanceSandboxPolicy = .init()) -> Result<Int, FinancialSandboxError> {
  guard policy.isWellFormed(), (1...12).contains(periods), (0...3).contains(ordinal), ownedLots >= 0,
        principal > 0 else { return .failure(.invalidAmount) }
  guard ownedLots <= 3 else { return .failure(.termsAwaitOwnerRuling) }
  guard principal <= policy.loanCapsByProperties[ownedLots] else { return .failure(.collateralCapExceeded) }
  let rate = policy.loanInterestBasisPoints[ordinal]
  let perPeriod = principal * rate / 10_000
  return .success(principal + perPeriod * periods)
 }

 public static func apply(_ state: FinancialSandboxState, _ move: FinancialSandboxMove,
                          policy: FinanceSandboxPolicy = .init()) -> Transition {
  guard policy.isWellFormed(), state.accounts.count == 4, (0...1_000_000).contains(state.period),
        (0...1_000_000).contains(state.nextSeq),
        state.accounts.allSatisfy({ (0...1_000_000_000).contains($0.cash) && $0.ownedLots >= 0 })
  else { return .failure(.invalidState) }
  guard move.seq == state.nextSeq else { return .failure(.invalidSequence) }
  guard state.accounts.indices.contains(move.player) else { return .failure(.invalidPlayer) }
  var g = state
  let p = move.player
  var effects: [FinancialSandboxEffect] = []
  switch move.action {
  case .advancePeriod:
   guard g.period < 1_000_000 else { return .failure(.invalidState) }
   g.period += 1
   effects.append(.init("periodAdvanced", player: p, amount: g.period))
  case .deposit:
   guard let feature = move.feature, [.demandDeposit, .fixedDeposit].contains(feature),
         let amount = move.amount, (1...1_000_000).contains(amount) else { return .failure(.invalidAmount) }
   let rate: Int?
   let lock: Int
   if feature == .demandDeposit { rate = policy.demandYieldBasisPoints; lock = 0 }
   else { rate = policy.fixedYieldBasisPoints; lock = policy.fixedLockPeriods ?? -1 }
   guard let approvedRate = rate, lock >= 0 else { return .failure(.termsAwaitOwnerRuling) }
   guard g.accounts[p].cash >= amount else { return .failure(.insufficientCash) }
   g.accounts[p].cash -= amount
   g.accounts[p].savings.append(.init(id: g.nextSeq, feature: feature, principal: amount,
                                      unlockPeriod: g.period + lock, payoutBasisPoints: approvedRate))
   effects.append(.init("deposited", player: p, amount: -amount))
  case .withdraw:
   guard let id = move.targetID, let index = g.accounts[p].savings.firstIndex(where: { $0.id == id })
   else { return .failure(.positionNotFound) }
   let saving = g.accounts[p].savings[index]
   guard g.period >= saving.unlockPeriod else { return .failure(.positionLocked) }
   let amount = saving.principal + saving.principal * saving.payoutBasisPoints / 10_000
   guard g.accounts[p].cash <= 1_000_000_000 - amount else { return .failure(.invalidState) }
   g.accounts[p].cash += amount
   g.accounts[p].savings.remove(at: index)
   effects.append(.init("withdrew", player: p, amount: amount))
  case .borrow:
   guard let amount = move.amount, let periods = move.periods else { return .failure(.invalidAmount) }
   let ordinal = g.accounts[p].borrowCount
   guard ordinal < 4 else { return .failure(.loanLimitExceeded) }
   let quote = loanQuote(principal: amount, periods: periods, ownedLots: g.accounts[p].ownedLots,
                         ordinal: ordinal, policy: policy)
   guard case .success(let total) = quote else {
    if case .failure(let error) = quote { return .failure(error) }
    return .failure(.invalidAmount)
   }
   guard g.accounts[p].cash <= 1_000_000_000 - amount else { return .failure(.invalidState) }
   g.accounts[p].cash += amount
   g.accounts[p].borrowCount += 1
   g.accounts[p].loans.append(.init(id: g.nextSeq, principal: amount,
                                    interestBasisPoints: policy.loanInterestBasisPoints[ordinal],
                                    duePeriod: g.period + periods, periods: periods, totalDue: total))
   effects.append(.init("borrowed", player: p, amount: amount))
  case .repayLoan:
   guard let id = move.targetID, let index = g.accounts[p].loans.firstIndex(where: { $0.id == id })
   else { return .failure(.positionNotFound) }
   let loan = g.accounts[p].loans[index]
   guard g.period >= loan.duePeriod else { return .failure(.positionLocked) }
   guard g.accounts[p].cash >= loan.totalDue else { return .failure(.insufficientFundsForRepayment) }
   g.accounts[p].cash -= loan.totalDue
   g.accounts[p].loans.remove(at: index)
   effects.append(.init("loanRepaid", player: p, amount: -loan.totalDue))
  case .openInvestment:
   guard let feature = move.feature, [.managedFund, .ventureSimulation, .stockSimulation].contains(feature),
         let amount = move.amount, (1...1_000_000).contains(amount) else { return .failure(.invalidAmount) }
   guard policy.payouts[feature]?.count == 6, let lock = policy.draftDurations[feature], lock > 0 else {
    return .failure(.termsAwaitOwnerRuling)
   }
   guard g.accounts[p].cash >= amount else { return .failure(.insufficientCash) }
   g.accounts[p].cash -= amount
   g.accounts[p].positions.append(.init(id: g.nextSeq, feature: feature,
                                        principal: amount, duePeriod: g.period + lock))
   effects.append(.init("simulationOpened", player: p, amount: -amount))
  case .settleInvestment:
   guard let id = move.targetID, let index = g.accounts[p].positions.firstIndex(where: { $0.id == id })
   else { return .failure(.positionNotFound) }
   let position = g.accounts[p].positions[index]
   guard g.period >= position.duePeriod else { return .failure(.positionLocked) }
   guard let table = policy.payouts[position.feature], table.count == 6 else { return .failure(.termsAwaitOwnerRuling) }
   let roll = Int(seededRNG(seed: g.seed, counter: &g.rngCounter) % 6) + 1
   let payout = position.principal * table[roll - 1] / 10_000
   guard g.accounts[p].cash <= 1_000_000_000 - payout else { return .failure(.invalidState) }
   g.accounts[p].cash += payout
   g.accounts[p].positions.remove(at: index)
   effects.append(.init("simulationSettled", player: p, amount: payout, rolled: roll))
  case .rollNoStakeChallenge:
   // No stake, no in-game currency payout, and no real-money functionality.
   let roll = Int(seededRNG(seed: g.seed, counter: &g.rngCounter) % 6) + 1
   if roll == 6 { g.accounts[p].diceChallengeWins += 1 }
   effects.append(.init("noStakeDice", player: p, rolled: roll))
  }
  g.nextSeq += 1
  g.moveLog.append(move)
  return .success((g, effects))
 }
}
