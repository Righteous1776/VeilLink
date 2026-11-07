import Foundation
import VeilopolyEngine

/// Generated blank tile and architectural symbols. All names/prices stay live.
public enum AstraTileArtwork {
 public static let face = "astraTileFace"
 public static let icons = ["astraTileGo", "astraTileJail", "astraTilePark", "astraTileGoToJail",
                            "astraTileRail", "astraTileElectric", "astraTileWater", "astraTileChest",
                            "astraTileChance", "astraTileTax"]
 public static let aliases = [face] + icons
 public static func icon(for tile: Tile) -> String? {
  switch tile.kind {
  case .go: return icons[0]
  case .jail: return icons[1]
  case .freeParking: return icons[2]
  case .goToJail: return icons[3]
  case .railroad: return icons[4]
  case .utility: return tile.i == 28 ? icons[6] : icons[5]
  case .chest: return icons[7]
  case .chance: return icons[8]
  case .tax: return icons[9]
  case .street: return nil
  }
 }
 public static func resourceURL(_ alias: String) -> URL? {
  Bundle.module.url(forResource: alias, withExtension: "png")
 }

 public struct Layout {
  public let index: Int
  public let width: Double
  public let height: Double
  public let rotation: Double
  public var labelWidth: Double { max(16, width - 28) }
  public var priceY: Double { -height / 2 + ((21...29).contains(index) ? 22 : 10) }
  public var buildingY: Double { height / 2 - 22 }
  public var iconSize: Double { height < 90 ? 28 : 42 }
  public var iconY: Double { height < 90 ? 11 : 13 }
  public func nameY(special: Bool) -> Double {
   special ? (height < 90 ? -12 : -24) : -8
  }
  /// Convert screen-oriented offsets into a rotated tile's local coordinates.
  public func local(_ x: Double, _ y: Double) -> (x: Double, y: Double) {
   (x * cos(rotation) + y * sin(rotation), -x * sin(rotation) + y * cos(rotation))
  }
 }
 public static func layout(_ spec: KimiK2TileSpec) -> Layout {
  let quarterTurn = abs(spec.rotationDegrees) == 90
  return Layout(index: spec.index, width: quarterTurn ? spec.displayHeight : spec.displayWidth,
                height: quarterTurn ? spec.displayWidth : spec.displayHeight,
                rotation: spec.rotationRadians)
 }
}
