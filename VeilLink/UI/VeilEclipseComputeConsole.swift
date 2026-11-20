import SwiftUI
import Foundation

/// The black console sits INSIDE the original VeilLink themed card.
/// It is a decorative display: no board coordinate, candidate, PV or
/// protected engine reasoning object can enter its public interface.
struct VeilEclipseComputeConsole: View {
    let isComputing: Bool
    let actualSearchStartedAt: Date?
    let liveMetrics: VeilEclipseTracePolicy.LiveMetrics?
    var compact: Bool = false

    @ObservedObject private var appearance = VeilAppearanceController.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var active: Bool { isComputing && actualSearchStartedAt != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(active ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                    .frame(width: 5, height: 5)
                Text("ECLIPSE // VISUAL STREAM")
                    .font(.system(size: compact ? 8 : 10, weight: .bold, design: .monospaced))
                    .foregroundColor(VeilTheme.paleMetal)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(active ? "RUN" : "IDLE")
                    .foregroundColor(active ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                    .font(.system(size: compact ? 8 : 10, weight: .medium, design: .monospaced))
            }
            if active, let startedAt = actualSearchStartedAt {
                // R17 selective adoption: a REAL elapsed clock in the retained
                // robot console. No fake code scroll, pseudo-search progress,
                // extra telemetry card, board ripple or decorative frame timer.
                TimelineView(.periodic(
                    from: .now,
                    by: scenePhase != .active ? 5.0 :
                        (reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 : 0.5)
                )) { timeline in
                    let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                    VStack(alignment: .leading, spacing: compact ? 3 : 7) {
                        HStack(spacing: 5) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: compact ? 8 : 11))
                            Text(String(format: "REAL CLOCK  T+%.1fs", elapsed))
                                .font(.system(size: compact ? 8 : 10, weight: .semibold, design: .monospaced))
                                .monospacedDigit()
                            Spacer(minLength: 0)
                            Text("ELAPSED")
                                .font(.system(size: compact ? 7 : 9, weight: .medium, design: .monospaced))
                                .foregroundColor(VeilTheme.goldBright)
                        }
                        .foregroundColor(VeilTheme.paleMetal)
                        Text("vis.compute ()")
                            .font(.system(size: compact ? 8 : 10, weight: .medium, design: .monospaced))
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("vis.idle ()")
                    .font(.system(size: compact ? 8 : 10, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
            }
            if !compact {
                if active, let liveMetrics {
                    let depth = liveMetrics.completedDepth.map { "D\($0)" } ?? "—"
                    let nodes = liveMetrics.visitedNodes.map(String.init) ?? "—"
                    Text("MEASURED · DEPTH \(depth) / NODES \(nodes)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(VeilTheme.goldBright)
                } else {
                    Text("MEASURED · 暂无实时深度/节点数据")
                        .font(.caption2)
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Text("仅显示真实时长和可用测量值，不模拟思考过程、节点或搜索完成百分比。")
                    .font(.caption2)
                    .foregroundColor(VeilTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: compact ? 55 : 166)
        .background(
            RoundedRectangle(cornerRadius: appearance.isPlainline ? 2 : 10, style: .continuous)
                .fill(Color.black.opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: appearance.isPlainline ? 2 : 10, style: .continuous)
                .stroke(VeilTheme.gold.opacity(appearance.isInstrument ? 0.24 : 0.12), lineWidth: 0.8)
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ECLIPSE 实时计算状态。\(active ? "计算中，显示真实已用时长" : "待机")。不会预测落点。")
    }

}
