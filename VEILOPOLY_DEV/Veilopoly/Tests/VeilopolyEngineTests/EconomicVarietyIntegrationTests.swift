import XCTest
@testable import VeilopolyEngine

final class EconomicVarietyIntegrationTests: XCTestCase {
 func testNewSeedsDiversifyChanceFateAndMarketTogether() {
  let states=(101...116).map { GameFactory.make(seed:UInt64($0)) }
  XCTAssertEqual(Set(states.map { $0.chanceDeck.order.map(String.init).joined(separator:",") }).count,16)
  XCTAssertEqual(Set(states.map { $0.chestDeck.order.map(String.init).joined(separator:",") }).count,16)
  let markets=states.map { StockMarketEngine.initial(seed:$0.seed) }
  XCTAssertEqual(Set(markets.map(\.seed)).count,16)
  XCTAssertTrue(markets.allSatisfy { $0.algorithmVersion == 2 })
 }
 func testVersionedStockMarketSurvivesFullGameStateJSONRoundTrip() throws {
  var game=GameFactory.make(seed:123)
  game.banking=IntegratedBankLedger(market:StockMarketEngine.initial(seed:game.seed))
  let before=StateDigest.hash(game)
  let data=try JSONEncoder().encode(game)
  let restored=try JSONDecoder().decode(GameState.self,from:data)
  XCTAssertEqual(before,StateDigest.hash(restored))
  XCTAssertEqual(restored.banking?.market?.algorithmVersion,2)
 }
 func testLegacyStockMarketStateOmissionDoesNotChangeSavedGameHash() throws {
  var game=GameFactory.make(seed:124)
  var m=StockMarketEngine.initial(seed:game.seed)
  m.algorithmVersion=1
  game.banking=IntegratedBankLedger(market:m)
  let encoder=JSONEncoder()
  encoder.outputFormatting=[.sortedKeys]
  let data=try encoder.encode(game)
  let json=try XCTUnwrap(String(data:data,encoding:.utf8))
  XCTAssertFalse(json.contains("algorithmVersion"))
  let restored=try JSONDecoder().decode(GameState.self,from:data)
  XCTAssertEqual(game,restored)
  XCTAssertEqual(StateDigest.hash(game),StateDigest.hash(restored))
 }
}
