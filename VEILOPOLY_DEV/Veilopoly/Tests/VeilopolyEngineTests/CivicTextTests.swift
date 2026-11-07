import XCTest
@testable import VeilopolyEngine

final class CivicTextTests: XCTestCase {
 func testDeedReflectsActualOwnershipAndNeverInventsAProperty() throws {
  var state = GameFactory.make(seed: 765, humanCount: 1)
  XCTAssertNil(VeilopolyCivicText.deed(state, tileIndex: 40))
  XCTAssertNil(VeilopolyCivicText.deed(state, tileIndex: 0))
  var document = try XCTUnwrap(VeilopolyCivicText.deed(state, tileIndex: 1))
  XCTAssertTrue(document.fields.contains(.init("当前所有者","尚未登记")))
  state.board[1].owner = 0
  state.board[1].houses = 2
  state.board[1].mortgaged = true
  document = try XCTUnwrap(VeilopolyCivicText.deed(state, tileIndex: 1))
  XCTAssertTrue(document.fields.contains(.init("当前所有者","玩家 1")))
  XCTAssertTrue(document.fields.contains(.init("建筑状况","房屋 ×2")))
  XCTAssertTrue(document.fields.contains(.init("抵押状态","已抵押")))
  XCTAssertEqual(document.fields.first(where: { $0.label == "城市札记" })?.value,
    VeilopolyWorldEditorial.page(for:state.board[1])?.story)
 }
 func testAuctionUsesLiveBidderAndNeverReportsPrematureSale() throws {
  var state = GameFactory.make(seed: 14)
  XCTAssertNil(VeilopolyCivicText.auction(state))
  state.auction = AuctionState(tile: 3, active:[0,1,2])
  state.auction?.currentBid = 146
  state.auction?.bidder = 1
  let document = try XCTUnwrap(VeilopolyCivicText.auction(state))
  XCTAssertTrue(document.fields.contains(.init("当前最高价","¥146")))
  XCTAssertTrue(document.fields.contains(.init("最高出价人","玩家 2")))
  XCTAssertTrue(document.note.contains("才发生产权转移"))
 }
 func testTradeDetailsIncludeBothDirectionsAndJailCards() throws {
  var state = GameFactory.make(seed: 222)
  state.trade = TradeState(from: 0,to: 1,
   offer: TradeTransfer(cash: 70,tiles:[1],chanceCards:1),
   request: TradeTransfer(cash: 35,tiles:[3],chestCards:2))
  let doc = try XCTUnwrap(VeilopolyCivicText.trade(state))
  XCTAssertTrue(doc.fields.contains(.init("甲方","玩家 1")))
  XCTAssertTrue(doc.fields.contains(.init("乙方","玩家 2")))
  XCTAssertTrue(doc.fields.first(where:{$0.label=="甲方提出"})?.value.contains("¥70") == true)
  XCTAssertTrue(doc.fields.first(where:{$0.label=="向乙方请求"})?.value.contains("¥35") == true)
  XCTAssertTrue(doc.fields.first(where:{$0.label=="向乙方请求"})?.value.contains("命运出狱卡2张") == true)
  XCTAssertTrue(doc.note.contains("并非成交"))
 }
 func testBankingDoesNotConflateSavingsCashAndLoans() throws {
  var state = GameFactory.make(seed: 987)
  let first = try XCTUnwrap(VeilopolyCivicText.banking(state, player: 0))
  XCTAssertTrue(first.fields.contains(.init("手持现金","¥1500")))
  var ledger = IntegratedBankLedger()
  ledger.completedTurns = 7
  ledger.accounts[0].savings = [SandboxSaving(id: 1,feature:.demandDeposit,principal:200,
                                            unlockPeriod:0,payoutBasisPoints:0)]
  ledger.accounts[0].loans = [SandboxLoan(id: 2,principal:500,
                                       interestBasisPoints:2000,duePeriod:9,
                                       periods:2,totalDue:600)]
  state.banking=ledger
  let doc = try XCTUnwrap(VeilopolyCivicText.banking(state,player:0))
  XCTAssertTrue(doc.fields.contains(.init("存款本金","¥200")))
  XCTAssertTrue(doc.fields.contains(.init("贷款待偿总额","¥600")))
  XCTAssertTrue(doc.fields.contains(.init("账本期次","7")))
  XCTAssertFalse(doc.note.contains("¥1700"))
 }
 func testDebtAndSettlementAreNotFalselyDeclared() throws {
  var state = GameFactory.make(seed: 2026)
  XCTAssertNil(VeilopolyCivicText.debt(state))
  XCTAssertNil(VeilopolyCivicText.settlement(state))
  state.pendingDebt = PendingDebt(player: 1,amount:365,creditor:0)
  let debt = try XCTUnwrap(VeilopolyCivicText.debt(state))
  XCTAssertTrue(debt.fields.contains(.init("待支付","¥365")))
  XCTAssertTrue(debt.note.contains("不代表已宣告破产"))
  state.pendingDebt=nil
  state.winner=0
  state.turn.phase = .finished
  state.players[1].bankrupt=true
  let finished = try XCTUnwrap(VeilopolyCivicText.settlement(state))
  XCTAssertTrue(finished.fields.contains(.init("本局胜者","玩家 1")))
  XCTAssertTrue(finished.fields.contains(.init("已破产玩家","1 位")))
 }
 func testDocumentsLeaveGameHashAndRulesUntouched() throws {
  let state = GameFactory.make(seed: 333, humanCount: 1)
  let before=StateDigest.hash(state)
  _ = VeilopolyCivicText.deed(state,tileIndex:1)
  _ = VeilopolyCivicText.banking(state,player:0)
  _ = VeilopolyCivicText.auction(state)
  _ = VeilopolyCivicText.trade(state)
  _ = VeilopolyCivicText.debt(state)
  _ = VeilopolyCivicText.settlement(state)
  XCTAssertEqual(before,StateDigest.hash(state))
  XCTAssertEqual(VeilopolyCivicText.minimumIOS,15)
 }
}
