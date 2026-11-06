/// Atlas geometry only. The image's original frame is specified using a top
/// origin; SpriteKit's SKTexture(rect:in:) expects normalized bottom origin.
public enum KimiK2AtlasGeometry {
 public struct Rect: Sendable, Equatable {
  public let x: Double; public let y: Double
  public let width: Double; public let height: Double
  public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
   self.x=x; self.y=y; self.width=width; self.height=height
  }
 }
 public static func bottomUV(frame: Rect, atlasWidth: Double = 2048, atlasHeight: Double = 1280) -> Rect? {
  guard atlasWidth > 0, atlasHeight > 0, frame.x >= 0, frame.y >= 0,
        frame.width > 0, frame.height > 0,
        frame.x + frame.width <= atlasWidth,
        frame.y + frame.height <= atlasHeight else { return nil }
  return Rect(frame.x / atlasWidth,
              (atlasHeight - frame.y - frame.height) / atlasHeight,
              frame.width / atlasWidth, frame.height / atlasHeight)
 }
 public static func radians(_ degrees: Double) -> Double { degrees * Double.pi / 180 }
}
