import XCTest
@testable import VeilopolyUI

final class KimiRuntimeResourceAuditTests: XCTestCase {
 func testAllSelectedBoardAndDirectKimiExtrasPresentInSwiftPMResources() {
  XCTAssertEqual(KimiK2RuntimeResourceAudit.expectedCount, 25)
  XCTAssertEqual(KimiK2RuntimeResourceAudit.expectedBytes, 897638)
  XCTAssertEqual(KimiK2RuntimeResourceAudit.missingResourceNames(), [])
  XCTAssertEqual(KimiK2RuntimeResourceAudit.invalidResourceLengths(), [])
 }

 func testUniqueKimiAndAstraIdentifiers() {
  let aliases = KimiK2BoardCatalog.assets.map(\.alias) +
   KimiK2RuntimeResourceAudit.additional.map(\.alias)
  XCTAssertEqual(Set(aliases).count, 25)
  XCTAssertTrue(Set(aliases).isDisjoint(with: Set(AstraB01AssetNames.imported)))
  XCTAssertTrue(KimiK2RuntimeResourceAudit.additional.allSatisfy {
   $0.alias.hasPrefix("kimi") && $0.gitBlobSHA1.count == 40
  })
 }
 func testKimiSourceWiringLedgerMatchesSelectedAssetsAndDoesNotOverlapAstra() {
  let selected = Set(KimiK2BoardCatalog.assets.map(\.alias) +
                     KimiK2RuntimeResourceAudit.additional.map(\.alias))
  let wired = KimiK2VisualUtilization.sourceWired
  let deferred = KimiK2VisualUtilization.deliberatelyDeferred
  XCTAssertEqual(wired.count,23)
  XCTAssertEqual(deferred.count,2)
  XCTAssertEqual(Set(wired+deferred),selected)
  XCTAssertEqual(Set(wired).count,wired.count)
  XCTAssertEqual(Set(deferred).count,deferred.count)
  XCTAssertTrue(Set(wired).isDisjoint(with:Set(deferred)))
  XCTAssertTrue(Set(wired).isDisjoint(with:Set(AstraB01AssetNames.imported)))
  XCTAssertEqual(KimiK2VisualUtilization.selectedCount,25)
 }

}
