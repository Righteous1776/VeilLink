import XCTest
import VeilopolyAI

final class LongSimTests: XCTestCase {
 func testExploratoryFullGames() throws {
  var complete = 0
  var moves = 0
  for seed in 0..<20 {
   let result = try LocalGameRunner.autoplay(seed: UInt64(seed), maxMoves: 6000)
   if result.completed { complete += 1 }
   moves += result.totalMoves
  }
  print("EXPLORATORY 20 SEEDS: complete=\(complete), totalMoves=\(moves)")
 }
}
