import XCTest
import VeilopolyAI

/// Exploratory comparison; prints real completed/capped totals. Never claims
/// that move-count is equal to minutes of human play.
final class CityLongAutoplayTests: XCTestCase {
 func testPairedSeedsProduceReproducibleEvidenceWithoutIllegalMoves() throws {
  var legacyFinished = 0
  var cityFinished = 0
  var cityFirstBankrupt: [Int] = []
  var legacyFirstBankrupt: [Int] = []
  for seed in 100..<112 {
   let old = try LocalGameRunner.compareEconomy(seed: UInt64(seed), maxMoves: 2_500,
                                                cityLong: false)
   let new = try LocalGameRunner.compareEconomy(seed: UInt64(seed), maxMoves: 2_500,
                                                cityLong: true)
   let replay = try LocalGameRunner.compareEconomy(seed: UInt64(seed), maxMoves: 2_500,
                                                   cityLong: true)
   XCTAssertEqual(new, replay)
   XCTAssertLessThanOrEqual(new.moves, 2_500)
   XCTAssertLessThanOrEqual(old.moves, 2_500)
   XCTAssertEqual(new.liquidCash.count, 4)
   XCTAssertEqual(new.propertyCounts.count, 4)
   if old.finished { legacyFinished += 1 }
   if new.finished { cityFinished += 1 }
   if let at = old.firstBankruptcyAtMove { legacyFirstBankrupt.append(at) }
   if let at = new.firstBankruptcyAtMove { cityFirstBankrupt.append(at) }
  }
  print("ECON A/B 12 paired seeds cap=2500",
        "legacyFinished=\(legacyFinished)", "cityFinished=\(cityFinished)",
        "legacyFirstBankruptcyMoves=\(legacyFirstBankrupt)",
        "cityFirstBankruptcyMoves=\(cityFirstBankrupt)")
 }
}
