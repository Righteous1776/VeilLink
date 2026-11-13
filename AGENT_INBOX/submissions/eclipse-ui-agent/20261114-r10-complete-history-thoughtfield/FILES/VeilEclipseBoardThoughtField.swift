import Foundation
import SwiftUI

/// Placed between the background grid and stones. Board tapping remains owned
/// by VeilBoardTapSurface, which is above this in the ZStack.
struct VeilEclipseBoardThoughtField: View {
    let isThinking: Bool
    let actualSearchStartedAt: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var appearance = VeilAppearanceController.shared

    var body: some View {
        Group {
            if isThinking {
                TimelineView(.animation(
                    minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 12.0 : 1.0 / 24.0,
                    paused: reduceMotion
                )) { timeline in
                    Canvas(opaque: false, rendersAsynchronously: false) { context, area in
                        let elapsed = max(0, timeline.date.timeIntervalSince(actualSearchStartedAt ?? timeline.date))
                        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                        let count = reduceMotion ? 18 : VeilEclipseThoughtPattern.density(
                            elapsedSeconds: elapsed, lowPower: lowPower
                        )
                        let frame = reduceMotion ? 0 : max(0, Int(timeline.date.timeIntervalSinceReferenceDate * 24))
                        let tones = [VeilTheme.goldBright, VeilTheme.paleMetal,
                                     VeilTheme.success, VeilTheme.mutedGold]
                        for spark in VeilEclipseThoughtPattern.frame(frame: frame, count: count) {
                            var ray = Path()
                            let first = CGPoint(x: spark.x * area.width, y: spark.y * area.height)
                            let second = CGPoint(x: first.x + spark.dx * area.width,
                                                 y: first.y + spark.dy * area.height)
                            ray.move(to: first)
                            ray.addLine(to: second)
                            context.stroke(ray,
                                with: .color(tones[spark.tone].opacity(spark.opacity)),
                                style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("game.eclipse.decorative-thinking-no-hints")
    }
}
