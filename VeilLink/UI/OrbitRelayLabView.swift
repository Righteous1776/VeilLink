import SwiftUI

struct OrbitRelayLabView: View {
    @State private var state = OrbitRelayState()
    @State private var sessionID = UUID().uuidString
    @State private var angle = 0.0
    @State private var power = 40.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerDeck
                arena
                controls
                lastTurnPanel
                if state.isFinished { resultPanel }
            }
            .padding(14)
        }
        .background(VeilInstrumentBackground())
        .navigationTitle("轨道接力 · Game Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("重置") { reset() }
                    .foregroundColor(VeilTheme.gold)
            }
        }
    }

    private var headerDeck: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                VeilLCDDisplay(
                    title: "YOU / RELAY",
                    value: "\(state.hostCraft.score)/\(OrbitRelayState.winningScore)"
                )
                .frame(maxWidth: .infinity)

                VeilLCDDisplay(
                    title: "TURN",
                    value: "\(state.turn + 1)"
                )
                .frame(width: 86)

                VeilLCDDisplay(
                    title: "BOT / RELAY",
                    value: "\(state.guestCraft.score)/\(OrbitRelayState.winningScore)"
                )
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                statusMeter(
                    title: "燃料",
                    value: state.hostCraft.fuel,
                    maximum: 100,
                    symbol: "fuelpump.fill"
                )
                statusMeter(
                    title: "稳定",
                    value: state.hostCraft.stability,
                    maximum: 5,
                    symbol: "gyroscope"
                )
                statusMeter(
                    title: "速度",
                    value: Int(state.hostCraft.velocity.magnitude.rounded()),
                    maximum: 160,
                    symbol: "speedometer"
                )
            }

            Text("固定步长轨道博弈：选择推力方向与力度，抢先捕获 3 个动态中继点。撞击边界或进入引力井会损失稳定性。")
                .font(.caption2)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                emphasized: true
            )
        )
    }

    private var arena: some View {
        Canvas { context, size in
            let sx = size.width / OrbitRelayState.fieldWidth
            let sy = size.height / OrbitRelayState.fieldHeight

            func point(_ p: OrbitRelayPoint) -> CGPoint {
                CGPoint(x: p.x * sx, y: p.y * sy)
            }

            let center = point(OrbitRelayState.center)
            let wellRadius = CGFloat(OrbitRelayState.exclusionRadius) * min(sx, sy)
            let relay = point(state.relayPoint(sessionID: sessionID))
            let relayRadius = CGFloat(OrbitRelayState.relayCaptureRadius) * min(sx, sy)

            var outer = Path()
            outer.addRoundedRect(
                in: CGRect(origin: .zero, size: size),
                cornerSize: CGSize(width: 18, height: 18)
            )
            context.fill(outer, with: .color(Color.black.opacity(0.42)))

            for fraction in [0.22, 0.38, 0.54] {
                let radius = min(size.width, size.height) * CGFloat(fraction)
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(0.055)),
                    lineWidth: 0.8
                )
            }

            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: center.x - wellRadius,
                        y: center.y - wellRadius,
                        width: wellRadius * 2,
                        height: wellRadius * 2
                    )
                ),
                with: .color(Color.black.opacity(0.72))
            )
            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: center.x - wellRadius,
                        y: center.y - wellRadius,
                        width: wellRadius * 2,
                        height: wellRadius * 2
                    )
                ),
                with: .color(VeilTheme.gold.opacity(0.32)),
                lineWidth: 1.2
            )

            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: relay.x - relayRadius,
                        y: relay.y - relayRadius,
                        width: relayRadius * 2,
                        height: relayRadius * 2
                    )
                ),
                with: .color(VeilTheme.goldBright),
                lineWidth: 2.2
            )
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: relay.x - 5,
                        y: relay.y - 5,
                        width: 10,
                        height: 10
                    )
                ),
                with: .color(VeilTheme.goldBright)
            )

            if let pathPoints = state.lastTurn?.path, pathPoints.count > 1 {
                var path = Path()
                path.move(to: point(pathPoints[0]))
                for sample in pathPoints.dropFirst() {
                    path.addLine(to: point(sample))
                }
                context.stroke(
                    path,
                    with: .color(VeilTheme.gold.opacity(0.42)),
                    lineWidth: 1.4
                )
            }

            drawCraft(
                context: &context,
                at: point(state.hostCraft.position),
                label: "YOU",
                active: state.currentPlayer == .host
            )
            drawCraft(
                context: &context,
                at: point(state.guestCraft.position),
                label: "BOT",
                active: state.currentPlayer == .guest
            )
        }
        .frame(height: 300)
        .padding(6)
        .background(Color.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .accessibilityLabel("轨道接力竞技场")
    }

    private var controls: some View {
        VStack(spacing: 10) {
            controlSlider(title: "推力方向", value: $angle, range: 0...359, suffix: "°")
            controlSlider(title: "推力功率", value: $power, range: 0...100, suffix: "%")

            Button {
                commitHumanTurn()
            } label: {
                Label(
                    state.isFinished ? "本局已结束" : "执行轨道脉冲",
                    systemImage: "move.3d"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(VeilPhysicalButtonStyle(accent: true))
            .disabled(state.isFinished || state.currentPlayer != .host)
        }
        .padding(12)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        )
    }

    @ViewBuilder
    private var lastTurnPanel: some View {
        if let result = state.lastTurn {
            HStack(spacing: 10) {
                VeilIndicatorLamp(
                    active: result.capturedRelay,
                    color: VeilTheme.goldBright
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.actor == .host ? "你的上一轨道段" : "BOT 上一轨道段")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(VeilTheme.text)
                    Text(turnSummary(result))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
            }
            .padding(10)
            .background(
                VeilInstrumentPlate(
                    shape: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            )
        }
    }

    private var resultPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: state.isDraw ? "equal.circle.fill" : "flag.checkered")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(VeilTheme.goldBright)
            Text(resultTitle)
                .font(.headline)
                .foregroundColor(VeilTheme.text)
            Text("你 \(state.hostCraft.score) : \(state.guestCraft.score) BOT · 剩余燃料 \(state.hostCraft.fuel)% · 稳定 \(state.hostCraft.stability)/5")
                .font(.caption.monospacedDigit())
                .foregroundColor(VeilTheme.secondaryText)
            Button("再来一局") { reset() }
                .buttonStyle(VeilPhysicalButtonStyle(accent: true))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                emphasized: true
            )
        )
    }

    private var resultTitle: String {
        if state.isDraw { return "轨道窗口关闭 · 平局" }
        return state.winner == .host ? "中继链建立完成" : "BOT 抢先完成中继链"
    }

    private func statusMeter(
        title: String,
        value: Int,
        maximum: Int,
        symbol: String
    ) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundColor(VeilTheme.gold)
            Text("\(value)/\(maximum)")
                .font(.caption2.bold().monospacedDigit())
                .foregroundColor(VeilTheme.text)
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func controlSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(width: 66, alignment: .leading)
            Slider(value: value, in: range, step: 1)
                .tint(VeilTheme.gold)
            Text("\(Int(value.wrappedValue.rounded()))\(suffix)")
                .font(.caption.monospacedDigit())
                .frame(width: 52, alignment: .trailing)
        }
    }

    private func commitHumanTurn() {
        let move = OrbitRelayMove(
            angle: Int(angle.rounded()) % 360,
            power: Int(power.rounded())
        )
        var next = state
        guard next.apply(move: move, actor: .host, sessionID: sessionID) else { return }
        applyState(next)

        guard !next.isFinished,
              let botMove = OrbitRelayBot.chooseMove(
                in: next,
                actor: .guest,
                sessionID: sessionID
              ) else { return }

        var afterBot = next
        guard afterBot.apply(
            move: botMove,
            actor: .guest,
            sessionID: sessionID
        ) else { return }
        applyState(afterBot)
    }

    private func applyState(_ next: OrbitRelayState) {
        if let animation = VeilMotionPolicy.animation(
            .resolve,
            reduceMotionRequested: reduceMotion
        ) {
            withAnimation(animation) { state = next }
        } else {
            state = next
        }
    }

    private func reset() {
        state = OrbitRelayState()
        sessionID = UUID().uuidString
        angle = 0
        power = 40
    }

    private func turnSummary(_ result: OrbitRelayTurnResult) -> String {
        var parts = [
            "A\(result.move.angle)°",
            "P\(result.move.power)%",
            "燃料 -\(result.fuelSpent)"
        ]
        if result.capturedRelay { parts.append("捕获中继") }
        if result.boundaryHits > 0 { parts.append("边界×\(result.boundaryHits)") }
        if result.wellWarning { parts.append("引力井警告") }
        return parts.joined(separator: " · ")
    }

    private func drawCraft(
        context: inout GraphicsContext,
        at point: CGPoint,
        label: String,
        active: Bool
    ) {
        let radius: CGFloat = active ? 10 : 8
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            ),
            with: .color(active ? VeilTheme.goldBright : Color.white.opacity(0.72))
        )

        context.draw(
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(.white),
            at: CGPoint(x: point.x, y: point.y - 17)
        )
    }
}
