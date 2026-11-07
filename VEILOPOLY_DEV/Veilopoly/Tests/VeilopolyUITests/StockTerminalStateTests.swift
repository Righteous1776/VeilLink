import XCTest
import VeilopolyEngine
@testable import VeilopolyUI

final class StockTerminalStateTests: XCTestCase {
 func testRejectionsAccountForFeeCashAndActualHoldings() throws {
  var market = StockMarketEngine.initial(seed: 7)
  XCTAssertNotNil(StockTerminalState.rejection(market: market, player: 0, cash: 185,
   symbol: "VTL", shares: 10, buying: true))
  XCTAssertNil(StockTerminalState.rejection(market: market, player: 0, cash: 186,
   symbol: "VTL", shares: 10, buying: true))
  XCTAssertNotNil(StockTerminalState.rejection(market: market, player: 0, cash: 1500,
   symbol: "VTL", shares: 1, buying: false))
  var cash = 1500
  _ = try StockMarketEngine.buy(&market, player: 0, symbol: "VTL", shares: 10, cash: &cash)
  XCTAssertNil(StockTerminalState.rejection(market: market, player: 0, cash: cash,
   symbol: "VTL", shares: 10, buying: false))
  XCTAssertNotNil(StockTerminalState.rejection(market: market, player: 0, cash: 1_000_000_000,
   symbol: "VTL", shares: 10, buying: false))
  market.quotes[0].haltedTicks = 1
  XCTAssertNotNil(StockTerminalState.rejection(market: market, player: 0, cash: cash,
   symbol: "VTL", shares: 1, buying: true))
 }

 func testExecutionRequiresActualStructuredTradeEffect() {
  XCTAssertNil(StockExecution(sequence: 1, effect: Effect(.stockTicked)))
  XCTAssertNil(StockExecution(sequence: 1, effect: Effect(.stockSold, amount: 100)))
  let execution = StockExecution(sequence: 12, effect: Effect(.stockBought,
   player: 2, amount: -186, stockSymbol: "VTL", stockShares: 10, stockPriceCents: 1850))
  XCTAssertEqual(execution?.id, 12)
  XCTAssertEqual(execution?.cashDelta, -186)
  XCTAssertEqual(execution?.player, 2)
  XCTAssertEqual(execution?.bought, true)
 }

 func testChartInspectionClampsDragAndRejectsInvalidCoordinates() {
  XCTAssertEqual(StockTerminalState.chartIndex(fraction: -1, count: 60), 0)
  XCTAssertEqual(StockTerminalState.chartIndex(fraction: 2, count: 60), 59)
  XCTAssertEqual(StockTerminalState.chartIndex(fraction: 0.5, count: 5), 2)
  XCTAssertEqual(StockTerminalState.chartIndex(fraction: 0.5, count: 1), 0)
  XCTAssertNil(StockTerminalState.chartIndex(fraction: .nan, count: 5))
  XCTAssertNil(StockTerminalState.chartIndex(fraction: 0.5, count: 0))
 }
}
