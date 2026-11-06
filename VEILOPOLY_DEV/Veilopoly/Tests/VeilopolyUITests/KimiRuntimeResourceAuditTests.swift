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
}
