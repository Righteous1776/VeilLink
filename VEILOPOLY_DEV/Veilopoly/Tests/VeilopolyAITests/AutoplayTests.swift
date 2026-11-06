import XCTest
import VeilopolyAI
import VeilopolyEngine

final class AutoplayTests: XCTestCase {
 func test500SeededAIGamesNoIllegalMoves() throws {
  var completed = 0
  for seed in 0..<500 {
   let stats = try LocalGameRunner.autoplay(seed: UInt64(seed), maxMoves: 500)
   if stats.completed { completed += 1 }
   XCTAssertGreaterThan(stats.totalMoves, 0)
   XCTAssertNotEqual(stats.finalHash, "ENCODING_ERROR")
  }
  // A bounded 500-move smoke simulation per seed; not a full-length or time-budget certification.
  print("AI smoke 500 seeds: completed within cap \(completed)/500")
 }
}
