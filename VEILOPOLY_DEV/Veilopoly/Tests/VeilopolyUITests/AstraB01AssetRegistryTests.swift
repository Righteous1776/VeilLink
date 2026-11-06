import XCTest
@testable import VeilopolyUI

final class AstraB01AssetRegistryTests: XCTestCase {
 func testRuntimeResourcesHaveUniqueNames() {
  XCTAssertEqual(AstraB01AssetNames.imported.count, 20)
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
 func testSecondaryAndPlayerSkinStatePriority() {
  XCTAssertEqual(AstraB01AssetNames.secondaryButton(enabled: false, pressed: true),
                 AstraB01AssetNames.secondaryDisabled)
  XCTAssertEqual(AstraB01AssetNames.secondaryButton(enabled: true, pressed: true),
                 AstraB01AssetNames.secondaryPressed)
  XCTAssertEqual(AstraB01AssetNames.playerSkin(bankrupt: true, jailed: true, current: true),
                 AstraB01AssetNames.playerBankrupt)
  XCTAssertEqual(AstraB01AssetNames.playerSkin(bankrupt: false, jailed: true, current: true),
                 AstraB01AssetNames.playerJailed)
  XCTAssertEqual(AstraB01AssetNames.playerSkin(bankrupt: false, jailed: false, current: true),
                 AstraB01AssetNames.playerCurrent)
  XCTAssertEqual(AstraB01AssetNames.playerSkin(bankrupt: false, jailed: false, current: false),
                 AstraB01AssetNames.playerNormal)
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
