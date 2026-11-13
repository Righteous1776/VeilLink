import Foundation

enum VeilEclipseThoughtPattern {
    struct Streak: Sendable, Equatable {
        let x: Double
        let y: Double
        let dx: Double
        let dy: Double
        let tone: Int
        let opacity: Double
    }

    private static func mix(_ x: UInt64) -> UInt64 {
        var v = x &+ 0x9e3779b97f4a7c15
        v = (v ^ (v >> 30)) &* 0xbf58476d1ce4e5b9
        v = (v ^ (v >> 27)) &* 0x94d049bb133111eb
        return v ^ (v >> 31)
    }

    /// Display-time only. Increasing density is artistic buildup with elapsed
    /// thinking time; it makes NO claim about the number of nodes explored.
    static func density(elapsedSeconds: Double, lowPower: Bool) -> Int {
        let elapsed = elapsedSeconds.isFinite ? max(0, min(30, elapsedSeconds)) : 0
        let count = 72 + Int(elapsed * 8)
        return min(lowPower ? 80 : 170, count)
    }

    static func frame(frame: Int, count: Int) -> [Streak] {
        guard frame >= 0, count > 0 else { return [] }
        return (0..<min(180, count)).map { i in
            let seed = mix(UInt64(i) &* 0x9e3779b97f4a7c15 &+ UInt64(frame) &* 0x632be59bd9b4e019)
            let a = mix(seed), b = mix(seed ^ 0xe7037ed1a0b428db)
            let x = Double(a & 0xffff) / 65_535.0
            let y = Double((a >> 16) & 0xffff) / 65_535.0
            // Off-square, flowing lines: nothing snaps to a Gomoku intersection.
            let dx = 0.008 + Double(b & 0x7ff) / 70_000.0
            let dy = Double((b >> 11) & 0x7ff) / 110_000.0 - 0.009
            return Streak(x: 0.055 + x * 0.89,
                          y: 0.055 + y * 0.89,
                          dx: dx, dy: dy,
                          tone: Int((b >> 23) & 3),
                          opacity: 0.22 + Double((b >> 32) & 0xff) / 1_800.0)
        }
    }
}

