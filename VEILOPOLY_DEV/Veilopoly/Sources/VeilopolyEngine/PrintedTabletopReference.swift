import Foundation

/// Alternative table-game mechanics derived from the Owner's *printed* reference.
/// These pure helpers do not alter the classic Veilopoly GameState or wire format.
public enum PrintedTabletopRules {
 /// For deterministic replay the move already contains the rolled movement distance.
 /// A pass across Start pays, but a move landing exactly at Start does not.
 public static func startReward(from: Int, steps: Int,
                                policy: PrintedTabletopProfile = .init()) -> Int {
  guard (0..<40).contains(from), (1...40).contains(steps), from + steps >= 40 else { return 0 }
  return (from + steps) % 40 == 0 ? policy.salaryOnExactStart : policy.salaryWhenPassingStart
 }

 /// A host may inject an authoritative elapsed-minute event as part of a logged
 /// command. No local clock is sampled inside the rules package.
 /// A tied cash lead is left unresolved for Owner rules approval.
 public static func timedCashLeaders(_ cash: [Int], elapsedMinutes: Int,
                                     selectedLimit: Int,
                                     policy: PrintedTabletopProfile = .init()) -> [Int]? {
  guard policy.timedVictoryChoicesMinutes.contains(selectedLimit),
        elapsedMinutes >= selectedLimit, cash.count == 4,
        cash.allSatisfy({ $0 >= 0 }) else { return nil }
  guard let maximum = cash.max() else { return nil }
  return cash.indices.filter { cash[$0] == maximum }
 }
}

public struct PrintedStarState: Codable, Equatable {
 public var bank: Int = 8
 public var owned: [Int] = [0, 0, 0, 0]
 public var completedCycles: Int = 0
 public init() {}
}
public struct PrintedStarEvent: Codable, Equatable {
 public var awardedTo: Int
 public var awardCount: Int
 public var cycleEnded: Bool
 public var leadingPlayers: [Int]
}
public enum PrintedStarError: String, Error, Equatable {
 case invalidPlayer, invalidCount, insufficientSupply, invalidState
}
public enum PrintedStarRules {
 /// For the printed variant only, once all eight star tokens are distributed,
 /// the max holders (including ties) become hotel-*eligible*, not automatically
 /// hotel owners; hotel construction still needs a separate owner ruling.
 public static func award(_ initial: PrintedStarState, to player: Int, count: Int = 1)
  -> Result<(PrintedStarState, PrintedStarEvent), PrintedStarError> {
  guard initial.owned.count == 4, initial.bank >= 0,
        initial.bank + initial.owned.reduce(0,+) == 8,
        initial.owned.allSatisfy({ $0 >= 0 }), initial.completedCycles >= 0
  else { return .failure(.invalidState) }
  guard (0..<4).contains(player) else { return .failure(.invalidPlayer) }
  guard count > 0, count <= 8 else { return .failure(.invalidCount) }
  guard count <= initial.bank else { return .failure(.insufficientSupply) }
  var state = initial
  state.bank -= count
  state.owned[player] += count
  let ended = state.bank == 0
  var leaders: [Int] = []
  if ended {
   if let maxCount = state.owned.max() {
    leaders = state.owned.indices.filter { state.owned[$0] == maxCount }
   }
   state.bank = 8
   state.owned = [0,0,0,0]
   state.completedCycles += 1
  }
  return .success((state, PrintedStarEvent(awardedTo: player, awardCount: count,
                                           cycleEnded: ended, leadingPlayers: leaders)))
 }
}
