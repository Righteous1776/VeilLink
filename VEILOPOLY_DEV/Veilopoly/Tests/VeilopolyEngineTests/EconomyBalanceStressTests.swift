import XCTest
@testable import VeilopolyEngine

/// Bounded repeatable market checks, not a promise of returns.
final class EconomyBalanceStressTests: XCTestCase {
 func testVariableMarketDivergesButRetainsLimitsAcrossManySeeds() throws {
  var endings=Set<String>()
  var upward=0, downward=0
  var circuitBreakers=0
  for seed in 1...32 {
   var market=StockMarketEngine.initial(seed:UInt64(seed))
   XCTAssertEqual(market.algorithmVersion,2)
   for _ in 0..<160 {
    let previous=market.quotes.map(\.currentPriceCents)
    circuitBreakers += try StockMarketEngine.advance(&market).count
    XCTAssertTrue(StockMarketEngine.validate(market))
    for index in market.quotes.indices {
     let quote=market.quotes[index]
     if quote.currentPriceCents>previous[index] { upward += 1 }
     if quote.currentPriceCents<previous[index] { downward += 1 }
     XCTAssertGreaterThanOrEqual(quote.currentPriceCents,
       max(50,quote.sessionOpenCents*90/100))
     XCTAssertLessThanOrEqual(quote.currentPriceCents,
       min(1_000_000,quote.sessionOpenCents*110/100))
     XCTAssertTrue((0...2).contains(quote.haltedTicks))
    }
   }
   endings.insert(market.quotes.map { String($0.currentPriceCents) }.joined(separator:","))
  }
  // Catch broken RNG, flat tape, one-way market or runaway halts. These are
  // intentionally broad safety bounds, not hardcoded predicted percentages.
  XCTAssertGreaterThanOrEqual(endings.count,28)
  XCTAssertGreaterThan(upward,1000)
  XCTAssertGreaterThan(downward,1000)
  XCTAssertLessThan(circuitBreakers,1000)
 }
 func testV2LoanSettlementIsReplayableAndSerializedWithTheGame() throws {
  func play() throws -> GameState {
   var game=Fixture.game(.manage)
   var ledger=IntegratedBankLedger(completedTurns:0)
   ledger.accounts[0].loans=[
    SandboxLoan(id:37,principal:200,interestBasisPoints:2000,
                duePeriod:1,periods:1,totalDue:240)]
   game.banking=ledger
   let move=Move(.endTurn,player:game.turn.player,seq:game.nextSeq)
   let (next,effects)=try VeilopolyEngine.apply(game,VeilopolyEngine.context(game),move).get()
   XCTAssertTrue(effects.contains {
    $0.kind == .bankRepaid && $0.text == "automaticMaturity" && $0.amount == -240
   })
   XCTAssertTrue(next.banking?.accounts[0].loans.isEmpty == true)
   return next
  }
  let a=try play(),b=try play()
  XCTAssertEqual(StateDigest.hash(a),StateDigest.hash(b))
  let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
  let restored=try JSONDecoder().decode(GameState.self,from:encoder.encode(a))
  XCTAssertEqual(restored,a)
  XCTAssertEqual(StateDigest.hash(restored),StateDigest.hash(a))
  XCTAssertEqual(restored.banking?.financeRuleVersion,2)
 }
 func testLegacyBankingDoesNotRewriteHistoricalGameState() throws {
  var original=GameFactory.make(seed:20261107)
  original.banking=IntegratedBankLedger(completedTurns:12,financeRuleVersion:1)
  let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
  let bytes=try encoder.encode(original)
  let json=try XCTUnwrap(String(data:bytes,encoding:.utf8))
  XCTAssertFalse(json.contains("financeRuleVersion"))
  let restored=try JSONDecoder().decode(GameState.self,from:bytes)
  XCTAssertEqual(original,restored)
  XCTAssertEqual(try encoder.encode(restored),bytes)
  XCTAssertEqual(StateDigest.hash(original),StateDigest.hash(restored))
 }
}
