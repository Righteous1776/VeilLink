/// B01 v1.1 author-declared action geometry for the paper auction hero.
/// Origin top-left. Dimensions in logical points, not source PNG pixels.
public enum AstraB01AuctionHitZones {
 public struct Region: Equatable, Sendable {
  public let x: Int
  public let y: Int
  public let width: Int
  public let height: Int
  public var centerX: Double { Double(x) + Double(width) / 2 }
  public var centerY: Double { Double(y) + Double(height) / 2 }
  public init(x: Int, y: Int, width: Int, height: Int) {
   self.x = x; self.y = y; self.width = width; self.height = height
  }
 }
 public static let canvasWidth = 256
 public static let canvasHeight = 174
 public static let minus = Region(x: 12, y: 118, width: 44, height: 44)
 public static let input = Region(x: 62, y: 118, width: 132, height: 44)
 public static let plus = Region(x: 200, y: 118, width: 44, height: 44)
}
