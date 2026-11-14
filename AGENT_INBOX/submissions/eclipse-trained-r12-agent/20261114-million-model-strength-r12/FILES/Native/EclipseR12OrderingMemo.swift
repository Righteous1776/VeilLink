import Foundation

/// Local-only exact-key memo for ECLIPSE's frozen 48-tree ordering model.
///
/// This is *not* a second learned model or a transposition table for search
/// values. Only heuristic candidate ordering scores are cached. It cannot
/// bypass hard tactical rules, prove a win or change a legality decision.
/// One instance belongs to one search, never a shared/global singleton.
///
/// A Zobrist fingerprint collision could alter candidate order (not rules).
/// Caller must use the existing position Zobrist hash and pass side+cell.
struct EclipseR12OrderingMemo: Sendable {
    struct Stats: Equatable, Sendable {
        var hits = 0
        var misses = 0
        var stores = 0
    }

    private struct Slot: Sendable {
        var boardHash: UInt64 = 0
        var index: UInt16 = 0
        var side: UInt8 = 0
        var value: Int = 0
        var occupied: Bool = false
    }

    private var slots: [Slot]
    private let mask: UInt64
    private(set) var stats = Stats()

    /// Capacity must be a power of two; 4096 slots cost roughly 128 KiB.
    init(capacity: Int = 4096) {
        precondition((1...65536).contains(capacity) && capacity.nonzeroBitCount == 1)
        slots = [Slot](repeating: Slot(), count: capacity)
        mask = UInt64(capacity - 1)
    }

    private func bucket(hash: UInt64, side: UInt8, index: Int) -> Int {
        var key = hash ^ (UInt64(side) &* 0x9e3779b97f4a7c15)
        key ^= UInt64(index) &* 0xbf58476d1ce4e5b9
        key ^= key >> 30
        key &*= 0xbf58476d1ce4e5b9
        key ^= key >> 27
        key &*= 0x94d049bb133111eb
        key ^= key >> 31
        return Int(key & mask)
    }

    mutating func get(hash: UInt64, side: UInt8, index: Int) -> Int? {
        guard (1...2).contains(side), (0..<225).contains(index) else { return nil }
        let v = slots[bucket(hash: hash, side: side, index: index)]
        if v.occupied && v.boardHash == hash && v.side == side && v.index == index {
            stats.hits += 1
            return v.value
        }
        stats.misses += 1
        return nil
    }

    mutating func put(hash: UInt64, side: UInt8, index: Int, value: Int) {
        guard (1...2).contains(side), (0..<225).contains(index) else { return }
        slots[bucket(hash: hash, side: side, index: index)] = Slot(
            boardHash: hash, index: UInt16(index), side: side, value: value, occupied: true
        )
        stats.stores += 1
    }

    /// Evaluates the unchanged frozen policy on misses. Cache is never allowed
    /// to *manufacture* a score for a position that was not evaluated.
    mutating func score(
        hash: UInt64, side: UInt8, index: Int, calculate: () -> Int
    ) -> Int {
        guard (1...2).contains(side), (0..<225).contains(index) else { return calculate() }
        if let cached = get(hash: hash, side: side, index: index) { return cached }
        let calculated = calculate()
        put(hash: hash, side: side, index: index, value: calculated)
        return calculated
    }
}
