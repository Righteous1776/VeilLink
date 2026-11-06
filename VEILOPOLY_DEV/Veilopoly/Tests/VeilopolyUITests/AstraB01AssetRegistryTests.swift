import XCTest
@testable import VeilopolyUI

final class AstraB01AssetRegistryTests: XCTestCase {
 func testRuntimeResourcesHaveUniqueNames() {
  XCTAssertEqual(AstraB01AssetNames.imported.count, 13)
  XCTAssertEqual(Set(AstraB01AssetNames.imported).count, 13)
  XCTAssertTrue(AstraB01AssetNames.imported.allSatisfy { $0.hasPrefix("astra") })
 }
 func testButtonStateNeverSelectsPressedWhileDisabled() {
  XCTAssertEqual(AstraB01AssetNames.primaryButton(enabled: false, pressed: true),
                 AstraB01AssetNames.primaryDisabled)
  XCTAssertEqual(AstraB01AssetNames.primaryButton(enabled: true, pressed: false),
                 AstraB01AssetNames.primaryNormal)
  XCTAssertEqual(AstraB01AssetNames.primaryButton(enabled: true, pressed: true),
                 AstraB01AssetNames.primaryPressed)
 }
 func testFivePhaseHeroAliasesAreRegistered() {
  for phase in ["BUY", "AUCTION", "TRADE", "BANK", "SETTLEMENT"] {
   let alias = AstraB01AssetNames.phaseHero(phase)
   XCTAssertNotNil(alias)
   XCTAssertTrue(AstraB01AssetNames.imported.contains(alias!))
  }
  XCTAssertNil(AstraB01AssetNames.phaseHero("UNKNOWN"))
 }
}
