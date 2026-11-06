import Foundation

/// Kimi K1 diceSheetWhite.png: 256x128 px; frame locations copied from the
/// supplied XML, converted from top-left origin to SpriteKit's bottom origin.
/// Pure metadata: no UI frameworks and no random source.
public enum VeilopolyDiceAtlasMap {
 public struct UV: Equatable, Sendable {
  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double
 }

 public static let imageName = "diceSheetWhite"
 public static let pixelWidth = 256
 public static let pixelHeight = 128
 public static let facePx = 64

 /// Package-level asset smoke check. Does not load or allocate a texture.
 public static func hasK1RuntimeResources() -> Bool {
  let required = [("diceSheetWhite", "png"), ("cardChanceAlt", "png"),
                  ("cardChestAlt", "png"), ("buildClick", "wav")]
  guard required.allSatisfy({ Bundle.module.url(forResource: $0.0, withExtension: $0.1) != nil }),
        let xmlURL = Bundle.module.url(forResource: "diceSheetWhiteFrames", withExtension: "xml"),
        let xml = try? String(contentsOf: xmlURL, encoding: .utf8) else { return false }
  return xml.contains("imagePath=\"diceSheetWhite.png\"")
 }

 public static func frame(face: Int) -> UV? {
  let topLeft: (x: Int, y: Int)
  switch face {
  case 1: topLeft = (64, 0)
  case 2: topLeft = (128, 0)
  case 3: topLeft = (64, 64)
  case 4: topLeft = (128, 64)
  case 5: topLeft = (0, 64)
  case 6: topLeft = (0, 0)
  default: return nil
  }
  return UV(x: Double(topLeft.x)/Double(pixelWidth),
            y: Double(pixelHeight-topLeft.y-facePx)/Double(pixelHeight),
            width: Double(facePx)/Double(pixelWidth),
            height: Double(facePx)/Double(pixelHeight))
 }
}
