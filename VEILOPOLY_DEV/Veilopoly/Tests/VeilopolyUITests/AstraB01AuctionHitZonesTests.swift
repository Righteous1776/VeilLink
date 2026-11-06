import XCTest
@testable import VeilopolyUI

final class AstraB01AuctionHitZonesTests: XCTestCase {
 func testHitRegionsStayWithinTheArt() {
  for rect in [
   AstraB01AuctionHitZones.minus,
   AstraB01AuctionHitZones.input,
   AstraB01AuctionHitZones.plus,
  ] {
   XCTAssertGreaterThanOrEqual(rect.x, 0)
   XCTAssertGreaterThanOrEqual(rect.y, 0)
   XCTAssertLessThanOrEqual(rect.x + rect.width, AstraB01AuctionHitZones.canvasWidth)
   XCTAssertLessThanOrEqual(rect.y + rect.height, AstraB01AuctionHitZones.canvasHeight)
   XCTAssertGreaterThanOrEqual(rect.height, 44)
  }
 }
 func testMinusInputPlusHaveSeparateTouchTargets() {
  let minus = AstraB01AuctionHitZones.minus
  let input = AstraB01AuctionHitZones.input
  let plus = AstraB01AuctionHitZones.plus
  XCTAssertGreaterThanOrEqual(minus.width, 44)
  XCTAssertGreaterThanOrEqual(plus.width, 44)
  XCTAssertLessThanOrEqual(minus.x + minus.width, input.x)
  XCTAssertLessThanOrEqual(input.x + input.width, plus.x)
  XCTAssertEqual(minus.centerY, input.centerY)
  XCTAssertEqual(input.centerY, plus.centerY)
 }
 func testManifestInputSizeMatches() {
  XCTAssertEqual(AstraB01AuctionHitZones.input.width, 132)
  XCTAssertEqual(AstraB01AuctionHitZones.input.centerX, 128)
 }
}
