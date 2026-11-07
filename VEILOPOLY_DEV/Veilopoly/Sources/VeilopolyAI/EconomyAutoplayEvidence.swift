import VeilopolyEngine

/// Deterministic offline test evidence, NOT duration in physical minutes.
public struct EconomyAutoplayEvidence: Equatable {
 public let seed: UInt64
 public let cityLong: Bool
 public let moves: Int
 public let completedTurns: Int
 public let finished: Bool
 public let winner: Int?
 public let bankruptSeats: Int
 public let firstBankruptcyAtMove: Int?
 public let liquidCash: [Int]
 public let propertyCounts: [Int]
 public let finalHash: String
}
