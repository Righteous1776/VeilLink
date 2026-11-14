import Foundation

/// Decorative visual code. It does not receive search candidates, board cells,
/// threat maps, principal variations or any private reasoning data.
/// Genuine measured depth/nodes are shown separately, only if available.
enum VeilEclipseConsoleStream {
    struct Line: Equatable, Sendable {
        let text: String
        let tone: Int
    }
    private static let verbs = [
        "vis.sync", "vis.phase", "vis.flux", "vis.orbit",
        "vis.align", "vis.echo", "vis.fold", "vis.pulse"
    ]
    private static func mix(_ seed: UInt64) -> UInt64 {
        var x = seed &+ 0x9e3779b97f4a7c15
        x = (x ^ (x >> 30)) &* 0xbf58476d1ce4e5b9
        x = (x ^ (x >> 27)) &* 0x94d049bb133111eb
        return x ^ (x >> 31)
    }
    /// Visual row scrolls: 14 lines/s normal, 6 in Low Power Mode.
    /// Uses only genuine elapsed calculation time; rate is decorative, not a
    /// measure of model speed. The result is deterministic and bounded.
    static func scrollPosition(elapsedSeconds: Double, lowPower: Bool = false) -> Double {
        let elapsed = elapsedSeconds.isFinite ? max(0, min(86_400, elapsedSeconds)) : 0
        return elapsed * (lowPower ? 6 : 14)
    }
    static func lines(elapsedSeconds: Double, visibleRows: Int, lowPower: Bool = false) -> [Line] {
        let frame = UInt64(scrollPosition(elapsedSeconds: elapsedSeconds, lowPower: lowPower))
        let rows = max(1, min(10, visibleRows))
        return (0..<rows).map { row in
            let k = mix((frame &+ UInt64(row)) &* 0x2545f4914f6cdd1d)
            let operation = verbs[Int(k % UInt64(verbs.count))]
            let channel = Int((k >> 7) & 0xf)
            let phase = Int((k >> 12) & 0xff)
            let mask = Int((k >> 21) & 0xffff)
            return Line(
                text: String(format: "%@ (ch:%X, phase:%02X, flux:%04X)", operation, channel, phase, mask),
                tone: Int((k >> 40) & 3)
            )
        }
    }
    static let disclosure = "视觉编码流 · 非真实搜索日志，不表示候选落点或推理过程"
}
