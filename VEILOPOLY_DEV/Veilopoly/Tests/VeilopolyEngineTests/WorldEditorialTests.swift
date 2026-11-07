import XCTest
@testable import VeilopolyEngine

final class WorldEditorialTests: XCTestCase {
 func testAll40CanonicalTilesHaveUniqueAndReadablePages() throws {
  let board=GameFactory.board()
  XCTAssertEqual(board.count,40)
  XCTAssertEqual(VeilopolyWorldEditorial.pages.count,40)
  XCTAssertEqual(Set(VeilopolyWorldEditorial.pages.map(\.id)).count,40)
  XCTAssertEqual(Set(VeilopolyWorldEditorial.pages.map(\.title)).count,40)
  for (index,tile) in board.enumerated() {
   let page=try XCTUnwrap(VeilopolyWorldEditorial.page(for:tile))
   XCTAssertEqual(page.index,index)
   XCTAssertEqual(page.canonicalName,tile.name)
   XCTAssertEqual(page.kind,tile.kind)
   XCTAssertEqual(page.id,String(format:"VL-LORE-TILE-%02d",index))
   XCTAssertGreaterThan(page.teaser.count,9)
   XCTAssertGreaterThan(page.story.count,20)
  }
 }
 func testRenamedOrCustomTilesNeverShowIncorrectLore() {
  var t=GameFactory.board()[24]
  XCTAssertNotNil(VeilopolyWorldEditorial.page(for:t))
  t.name="自定义大道"
  XCTAssertNil(VeilopolyWorldEditorial.page(for:t))
  t=GameFactory.board()[24]
  t.kind = .chance
  XCTAssertNil(VeilopolyWorldEditorial.page(for:t))
  t.i = 999
  XCTAssertNil(VeilopolyWorldEditorial.page(for:t))
 }
 func testAllFiveFictionalIssuersHaveMatchedProfiles() throws {
  let quotes=StockMarketEngine.initial(seed:42).quotes
  XCTAssertEqual(quotes.count,5)
  XCTAssertEqual(VeilopolyMarketEditorial.issuers.count,5)
  for q in quotes {
   let profile=try XCTUnwrap(VeilopolyMarketEditorial.issuer(for:q))
   XCTAssertEqual(profile.symbol,q.symbol)
   XCTAssertEqual(profile.canonicalName,q.name)
   XCTAssertGreaterThan(profile.summary.count,18)
  }
  var altered=try XCTUnwrap(quotes.first)
  altered.name = "新公司"
  XCTAssertNil(VeilopolyMarketEditorial.issuer(for:altered))
 }
 func testMarketNarrativeRespondsToRealTickStateOnly() throws {
  var m=StockMarketEngine.initial(seed:7)
  for regime in -2...2 {
   m.regime=regime
   XCTAssertFalse(VeilopolyMarketEditorial.regimeNotice(m).isEmpty)
  }
  var q=try XCTUnwrap(m.quotes.first)
  XCTAssertTrue(VeilopolyMarketEditorial.quoteNotice(q).contains("暂未记录"))
  q.sessionVolume=25
  XCTAssertTrue(VeilopolyMarketEditorial.quoteNotice(q).contains("25 股"))
  q.haltedTicks=1
  XCTAssertTrue(VeilopolyMarketEditorial.quoteNotice(q).contains("暂停交易"))
 }
 func testEditorialLookupsDoNotChangeCanonicalStateOrMarket() throws {
  let state=GameFactory.make(seed:20261107)
  let before=StateDigest.hash(state)
  for tile in state.board { _ = VeilopolyWorldEditorial.page(for:tile) }
  let m=StockMarketEngine.initial(seed:state.seed)
  let old=m
  for q in m.quotes {
   _ = VeilopolyMarketEditorial.issuer(for:q)
   _ = VeilopolyMarketEditorial.quoteNotice(q)
  }
  _ = VeilopolyMarketEditorial.regimeNotice(m)
  XCTAssertEqual(old,m)
  XCTAssertEqual(StateDigest.hash(state),before)
 }
}
