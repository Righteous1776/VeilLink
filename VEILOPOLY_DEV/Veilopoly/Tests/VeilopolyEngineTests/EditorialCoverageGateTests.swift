import XCTest
@testable import VeilopolyEngine

final class EditorialCoverageGateTests: XCTestCase {
 func testAllActiveNarrativeSurfacesHaveStableGroundedContent() throws {
  let game = GameFactory.make(seed:707, humanCount:1)
  XCTAssertEqual(game.cards.count,32)
  XCTAssertEqual(game.cards.compactMap(VeilopolyCardEditorial.presentation).count,32)
  XCTAssertEqual(game.board.compactMap(VeilopolyWorldEditorial.page).count,40)
  let market=StockMarketEngine.initial(seed:game.seed)
  XCTAssertEqual(market.quotes.count,5)
  XCTAssertEqual(market.quotes.compactMap(VeilopolyMarketEditorial.issuer).count,5)
  XCTAssertEqual(VeilopolyGuideLibrary.topics.count,23)
  XCTAssertEqual(Set(VeilopolyGuideLibrary.topics.map(\.id)).count,23)
  XCTAssertEqual(VeilopolyGuideChapter.allCases.count,4)
  XCTAssertNotNil(VeilopolyCivicText.deed(game,tileIndex:1))
  XCTAssertNotNil(VeilopolyCivicText.banking(game,player:0))
  XCTAssertNil(VeilopolyCivicText.deed(game,tileIndex:0))
  XCTAssertNil(VeilopolyCivicText.auction(game))
  XCTAssertNil(VeilopolyCivicText.trade(game))
  XCTAssertNil(VeilopolyCivicText.debt(game))
  XCTAssertNil(VeilopolyCivicText.settlement(game))
 }
 func testStatusDependentPaperworkNeverClaimsAnUncommittedTransaction() throws {
  let original=GameFactory.make(seed:708)
  var game=original
  game.auction=AuctionState(tile:1, active:[0,1])
  let auction=try XCTUnwrap(VeilopolyCivicText.auction(game))
  XCTAssertTrue(auction.subtitle.contains("尚未"))
  game.auction=nil
  game.trade=TradeState(from:0,to:1,offer:TradeTransfer(cash:20),
                       request:TradeTransfer(cash:30))
  let contract=try XCTUnwrap(VeilopolyCivicText.trade(game))
  XCTAssertTrue(contract.note.contains("并非成交"))
  game.trade=nil
  game.pendingDebt=PendingDebt(player:0,amount:250,creditor:1)
  let debt=try XCTUnwrap(VeilopolyCivicText.debt(game))
  XCTAssertTrue(debt.note.contains("不代表已宣告破产"))
  game.pendingDebt=nil
  game.winner=0
  game.turn.phase = .finished
  XCTAssertNotNil(VeilopolyCivicText.settlement(game))
  XCTAssertEqual(original,GameFactory.make(seed:708))
 }
 func testNarrationNeverChangesDeterministicGameOrMarketState() {
  let original=GameFactory.make(seed:709)
  let stateHash=StateDigest.hash(original)
  for tile in original.board { _=VeilopolyWorldEditorial.page(for:tile) }
  for card in original.cards { _=VeilopolyCardEditorial.presentation(for:card) }
  _=VeilopolyCivicText.banking(original,player:0)
  _=VeilopolyGuideLibrary.status(original)
  let market=StockMarketEngine.initial(seed:original.seed)
  let reference=market
  for quote in market.quotes {
   _=VeilopolyMarketEditorial.issuer(for:quote)
   _=VeilopolyMarketEditorial.quoteNotice(quote)
  }
  _=VeilopolyMarketEditorial.regimeNotice(market)
  XCTAssertEqual(StateDigest.hash(original),stateHash)
  XCTAssertEqual(market,reference)
 }
}
