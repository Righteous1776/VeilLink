import Foundation
import SwiftUI

/// Genuine *examined* hypothetical search branches, not random particles.
/// Visible only while the native AI is searching and the user cannot move.
/// Never retained as an active-game hint after the worker stops.
struct VeilEclipseBoardThoughtField: View {
    let isThinking: Bool
    let actualSearchStartedAt: Date?
    let enabled: Bool
    let searchTrace: VeilEclipseSearchTraceStore
    let sessionID: String
    let turn: Int
    let matchPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if enabled && isThinking && actualSearchStartedAt != nil && matchPlaying {
                TimelineView(.animation(
                    minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0/12.0 : 1.0/24.0,
                    paused: reduceMotion
                )) { _ in
                    let now = ProcessInfo.processInfo.systemUptime
                    let branches = searchTrace.snapshot(
                        sessionID: sessionID, turn: turn,
                        playing: matchPlaying, aiThinking: isThinking
                    )
                    Canvas(opaque: false, rendersAsynchronously: false) { context, area in
                        let margin = min(area.width, area.height) * 0.055
                        let step = (min(area.width, area.height) - margin * 2) / 14
                        let tones = [VeilTheme.goldBright, VeilTheme.paleMetal,
                                     VeilTheme.success, VeilTheme.mutedGold]
                        for (rank, branch) in branches.enumerated() {
                            let age = max(0, now - branch.emittedAtUptime)
                            let fading = max(0, 1.0 - age / 1.35)
                            guard fading > 0 else { continue }
                            let tone = tones[rank % tones.count]
                            let points = branch.indices.map { index in
                                CGPoint(x: margin + CGFloat(index % 15) * step,
                                        y: margin + CGFloat(index / 15) * step)
                            }
                            for hop in points.indices {
                                let progress = reduceMotion ? 1.0 : min(1, max(0, (age - Double(hop) * 0.09) * 9.0))
                                guard progress > 0 else { continue }
                                if hop > 0 {
                                    let a = points[hop - 1], b = points[hop]
                                    let tip = CGPoint(
                                        x: a.x + (b.x - a.x) * progress,
                                        y: a.y + (b.y - a.y) * progress
                                    )
                                    var path = Path()
                                    path.move(to: a)
                                    path.addLine(to: tip)
                                    context.stroke(path, with: .color(tone.opacity(0.65 * fading)),
                                                   style: StrokeStyle(lineWidth: 1.15, lineCap: .round))
                                }
                                if progress >= 0.96 {
                                    let r = max(3, step * 0.35)
                                    let point = points[hop]
                                    let oval = Path(ellipseIn: CGRect(
                                        x: point.x - r, y: point.y - r,
                                        width: r * 2, height: r * 2
                                    ))
                                    // Hollow/dashed: a hypothetical stone, not a placed stone.
                                    context.fill(oval, with: .color(tone.opacity(0.10 * fading)))
                                    context.stroke(oval, with: .color(tone.opacity(0.8 * fading)),
                                                   style: StrokeStyle(lineWidth: 1,
                                                                      lineCap: .round,
                                                                      dash: [2, 2]))
                                }
                            }
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("game.eclipse.live-examined-branches")
    }
}
