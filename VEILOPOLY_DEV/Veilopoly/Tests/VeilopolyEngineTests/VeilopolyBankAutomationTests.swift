import XCTest
@testable import VeilopolyEngine
final class VeilopolyBankAutomationTests: XCTestCase {
 func testNoFictitiousAccountWhenBankHasNotOpened() throws {
  let game=GameFactory.make(seed:20)
  let view=try XCTUnwrap(VeilopolyBankAutomation.digest(game,player:0))
  XCTAssertTrue(view.notices.isEmpty)
  XCTAssertTrue(view.memorandum.contains("尚未启用"))
  XCTAssertNil(VeilopolyBankAutomation.digest(game,player:5))
 }
 func testRealMaturitiesAndLoansUseStoredLedger() throws {
  var game=GameFactory.make(seed:21)
  var bank=IntegratedBankLedger(completedTurns:8)
  bank.accounts[0].savings=[
   .init(id:1,feature:.demandDeposit,principal:100,unlockPeriod:8,payoutBasisPoints:0)]
  bank.accounts[0].loans=[
   .init(id:2,principal:150,interestBasisPoints:2000,duePeriod:9,periods:2,totalDue:180)]
  game.banking=bank
  let view=try XCTUnwrap(VeilopolyBankAutomation.digest(game,player:0))
  XCTAssertEqual(view.period,8)
  XCTAssertEqual(view.notices.count,2)
  XCTAssertTrue(view.notices[0].urgent)
  XCTAssertTrue(view.notices[0].text.contains("¥100"))
  XCTAssertTrue(view.notices[1].text.contains("1 期"))
 }
 func testMissingInvestmentPayoutRulesAreNotInvented() throws {
  var game=GameFactory.make(seed:22)
  var bank=IntegratedBankLedger(completedTurns:5)
  bank.accounts[0].positions=[
   .init(id:4,feature:.ventureSimulation,principal:100,duePeriod:5)]
  game.banking=bank
  let view=try XCTUnwrap(VeilopolyBankAutomation.digest(game,player:0))
  XCTAssertTrue(view.notices[0].text.contains("尚未批准"))
 }
 func testMemoVariesAcrossPeriodsWithoutMutatingGame() throws {
  var game=GameFactory.make(seed:23)
  game.banking=IntegratedBankLedger()
  let start=game
  let view=VeilopolyBankAutomation.digest(game,player:0)
  XCTAssertEqual(view,VeilopolyBankAutomation.digest(game,player:0))
  XCTAssertEqual(game,start)
  var strings=Set<String>()
  for period in 0..<25 {
   game.banking?.completedTurns=period
   strings.insert(try XCTUnwrap(VeilopolyBankAutomation.digest(game,player:0)).memorandum)
  }
  XCTAssertGreaterThan(strings.count,1)
 }
}
