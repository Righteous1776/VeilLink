import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class VeilopolyNewGameSeedTests: XCTestCase {
 func testEachResetUsesFreshEntropyInsteadOfIncrementingOldSeed() {
  let seed = VeilopolyNewGameSeed.fresh()
  let next = VeilopolyNewGameSeed.fresh(excluding: seed)
  XCTAssertNotEqual(seed, next)
 }
 func testManyFreshGamesProduceDifferentEngineAndMarketPaths() {
  var seeds = Set<UInt64>()
  var marketSeeds = Set<UInt64>()
  for _ in 0..<32 {
   let seed = VeilopolyNewGameSeed.fresh()
   seeds.insert(seed)
   let game = GameFactory.make(seed: seed)
   XCTAssertEqual(game.seed, seed)
   marketSeeds.insert(StockMarketEngine.initial(seed: seed).seed)
  }
  XCTAssertEqual(seeds.count, 32)
  XCTAssertEqual(marketSeeds.count, 32)
 }
 func testExplicitSeedIsStillPerfectlyReproducible() {
  let a = GameFactory.make(seed: 1_729_123)
  let b = GameFactory.make(seed: 1_729_123)
  XCTAssertEqual(a, b)
  XCTAssertEqual(StateDigest.hash(a), StateDigest.hash(b))
  XCTAssertEqual(StockMarketEngine.initial(seed:a.seed),StockMarketEngine.initial(seed:b.seed))
 }
}
