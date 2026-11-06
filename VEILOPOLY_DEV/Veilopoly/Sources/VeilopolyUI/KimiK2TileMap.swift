/// Metadata-only canonical Kimi K2 40-cell visual geometry. No game-state changes.
public struct KimiK2TileSpec: Sendable, Equatable {
 public let index: Int
 public let id: String
 public let centerX: Double
 public let centerY: Double
 public let pixelX: Double
 public let pixelY: Double
 public let pixelWidth: Double
 public let pixelHeight: Double
 public let displayWidth: Double
 public let displayHeight: Double
 public let rotationDegrees: Double
 public let kind: String
 public var uvX: Double { pixelX / 2048 }
 public var uvY: Double { (1280 - pixelY - pixelHeight) / 1280 }
 public var uvWidth: Double { pixelWidth / 2048 }
 public var uvHeight: Double { pixelHeight / 1280 }
 public var rotationRadians: Double { rotationDegrees * Double.pi / 180 }
}
public enum KimiK2TileMap {
 public static let designWidth = 1024.0
 public static let designHeight = 940.0
 public static let tileCount = 40
 public static let tiles: [KimiK2TileSpec] = [
  .init(index: 0, id: "VL-K2-TILE-000", centerX: 932, centerY: 101.2889, pixelX: 10, pixelY: 10, pixelWidth: 236, pixelHeight: 236, displayWidth: 118, displayHeight: 118, rotationDegrees: 0, kind: "go"),
  .init(index: 1, id: "VL-K2-TILE-001", centerX: 832, centerY: 101.2889, pixelX: 306, pixelY: 10, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "street"),
  .init(index: 2, id: "VL-K2-TILE-002", centerX: 752, centerY: 101.2889, pixelX: 562, pixelY: 10, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "chest"),
  .init(index: 3, id: "VL-K2-TILE-003", centerX: 672, centerY: 101.2889, pixelX: 818, pixelY: 10, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "street"),
  .init(index: 4, id: "VL-K2-TILE-004", centerX: 592, centerY: 101.2889, pixelX: 1074, pixelY: 10, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "taxIncome"),
  .init(index: 5, id: "VL-K2-TILE-005", centerX: 512, centerY: 101.2889, pixelX: 1330, pixelY: 10, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "railroad"),
  .init(index: 6, id: "VL-K2-TILE-006", centerX: 432, centerY: 101.2889, pixelX: 1586, pixelY: 10, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "street"),
  .init(index: 7, id: "VL-K2-TILE-007", centerX: 352, centerY: 101.2889, pixelX: 1842, pixelY: 10, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "chance"),
  .init(index: 8, id: "VL-K2-TILE-008", centerX: 272, centerY: 101.2889, pixelX: 50, pixelY: 266, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "street"),
  .init(index: 9, id: "VL-K2-TILE-009", centerX: 192, centerY: 101.2889, pixelX: 306, pixelY: 266, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 0, kind: "street"),
  .init(index: 10, id: "VL-K2-TILE-010", centerX: 92, centerY: 101.2889, pixelX: 522, pixelY: 266, pixelWidth: 236, pixelHeight: 236, displayWidth: 118, displayHeight: 118, rotationDegrees: -90, kind: "jail"),
  .init(index: 11, id: "VL-K2-TILE-011", centerX: 92, centerY: 194.6618, pixelX: 824, pixelY: 266, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "street"),
  .init(index: 12, id: "VL-K2-TILE-012", centerX: 92, centerY: 265.4963, pixelX: 1080, pixelY: 266, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "utilityElectric"),
  .init(index: 13, id: "VL-K2-TILE-013", centerX: 92, centerY: 336.3309, pixelX: 1336, pixelY: 266, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "street"),
  .init(index: 14, id: "VL-K2-TILE-014", centerX: 92, centerY: 407.1654, pixelX: 1592, pixelY: 266, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "street"),
  .init(index: 15, id: "VL-K2-TILE-015", centerX: 92, centerY: 478, pixelX: 1848, pixelY: 266, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "railroad"),
  .init(index: 16, id: "VL-K2-TILE-016", centerX: 92, centerY: 548.8346, pixelX: 56, pixelY: 522, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "street"),
  .init(index: 17, id: "VL-K2-TILE-017", centerX: 92, centerY: 619.6691, pixelX: 312, pixelY: 522, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "chest"),
  .init(index: 18, id: "VL-K2-TILE-018", centerX: 92, centerY: 690.5037, pixelX: 568, pixelY: 522, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "street"),
  .init(index: 19, id: "VL-K2-TILE-019", centerX: 92, centerY: 761.3382, pixelX: 824, pixelY: 522, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: -90, kind: "street"),
  .init(index: 20, id: "VL-K2-TILE-020", centerX: 92, centerY: 854.7111, pixelX: 1034, pixelY: 522, pixelWidth: 236, pixelHeight: 236, displayWidth: 118, displayHeight: 118, rotationDegrees: 180, kind: "freeParking"),
  .init(index: 21, id: "VL-K2-TILE-021", centerX: 192, centerY: 854.7111, pixelX: 1330, pixelY: 522, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "street"),
  .init(index: 22, id: "VL-K2-TILE-022", centerX: 272, centerY: 854.7111, pixelX: 1586, pixelY: 522, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "chance"),
  .init(index: 23, id: "VL-K2-TILE-023", centerX: 352, centerY: 854.7111, pixelX: 1842, pixelY: 522, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "street"),
  .init(index: 24, id: "VL-K2-TILE-024", centerX: 432, centerY: 854.7111, pixelX: 50, pixelY: 778, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "street"),
  .init(index: 25, id: "VL-K2-TILE-025", centerX: 512, centerY: 854.7111, pixelX: 306, pixelY: 778, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "railroad"),
  .init(index: 26, id: "VL-K2-TILE-026", centerX: 592, centerY: 854.7111, pixelX: 562, pixelY: 778, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "street"),
  .init(index: 27, id: "VL-K2-TILE-027", centerX: 672, centerY: 854.7111, pixelX: 818, pixelY: 778, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "street"),
  .init(index: 28, id: "VL-K2-TILE-028", centerX: 752, centerY: 854.7111, pixelX: 1074, pixelY: 778, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "utilityWater"),
  .init(index: 29, id: "VL-K2-TILE-029", centerX: 832, centerY: 854.7111, pixelX: 1330, pixelY: 778, pixelWidth: 156, pixelHeight: 236, displayWidth: 78, displayHeight: 118, rotationDegrees: 180, kind: "street"),
  .init(index: 30, id: "VL-K2-TILE-030", centerX: 932, centerY: 854.7111, pixelX: 1546, pixelY: 778, pixelWidth: 236, pixelHeight: 236, displayWidth: 118, displayHeight: 118, rotationDegrees: 90, kind: "goToJail"),
  .init(index: 31, id: "VL-K2-TILE-031", centerX: 932, centerY: 761.3382, pixelX: 1848, pixelY: 778, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "street"),
  .init(index: 32, id: "VL-K2-TILE-032", centerX: 932, centerY: 690.5037, pixelX: 56, pixelY: 1034, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "street"),
  .init(index: 33, id: "VL-K2-TILE-033", centerX: 932, centerY: 619.6691, pixelX: 312, pixelY: 1034, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "chest"),
  .init(index: 34, id: "VL-K2-TILE-034", centerX: 932, centerY: 548.8346, pixelX: 568, pixelY: 1034, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "street"),
  .init(index: 35, id: "VL-K2-TILE-035", centerX: 932, centerY: 478, pixelX: 824, pixelY: 1034, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "railroad"),
  .init(index: 36, id: "VL-K2-TILE-036", centerX: 932, centerY: 407.1654, pixelX: 1080, pixelY: 1034, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "chance"),
  .init(index: 37, id: "VL-K2-TILE-037", centerX: 932, centerY: 336.3309, pixelX: 1336, pixelY: 1034, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "street"),
  .init(index: 38, id: "VL-K2-TILE-038", centerX: 932, centerY: 265.4963, pixelX: 1592, pixelY: 1034, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "taxLuxury"),
  .init(index: 39, id: "VL-K2-TILE-039", centerX: 932, centerY: 194.6618, pixelX: 1848, pixelY: 1034, pixelWidth: 144, pixelHeight: 236, displayWidth: 72, displayHeight: 118, rotationDegrees: 90, kind: "street"),
 ]
 public static func visual(for index: Int) -> KimiK2TileSpec? {
  tiles.indices.contains(index) ? tiles[index] : nil
 }
}
