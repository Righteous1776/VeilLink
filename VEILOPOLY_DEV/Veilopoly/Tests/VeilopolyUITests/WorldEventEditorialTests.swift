#if os(iOS) && canImport(SwiftUI)
import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class WorldEventEditorialTests: XCTestCase {
 func testBoughtUsesCommittedTileAndActualPrice() {
  var g = GameFactory.make(seed: 7)
  g.board[1].owner = 0
  let message=VeilopolyEventFeedback.contextualSummary(
   [Effect(.bought, player:0, tile:1, amount:60)], state:g)
  XCTAssertEqual(message,"地契入册 · 玩家 1 以 ¥60 登记「地中海大道」")
 }
 func testAuctionReportsActualBidNotMadeUpResult() {
  let g = GameFactory.make(seed: 7)
  let bid=VeilopolyEventFeedback.contextualSummary(
    [Effect(.bid,player:1,tile:24,amount:275)],state:g)
  XCTAssertEqual(bid,"竞价举牌 · 玩家 2 报价 ¥275")
  let settled=VeilopolyEventFeedback.contextualSummary(
    [Effect(.auctionWon,player:1,tile:24,amount:275)],state:g)
  XCTAssertEqual(settled,"拍卖落槌 · 玩家 2 以 ¥275 获得「伊利诺伊大道」")
 }
 func testFailedRentNeverClaimsSettlement() {
  var g=GameFactory.make(seed: 7)
  g.pendingDebt=PendingDebt(player:0,amount:120,creditor:1)
  let ev=Effect(.rentPaid,player:0,tile:24,to:1,amount:120)
  XCTAssertTrue(VeilopolyEventFeedback.contextualSummary([ev],state:g)?.contains("待清偿") == true)
  g.pendingDebt=nil
  XCTAssertTrue(VeilopolyEventFeedback.contextualSummary([ev],state:g)?.contains("已结算") == true)
 }
 func testStockReceiptsUseActualCommittedCashDelta() {
  let g=GameFactory.make(seed: 7)
  let buying=VeilopolyEventFeedback.contextualSummary(
   [Effect(.stockBought,player:0,amount:-186,stockSymbol:"VTL",stockShares:10)],state:g)
  XCTAssertEqual(buying,"证券成交回执 · 玩家 1 买入 VTL ×10，现金支出 ¥186")
  let selling=VeilopolyEventFeedback.contextualSummary(
   [Effect(.stockSold,player:0,amount:73,stockSymbol:"VTL",stockShares:4)],state:g)
  XCTAssertEqual(selling,"证券成交回执 · 玩家 1 卖出 VTL ×4，现金到账 ¥73")
 }
 func testMissingIDsAndInvalidExtrasFallBackSafely() {
  let g=GameFactory.make(seed: 7)
  XCTAssertEqual(VeilopolyEventFeedback.contextualSummary([
    Effect(.bought,player:0,tile:999,amount:60)
   ],state:g),"地契入册 · 新产权已登记")
  XCTAssertNil(VeilopolyEventFeedback.contextualSummary([],state:g))
 }
}
#endif
