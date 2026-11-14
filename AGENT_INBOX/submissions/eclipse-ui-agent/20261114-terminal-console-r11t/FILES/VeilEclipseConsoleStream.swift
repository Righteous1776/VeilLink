import Foundation

/// ECLIPSE's aesthetic console is intentionally NOT the model's reasoning trace.
/// This pure display generator has no API parameter for a board, a move, a
/// principal variation, a threat or a candidate. Its numbers are decorative.
/// Genuine node/depth measurements appear in a separate explicitly labeled row.
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

    /// At most 24 decorative frames/sec and <= 10 visible rows. The current
    /// frame is a function of elapsed genuine compute time, but neither rate nor
    /// row content describes model search complexity/progress.
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
