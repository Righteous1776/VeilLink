import Foundation

/// Testable board-tap picking. Point and tile-center coordinates are always
/// measured in the same fixed 1024 × 940 SpriteKit scene coordinate space,
/// not physical iPhone pixels or the SwiftUI view's current scale.
struct VeilopolyTileHitTarget: Equatable {
 let index: Int
 let x: Double
 let y: Double
}

enum VeilopolyTileHitTesting {
 /// Prefer the closest square regardless of Dictionary iteration order.
 /// The radius excludes the board's large empty center and off-board taps.
 static func nearest(
  x: Double, y: Double,
  centers: [VeilopolyTileHitTarget],
  radius: Double = 60
 ) -> Int? {
  guard x.isFinite, y.isFinite, radius.isFinite, radius > 0 else { return nil }
  let cap = radius * radius
  var bestIndex: Int?
  var bestDistance = Double.infinity
  for cell in centers {
   guard cell.x.isFinite && cell.y.isFinite else { continue }
   let dx = x - cell.x
   let dy = y - cell.y
   let distance = dx * dx + dy * dy
   guard distance.isFinite && distance <= cap else { continue }
   if distance < bestDistance ||
      (distance == bestDistance && (bestIndex == nil || cell.index < bestIndex!)) {
    bestDistance = distance
    bestIndex = cell.index
   }
  }
  return bestIndex
 }
}
