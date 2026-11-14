import Foundation
import SwiftUI

/// True search timing and completed native engine measurements. Neither the
/// mechanical tick nor its speed is an estimate of AI completion percentage.
struct VeilEclipseRuntimeInstruments: View {
    let running: Bool
    let start: Date?
    let lastNodes: Int?
    let lastMilliseconds: Int?
    let trainedGames: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("ECLIPSE / 实测仪表", systemImage: "cpu.fill")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(VeilTheme.goldBright)
                Spacer()
                Text(running && start != nil ? "SEARCH" : "IDLE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(VeilTheme.secondaryText)
            }
            TimelineView(.periodic(from: .now,
                by: scenePhase != .active ? 5.0 : (reduceMotion ? 0.5 :
                    (ProcessInfo.processInfo.isLowPowerModeEnabled ? 0.25 : 0.1)))) { timeline in
                let elapsed = running && start != nil
                    ? max(0, timeline.date.timeIntervalSince(start!)) : 0
                HStack(spacing: 15) {
                    ZStack {
                        Circle().stroke(VeilTheme.hairline, lineWidth: 3)
                        ForEach(0..<24, id: \.self) { index in
                            Capsule()
                                .fill(running && !reduceMotion && scenePhase == .active &&
                                      index == Int(elapsed * 10) % 24
                                      ? VeilTheme.goldBright : VeilTheme.paleMetal.opacity(0.24))
                                .frame(width: 2, height: index % 6 == 0 ? 8 : 4)
                                .offset(y: -31)
                                .rotationEffect(.degrees(Double(index) * 15))
                        }
                        VStack(spacing: 1) {
                            Text(running && start != nil ? String(format: "%.1f", elapsed) : "—")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(VeilTheme.goldBright)
                            Text("SEC")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(VeilTheme.secondaryText)
                        }
                    }
                    .frame(width: 76, height: 76)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("LIVE CLOCK / 非搜索进度")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(VeilTheme.secondaryText)
                        Text(running ? "原生搜索进行中" : "等待下一次计算")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(VeilTheme.text)
                        Text("时钟取自真实启动时间；无实时节点时不虚构数字。")
                            .font(.caption2)
                            .foregroundColor(VeilTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 6) {
                cell("LAST NODES", lastNodes.map(String.init) ?? "—")
                cell("LAST MS", lastMilliseconds.map(String.init) ?? "—")
                cell("TRAINED", String(max(0, trainedGames)))
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("game.eclipse.measured-instruments")
    }

    private func cell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(VeilTheme.secondaryText)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(VeilTheme.goldBright)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(VeilTheme.subtleFill, in: RoundedRectangle(cornerRadius: 7))
    }
}
