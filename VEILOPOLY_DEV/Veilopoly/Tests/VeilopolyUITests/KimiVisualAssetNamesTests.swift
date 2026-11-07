import XCTest
@testable import VeilopolyUI

final class KimiVisualAssetNamesTests: XCTestCase {
 func testKimiRuntimeCandidatesNeverOverrideAstra() {
  let kimi = KimiVisualAssetNames.runtimeCandidates
  XCTAssertEqual(kimi.count, 14)
  XCTAssertEqual(Set(kimi).count, kimi.count)
  XCTAssertTrue(kimi.allSatisfy { $0.hasPrefix("kimi") })
  XCTAssertTrue(Set(kimi).isDisjoint(with: Set(AstraB01AssetNames.imported)))
  XCTAssertTrue(Set(kimi).isDisjoint(with: Set(KimiVisualAssetNames.stagingOnly)))
 }

 func testFourTokenSlotsStableAndUnknownPlayerFailsClosed() {
  XCTAssertEqual(KimiVisualAssetNames.tokenCandidate(for: 0), "kimiTokenPawnBlue")
  XCTAssertEqual(KimiVisualAssetNames.tokenCandidate(for: 1), "kimiTokenCarRed")
  XCTAssertEqual(KimiVisualAssetNames.tokenCandidate(for: 2), "kimiTokenShipGreen")
  XCTAssertEqual(KimiVisualAssetNames.tokenCandidate(for: 3), "kimiTokenPlaneYellow")
  XCTAssertNil(KimiVisualAssetNames.tokenCandidate(for: -1))
  XCTAssertNil(KimiVisualAssetNames.tokenCandidate(for: 4))
 }

 func testDayFeltPaletteIsExplicitAndDoesNotChangeExistingTheme() {
  XCTAssertEqual(KimiDayFeltPalette.table, "#F5F0E6")
  XCTAssertEqual(KimiDayFeltPalette.primaryText, "#0F172A")
  XCTAssertEqual(KimiDayFeltPalette.bankBackground, "#ECFDF5")
 }
}
