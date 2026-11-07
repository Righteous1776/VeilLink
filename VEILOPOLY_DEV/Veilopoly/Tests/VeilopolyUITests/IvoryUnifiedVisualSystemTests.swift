import XCTest
@testable import VeilopolyUI

final class IvoryUnifiedVisualSystemTests: XCTestCase {
 func testIvoryIsTheSingleAuthoritativeMainImage() {
  XCTAssertEqual(IvoryUnifiedVisualSystem.masterImageAlias, "ivoryR1CenterInlay")
  XCTAssertEqual(IvoryUnifiedVisualSystem.masterImageID, "VL-IVORY-R1-004")
  XCTAssertTrue(IvoryUnifiedVisualSystem.defaultLightTheme)
  XCTAssertEqual(IvoryUnifiedVisualSystem.minimumIOSMajorVersion, 15)
  XCTAssertEqual(IvoryUnifiedVisualSystem.boardRootName, "Veilopoly/IvoryUnifiedBoard")
 }
 func testComposedDecksTouchButNeverCoverMasterPlaque() {
  let left = IvoryUnifiedVisualSystem.centerX - IvoryUnifiedVisualSystem.centerSize / 2
  let right = IvoryUnifiedVisualSystem.centerX + IvoryUnifiedVisualSystem.centerSize / 2
  XCTAssertEqual(left, 288, accuracy: 0.01)
  XCTAssertEqual(right, 736, accuracy: 0.01)
  XCTAssertLessThanOrEqual(IvoryUnifiedVisualSystem.chanceDeckX + 38, left)
  XCTAssertGreaterThanOrEqual(IvoryUnifiedVisualSystem.chestDeckX - 38, right)
 }
 func testCodexArtworkStillParticipatesWithoutDuplicateOverdraw() {
  XCTAssertTrue(IvoryUnifiedVisualSystem.codexSpecialIconsRemainCanonical)
  XCTAssertFalse(IvoryUnifiedVisualSystem.independentGameplayState)
  XCTAssertTrue(IvoryUnifiedVisualSystem.integratedRuntimeAliases.contains(AstraTileArtwork.face))
  XCTAssertTrue(IvoryUnifiedVisualSystem.integratedRuntimeAliases.contains(AstraDetailArtwork.house))
  XCTAssertTrue(IvoryUnifiedVisualSystem.integratedRuntimeAliases.contains(AstraDetailArtwork.hotel))
  XCTAssertEqual(Set(IvoryUnifiedVisualSystem.integratedRuntimeAliases).count,
                 IvoryUnifiedVisualSystem.integratedRuntimeAliases.count)
 }
 func testMainArtExistsInSwiftPMResources() {
  XCTAssertNotNil(IvoryR1Artwork.resourceURL(for: IvoryUnifiedVisualSystem.masterImageAlias))
  XCTAssertNotNil(IvoryR1Artwork.resourceURL(for: IvoryUnifiedVisualSystem.turnBannerAlias))
 }
}
