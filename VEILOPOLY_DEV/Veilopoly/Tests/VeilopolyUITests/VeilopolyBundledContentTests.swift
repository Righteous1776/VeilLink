import XCTest
@testable import VeilopolyUI

final class VeilopolyBundledContentTests: XCTestCase {
 func testAllConfirmedImagesSoundsAndMetadataAreInRealPackageBundle() {
  XCTAssertEqual(VeilopolyBundledContent.imageAliases.count, 99)
  XCTAssertEqual(VeilopolyBundledContent.sounds.count, 13)
  XCTAssertEqual(VeilopolyBundledContent.missingResources, [])
  XCTAssertEqual(VeilopolyBundledContent.invalidImages, [])
 }
 func testConfirmedEditorialAndNewsAreCompiledOffline() {
  let text = VeilopolyBundledContent.compiledTextCounts
  XCTAssertEqual(text["cards"], 32)
  XCTAssertEqual(text["streets"], 40)
  XCTAssertEqual(text["issuers"], 5)
  XCTAssertEqual(text["guide"], 23)
  XCTAssertEqual(text["news"], 86)
 }
}
