import Foundation

/// OS entropy is used only in the iOS presentation layer at a new-match boundary.
/// Engine, replay, AI, market and network continue using stored seededRNG streams.
public enum VeilopolyNewGameSeed {
 public static func fresh(excluding previous: UInt64? = nil) -> UInt64 {
  var generator = SystemRandomNumberGenerator()
  var result = UInt64.random(in: UInt64.min...UInt64.max, using: &generator)
  // Avoid accidental identical successive sessions; no increment-by-one
  // coupling or repeated first-run default.
  if let previous {
   while result == previous {
    result = UInt64.random(in: UInt64.min...UInt64.max, using: &generator)
   }
  }
  return result
 }
}
