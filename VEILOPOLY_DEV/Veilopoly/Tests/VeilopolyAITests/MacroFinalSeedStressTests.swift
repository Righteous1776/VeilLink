import Foundation
import XCTest
import VeilopolyAI

/// Expensive explicit macro balance corpus; cap is a bound, NOT a natural win.
final class MacroFinalSeedStressTests: XCTestCase {
 func testOneHundredDeterministicV5SeedsReportBankLiquidityAndEarlyBankruptcy() throws {
  var naturalCompletions = 0
  var cappedRuns = 0
  var firstBankruptcyMoves: [Int] = []
  var turns: [Int] = []
  var highestBankClaim = 0
  var totalStressedMoves = 0
  var totalCrisisMoves = 0
  var outstandingClaims = 0
  let cap = 1_200
  for i in 0..<100 {
   let result = try LocalGameRunner.compareEconomy(
    seed: UInt64(41_000 + i), maxMoves: cap, cityLong: true)
   XCTAssertLessThanOrEqual(result.moves, cap)
   XCTAssertEqual(result.liquidCash.count, 4)
   XCTAssertEqual(result.propertyCounts.count, 4)
   XCTAssertGreaterThanOrEqual(result.unresolvedBankClaims, 0)
   XCTAssertGreaterThanOrEqual(result.bankReserve ?? -1, 0)
   XCTAssertEqual(result.liquidCash.reduce(0, +) + (result.bankReserve ?? 0),
                  2_100_000, "V5 monetary base must not drift in any seeded game")
   if result.finished {
    naturalCompletions += 1
    XCTAssertNotNil(result.winner)
   } else {
    cappedRuns += 1
    XCTAssertNil(result.winner)
   }
   if let first = result.firstBankruptcyAtMove {
    firstBankruptcyMoves.append(first)
   }
   turns.append(result.completedTurns)
   highestBankClaim = max(highestBankClaim, result.peakBankClaims)
   totalStressedMoves += result.stressedMoves
   totalCrisisMoves += result.crisisMoves
   outstandingClaims += result.unresolvedBankClaims
   if i < 3 {
    let again = try LocalGameRunner.compareEconomy(
     seed: UInt64(41_000 + i), maxMoves: cap, cityLong: true)
    XCTAssertEqual(result, again, "V5 gameplay including bank claims must replay")
   }
  }
  XCTAssertEqual(naturalCompletions + cappedRuns, 100)
  let sortedFirst = firstBankruptcyMoves.sorted()
  let medianFirst: Int? = sortedFirst.isEmpty ? nil :
   sortedFirst[sortedFirst.count / 2]
  let sortedTurns = turns.sorted()
  let medianTurns = sortedTurns[sortedTurns.count / 2]
  print("VLP-MACRO FINAL: 100 seeds capped at \(cap) engine actions",
        "naturalFinished=\(naturalCompletions)",
        "cappedUnfinished=\(cappedRuns)",
        "medianCompletedTurns=\(medianTurns)",
        "firstBankruptcySeen=\(firstBankruptcyMoves.count)",
        "medianFirstBankruptcyEngineAction=\(medianFirst.map(String.init) ?? "none")",
        "peakUnredeemedBankClaims=\(highestBankClaim)",
        "remainingClaimsAcrossFinalStates=\(outstandingClaims)",
        "stressedMoves=\(totalStressedMoves)",
        "crisisMoves=\(totalCrisisMoves)")
 }
}
