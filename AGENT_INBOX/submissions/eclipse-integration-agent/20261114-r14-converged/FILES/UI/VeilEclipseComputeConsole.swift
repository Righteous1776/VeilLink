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
                TimelineView(.animation(
                    minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 9.0 : 1.0 / 24.0,
                    paused: reduceMotion
                )) { timeline in
                    let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                    let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                    let position = VeilEclipseConsoleStream.scrollPosition(
                        elapsedSeconds: reduceMotion ? 0 : elapsed, lowPower: lowPower
                    )
                    let lineHeight: CGFloat = compact ? 11 : 15
                    let visibleCount = compact ? 2 : 7
                    let rows = VeilEclipseConsoleStream.lines(
                        elapsedSeconds: reduceMotion ? 0 : elapsed,
                        visibleRows: visibleCount + 1,
                        lowPower: lowPower
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<rows.count, id: \.self) { index in
                            Text(rows[index].text)
                                .font(.system(size: compact ? 8 : 10, weight: .medium, design: .monospaced))
                                .foregroundColor(tone(rows[index].tone))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(height: lineHeight, alignment: .leading)
                        }
                    }
                    .offset(y: -CGFloat(position - floor(position)) * lineHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: lineHeight * CGFloat(visibleCount), alignment: .top)
                    .clipped()
                    .accessibilityHidden(true)
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
                Text(VeilEclipseConsoleStream.disclosure)
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
        .accessibilityLabel("ECLIPSE 计算显示屏。\(active ? "计算中" : "待机")。装饰性编码流，不代表真实推理，也不会提示落点。")
    }

    private func tone(_ index: Int) -> Color {
        switch index {
        case 0: return VeilTheme.goldBright
        case 1: return VeilTheme.paleMetal
        case 2: return VeilTheme.success
        default: return VeilTheme.secondaryText
        }
    }
}
