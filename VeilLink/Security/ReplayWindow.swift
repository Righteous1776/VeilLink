import Foundation

struct ReplayWindow {
    private(set) var highestSequence: UInt64 = 0
    private var seenBitmap: UInt64 = 0

    func isPotentiallyFresh(_ sequence: UInt64) -> Bool {
        guard sequence > 0 else { return false }
        guard highestSequence > 0 else { return true }
        if sequence > highestSequence { return true }
        let distance = highestSequence - sequence
        guard distance < 64 else { return false }
        return (seenBitmap & (UInt64(1) << distance)) == 0
    }

    mutating func accept(_ sequence: UInt64) -> Bool {
        guard isPotentiallyFresh(sequence) else { return false }
        if highestSequence == 0 {
            highestSequence = sequence
            seenBitmap = 1
            return true
        }
        if sequence > highestSequence {
            let shift = sequence - highestSequence
            if shift >= 64 {
                seenBitmap = 1
            } else {
                seenBitmap = (seenBitmap << shift) | 1
            }
            highestSequence = sequence
            return true
        }
        let distance = highestSequence - sequence
        seenBitmap |= UInt64(1) << distance
        return true
    }
}
