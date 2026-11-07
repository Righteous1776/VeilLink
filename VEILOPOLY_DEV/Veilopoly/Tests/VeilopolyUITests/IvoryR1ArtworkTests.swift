import XCTest
@testable import VeilopolyUI

final class IvoryR1ArtworkTests: XCTestCase {
 func testAllNineteenIdsHaveStableNamesAndGitHashes() {
  let entries = IvoryR1Artwork.items
  XCTAssertEqual(entries.count, 19)
  XCTAssertEqual(Set(entries.map(\.id)).count, 19)
  XCTAssertEqual(Set(entries.map(\.alias)).count, 19)
  XCTAssertTrue(entries.allSatisfy { row in
   row.id.hasPrefix("VL-IVORY-R1-") && row.alias.hasPrefix("ivoryR1") &&
   row.sha256.count == 64 && row.gitBlobSHA1.count == 40 && row.bytes > 0
  })
 }
 func testNoCodexAssetIsOverwrittenByNewAliases() {
  let codexAssets = Set(["astraCenterCity", "astraHouseGreen", "astraHotelRed",
                         "astraTileFace", "astraTileChance", "astraTileChest",
                         "astraTileRail", "astraTileElectric", "astraTileWater"])
  XCTAssertTrue(codexAssets.isDisjoint(with: Set(IvoryR1Artwork.items.map(\.alias))))
  XCTAssertEqual(Set(IvoryR1Artwork.activeAliases),
                 Set(["ivoryR1ChanceCard", "ivoryR1ChestCard", "ivoryR1VictoryBadge"]))
  XCTAssertEqual(IvoryR1Artwork.candidateAliases.count,16)
 }
 func testAllResourcesAreActuallyBundledAndResolve() {
  for asset in IvoryR1Artwork.items {
   XCTAssertNotNil(IvoryR1Artwork.resourceURL(for: asset.alias), asset.alias)
  }
  XCTAssertEqual(IvoryR1Artwork.preferredCardAlias(isChance: true),
                 IvoryR1Artwork.chanceCard)
  XCTAssertEqual(IvoryR1Artwork.preferredCardAlias(isChance: false),
                 IvoryR1Artwork.chestCard)
  XCTAssertEqual(IvoryR1Artwork.preferredVictoryBadgeAlias(),
                 IvoryR1Artwork.victoryBadge)
 }
 func testRuntimeDoesNotEnableUnapprovedCandiateOverrides() {
  XCTAssertTrue(IvoryR1Artwork.candidateAliases.contains(IvoryR1Artwork.centerCandidate))
  XCTAssertTrue(IvoryR1Artwork.candidateAliases.contains(IvoryR1Artwork.houseCandidate))
  XCTAssertTrue(IvoryR1Artwork.candidateAliases.contains(IvoryR1Artwork.hotelCandidate))
  XCTAssertTrue(IvoryR1Artwork.candidateAliases.contains(IvoryR1Artwork.bannerCandidate))
 }
}