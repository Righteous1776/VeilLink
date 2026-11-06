import XCTest
@testable import VeilopolyEngine

final class PrintedTabletopReferenceTests: XCTestCase {
 func testStartRewardSkipsExactlyOnGoButPaysWhenPassing() {
  XCTAssertEqual(PrintedTabletopRules.startReward(from: 34, steps: 6), 0)
  XCTAssertEqual(PrintedTabletopRules.startReward(from: 38, steps: 5), 1000)
  XCTAssertEqual(PrintedTabletopRules.startReward(from: 10, steps: 5), 0)
  XCTAssertEqual(PrintedTabletopRules.startReward(from: 0, steps: 40), 0)
 }

 func testStarPoolEightTokensAndRepeatedCycles() throws {
  var state = PrintedStarState()
  for id in 0..<4 {
   let (next, event) = try PrintedStarRules.award(state, to: id, count: 2).get()
   state = next
   if id < 3 { XCTAssertFalse(event.cycleEnded) }
   if id == 3 {
    XCTAssertTrue(event.cycleEnded)
    XCTAssertEqual(event.leadingPlayers, [0, 1, 2, 3])
   }
  }
  XCTAssertEqual(state.bank, 8)
  XCTAssertEqual(state.owned, [0,0,0,0])
  XCTAssertEqual(state.completedCycles, 1)
 }

 func testStarAwardCannotOverspendSupply() throws {
  let (state, _) = try PrintedStarRules.award(.init(), to: 0, count: 7).get()
  switch PrintedStarRules.award(state, to: 1, count: 2) {
  case .failure(let error): XCTAssertEqual(error, .insufficientSupply)
  case .success: XCTFail("Must not mint extra stars")
  }
 }

 func testTimeBasedWinnerNeedsInjectedClockAndHandlesTie() {
  XCTAssertNil(PrintedTabletopRules.timedCashLeaders([1000,900,800,700], elapsedMinutes:59, selectedLimit:60))
  XCTAssertEqual(PrintedTabletopRules.timedCashLeaders([1000,1000,800,700], elapsedMinutes:60, selectedLimit:60), [0,1])
  XCTAssertNil(PrintedTabletopRules.timedCashLeaders([1000,900,800,700], elapsedMinutes:60, selectedLimit:45))
 }
}