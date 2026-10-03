import Foundation
import SwiftUI

/// Shared state surfaced by live tools instead of silently failing when hardware is unavailable.
enum VeilLiveToolState: Equatable, Sendable {
    case idle
    case requestingPermission
    case running
    case unavailable(String)
    case denied(String)
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .idle: return "等待启动"
        case .requestingPermission: return "正在请求系统权限"
        case .running: return "实时运行中"
        case .unavailable(let message), .denied(let message), .failed(let message): return message
        }
    }
}

struct VeilSoundReading: Equatable, Sendable {
    let decibels: Double
    let peakDecibels: Double
    let normalizedLevel: Double

    static let silence = VeilSoundReading(decibels: -80, peakDecibels: -80, normalizedLevel: 0)
}

enum VeilLiveToolMath {
    static func soundReading(rms: Double, peak: Double) -> VeilSoundReading {
        let safeRMS = max(rms, 0.000_1)
        let safePeak = max(peak, 0.000_1)
        let decibels = min(0, max(-80, 20 * log10(safeRMS)))
        let peakDecibels = min(0, max(-80, 20 * log10(safePeak)))
        // A square-root response keeps quiet speech visible without pretending to be a calibrated SPL meter.
        let normalized = min(1, max(0, pow(10, decibels / 40)))
        return VeilSoundReading(decibels: decibels, peakDecibels: peakDecibels, normalizedLevel: normalized)
    }

    static func downsample(_ samples: [Float], count: Int) -> [Double] {
        guard count > 0, !samples.isEmpty else { return [] }
        if samples.count <= count {
            return samples.map { min(1, abs(Double($0))) }
        }
        let stride = Double(samples.count) / Double(count)
        return (0..<count).map { index in
            let start = Int(Double(index) * stride)
            let end = min(samples.count, max(start + 1, Int(Double(index + 1) * stride)))
            let slice = samples[start..<end]
            let sum = slice.reduce(0.0) { $0 + Double($1 * $1) }
            return min(1, sqrt(sum / Double(slice.count)))
        }
    }

    static func levelAngles(gravityX: Double, gravityY: Double, gravityZ: Double) -> (roll: Double, pitch: Double) {
        let roll = atan2(gravityX, -gravityZ) * 180 / .pi
        let pitch = atan2(gravityY, sqrt(gravityX * gravityX + gravityZ * gravityZ)) * 180 / .pi
        return (roll, pitch)
    }

    static func clampedBubbleOffset(roll: Double, pitch: Double, radius: Double) -> (x: Double, y: Double) {
        guard radius > 0 else { return (0, 0) }
        var x = max(-radius, min(radius, roll / 15 * radius))
        var y = max(-radius, min(radius, pitch / 15 * radius))
        let distance = hypot(x, y)
        if distance > radius {
            x *= radius / distance
            y *= radius / distance
        }
        return (x, y)
    }

    static func metronomeInterval(bpm: Double) -> TimeInterval {
        60 / max(30, min(240, bpm))
    }

    static func metronomePhase(elapsed: TimeInterval, bpm: Double) -> Double {
        let interval = metronomeInterval(bpm: bpm)
        guard interval > 0 else { return 0 }
        let remainder = elapsed.truncatingRemainder(dividingBy: interval)
        return max(0, min(1, remainder / interval))
    }
}

enum VeilBeaconPattern: String, CaseIterable, Identifiable, Sendable {
    case steady
    case pulse
    case sos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steady: return "常亮"
        case .pulse: return "脉冲"
        case .sos: return "SOS"
        }
    }

    var systemImage: String {
        switch self {
        case .steady: return "flashlight.on.fill"
        case .pulse: return "waveform.path"
        case .sos: return "sos.circle.fill"
        }
    }

    var segments: [VeilBeaconSegment] {
        switch self {
        case .steady:
            return [VeilBeaconSegment(isOn: true, units: 1)]
        case .pulse:
            return [VeilBeaconSegment(isOn: true, units: 1), VeilBeaconSegment(isOn: false, units: 1)]
        case .sos:
            // International Morse timing: S (...), O (---), S (...), then a word gap.
            return [
                .init(isOn: true, units: 1), .init(isOn: false, units: 1),
                .init(isOn: true, units: 1), .init(isOn: false, units: 1),
                .init(isOn: true, units: 1), .init(isOn: false, units: 3),
                .init(isOn: true, units: 3), .init(isOn: false, units: 1),
                .init(isOn: true, units: 3), .init(isOn: false, units: 1),
                .init(isOn: true, units: 3), .init(isOn: false, units: 3),
                .init(isOn: true, units: 1), .init(isOn: false, units: 1),
                .init(isOn: true, units: 1), .init(isOn: false, units: 1),
                .init(isOn: true, units: 1), .init(isOn: false, units: 7)
            ]
        }
    }
}

struct VeilBeaconSegment: Equatable, Sendable {
    let isOn: Bool
    let units: Double
}

/// Compact, shared hardware-state indicator used by every realtime utility.
struct VeilLiveStateBadge: View {
    let state: VeilLiveToolState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("实时工具状态：\(state.message)")
    }

    private var label: String {
        switch state {
        case .idle: return "待机"
        case .requestingPermission: return "授权中"
        case .running: return "LIVE"
        case .unavailable: return "不可用"
        case .denied: return "未授权"
        case .failed: return "异常"
        }
    }

    private var tint: Color {
        switch state {
        case .idle: return VeilTheme.tertiaryText
        case .requestingPermission: return .orange
        case .running: return .green
        case .unavailable, .denied, .failed: return .red
        }
    }
}

/// Gives permission and hardware failures a visible, consistent home instead
/// of leaving a realtime screen looking inert.
struct VeilLiveStatusPanel: View {
    let state: VeilLiveToolState
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(VeilTheme.text)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .veilCard()
        .accessibilityElement(children: .combine)
    }

    private var statusDetail: String {
        switch state {
        case .unavailable, .denied, .failed:
            return state.message + "\n" + detail
        case .requestingPermission:
            return state.message + "。\n" + detail
        case .idle, .running:
            return detail
        }
    }

    private var icon: String {
        switch state {
        case .idle: return "pause.circle"
        case .requestingPermission: return "ellipsis.circle"
        case .running: return "waveform.path.ecg"
        case .unavailable: return "nosign"
        case .denied: return "hand.raised.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .idle: return VeilTheme.tertiaryText
        case .requestingPermission: return .orange
        case .running: return .green
        case .unavailable, .denied, .failed: return .red
        }
    }
}
