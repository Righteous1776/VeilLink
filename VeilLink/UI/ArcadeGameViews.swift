import SwiftUI

struct ArtilleryGameView: View {
    let state: ArtilleryState
    let sessionID: String
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let onFire: (Int, Int) -> Void

    @State private var angle = 45.0
    @State private var power = 68.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 10) {
                health("你", player: localPlayer)
                windGauge
                health("对手", player: localPlayer.opponent)
            }

            HStack(spacing: 8) {
                VeilInstrumentLabel(
                    title: "FIRE SOLUTION",
                    value: fireSolutionText,
                    active: predictedShot.damage > 0
                )
                Spacer()
                VeilInstrumentLabel(
                    title: "NEXT WIND",
                    value: formattedWind(ArtilleryState.wind(sessionID: sessionID, turn: state.turn + 1)),
                    active: true
                )
            }
            .padding(.horizontal, 4)

            battlefield
                .frame(height: 238)
                .padding(5)
                .background(Color.black.opacity(0.26))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.46), lineWidth: 1.2))

            VeilInstrumentBay(title: "火控输入", role: .input, active: enabled) {
                parameterSlider(title: "角度", value: $angle, range: 15...80, suffix: "°")
                parameterSlider(title: "力度", value: $power, range: 30...100, suffix: "%")
                Button {
                    onFire(Int(angle.rounded()), Int(power.rounded()))
                } label: {
                    Label(enabled ? "发射" : "等待对方射击", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                .disabled(!enabled)
            }

            if let shot = state.lastShot {
                Text(shot.damage > 0 ? "命中 · 造成 \(shot.damage) 点损伤" : "落点偏离 · 校正角度、力度并留意风向")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(shot.damage > 0 ? VeilTheme.goldBright : VeilTheme.secondaryText)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(12)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                emphasized: true
            )
        )
        .animation(VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion), value: state.turn)
    }

    private var wind: Int { ArtilleryState.wind(sessionID: sessionID, turn: state.turn) }

    private var predictedShot: ArtilleryShot {
        ArtilleryState.simulate(
            angle: Int(angle.rounded()),
            power: Int(power.rounded()),
            actor: localPlayer,
            sessionID: sessionID,
            turn: state.turn
        )
    }

    private var fireSolutionText: String {
        if predictedShot.damage >= 2 { return "DIRECT / 2 DMG" }
        if predictedShot.damage == 1 { return "SPLASH / 1 DMG" }
        let target = ArtilleryState.turretX(for: localPlayer.opponent)
        let miss = Int(abs(predictedShot.landingX - target).rounded())
        return "MISS ±\(miss)"
    }

    private func formattedWind(_ value: Int) -> String {
        if value == 0 { return "CALM" }
        return "\(value > 0 ? "→" : "←") \(abs(value))"
    }

    /// Legacy devices use a cheaper Canvas path. God-mode full visuals makes
    /// the central policy return `true`, restoring the richer rendering path.
    private var usesHighQualityRendering: Bool { VeilMotionPolicy.allowsFullSpatialEffects }

    private var windGauge: some View {
        VeilLCDDisplay(
            title: "WIND",
            value: formattedWind(wind)
        )
        .frame(width: 92)
    }

    private func health(_ title: String, player: MiniGamePlayer) -> some View {
        VeilGaugeMeter(
            title: title,
            value: Double(state.health(for: player)) / 5.0,
            text: "\(state.health(for: player))/5"
        )
        .frame(maxWidth: .infinity)
    }

    private var battlefield: some View {
        Canvas { context, size in
            let sx = size.width / ArtilleryState.worldWidth
            let sy = size.height / ArtilleryState.worldHeight
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [VeilTheme.panelSoft, VeilTheme.background]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            var terrain = Path()
            terrain.move(to: CGPoint(x: 0, y: size.height))
            let terrainSegments = usesHighQualityRendering ? 100 : 56
            for sample in 0...terrainSegments {
                let worldX = Double(sample) * ArtilleryState.worldWidth / Double(terrainSegments)
                let y = size.height - CGFloat(ArtilleryState.terrainHeight(at: worldX)) * sy
                terrain.addLine(to: CGPoint(x: CGFloat(worldX) * sx, y: y))
            }
            terrain.addLine(to: CGPoint(x: size.width, y: size.height))
            terrain.closeSubpath()
            context.fill(terrain, with: .linearGradient(
                Gradient(colors: [VeilTheme.goldDeep.opacity(0.58), VeilTheme.obsidian]),
                startPoint: CGPoint(x: 0, y: size.height * 0.68),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            drawTurret(.host, in: &context, size: size, sx: sx, sy: sy)
            drawTurret(.guest, in: &context, size: size, sx: sx, sy: sy)

            if enabled {
                var preview = Path()
                for (index, point) in trajectory(angle: Int(angle), power: Int(power), actor: localPlayer).enumerated() {
                    let mapped = CGPoint(x: CGFloat(point.x) * sx, y: size.height - CGFloat(point.y) * sy)
                    if index == 0 { preview.move(to: mapped) } else { preview.addLine(to: mapped) }
                }
                context.stroke(preview, with: .color(VeilTheme.gold.opacity(0.42)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 5]))
            }

            if let shot = state.lastShot {
                let point = CGPoint(x: CGFloat(shot.landingX) * sx, y: size.height - CGFloat(shot.landingY) * sy)
                let radius: CGFloat = shot.damage > 0 ? 17 : 8
                let impact = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                if usesHighQualityRendering {
                    context.fill(impact, with: .radialGradient(
                        Gradient(colors: [VeilTheme.goldBright.opacity(0.9), VeilTheme.danger.opacity(0.55), .clear]),
                        center: point,
                        startRadius: 1,
                        endRadius: radius
                    ))
                } else {
                    context.fill(impact, with: .color(VeilTheme.goldBright.opacity(shot.damage > 0 ? 0.72 : 0.42)))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("二维炮战战场，我方生命 \(state.health(for: localPlayer))，对方生命 \(state.health(for: localPlayer.opponent))")
        .accessibilityValue("风力 \(abs(wind))，方向 \(wind == 0 ? "无" : (wind > 0 ? "向右" : "向左"))")
        .accessibilityHint(enabled ? "调整角度和力度后发射" : "等待对方完成回合")
    }

    private func drawTurret(_ player: MiniGamePlayer, in context: inout GraphicsContext, size: CGSize, sx: CGFloat, sy: CGFloat) {
        let x = CGFloat(ArtilleryState.turretX(for: player)) * sx
        let y = size.height - CGFloat(ArtilleryState.terrainHeight(at: ArtilleryState.turretX(for: player))) * sy
        let rect = CGRect(x: x - 11, y: y - 13, width: 22, height: 13)
        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(player == localPlayer ? VeilTheme.goldBright : VeilTheme.secondaryText))
        var barrel = Path()
        barrel.move(to: CGPoint(x: x, y: y - 10))
        barrel.addLine(to: CGPoint(x: x + (player == .host ? 15 : -15), y: y - 21))
        context.stroke(barrel, with: .color(VeilTheme.paleMetal), lineWidth: 3)
    }

    private func trajectory(angle: Int, power: Int, actor: MiniGamePlayer) -> [(x: Double, y: Double)] {
        let radians = Double(angle) * .pi / 180
        let direction = actor == .host ? 1.0 : -1.0
        let speed = Double(power) * 2.85
        var x = ArtilleryState.turretX(for: actor)
        var y = ArtilleryState.terrainHeight(at: x) + 24
        var vx = cos(radians) * speed * direction
        var vy = sin(radians) * speed
        var result: [(Double, Double)] = []
        let sampleInterval = usesHighQualityRendering ? 7 : 14
        for tick in 0..<520 {
            vx += Double(wind) * 0.19 * 0.035
            vy -= 92 * 0.035
            x += vx * 0.035
            y += vy * 0.035
            if tick % sampleInterval == 0 { result.append((x, y)) }
            if x < 0 || x > ArtilleryState.worldWidth || y > ArtilleryState.worldHeight || y <= ArtilleryState.terrainHeight(at: x) { break }
        }
        return result
    }

    private func parameterSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VeilHardwareSlider(
            title: title,
            value: value,
            range: range,
            step: 1,
            suffix: suffix
        )
    }
}

struct LightTrailGameView: View {
    let state: LightTrailState
    let sessionID: String
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let onShift: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 8) {
                metric("SHIELD", "\(state.shield(for: localPlayer))/3")
                metric("ENERGY", "\(state.energy(for: localPlayer))")
                metric("SECTOR", "\(min(LightTrailState.rounds, state.round + 1))/\(LightTrailState.rounds)")
            }

            HStack(spacing: 8) {
                VeilInstrumentLabel(title: "ROUTE ADVISORY", value: routeAdvisory, active: true)
                Spacer()
                VeilInstrumentLabel(title: "SAFE LANES", value: safeLaneText, active: !safeLanes.isEmpty)
            }
            .padding(.horizontal, 4)

            track
                .frame(height: 300)
                .padding(5)
                .background(Color.black.opacity(0.26))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.46), lineWidth: 1.2))
            HStack(spacing: 10) {
                shiftButton(-1, title: "左移", icon: "arrow.left")
                shiftButton(0, title: "直行", icon: "arrow.up")
                shiftButton(1, title: "右移", icon: "arrow.right")
            }
            Text(state.lastCollision ? "护盾受损：下一赛段会刷新障碍" : (state.lastEnergyPickup ? "已吸收能量核心" : "预判前方障碍，选择安全光轨"))
                .font(.caption)
                .foregroundColor(state.lastCollision ? VeilTheme.danger : VeilTheme.secondaryText)
        }
        .padding(12)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                emphasized: true
            )
        )
        .animation(VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion), value: state.turn)
    }

    private var currentCourseRound: Int { state.turn / 2 }

    private var safeLanes: [Int] {
        let blocked = LightTrailState.obstacleLanes(
            sessionID: sessionID,
            round: currentCourseRound
        )
        return (0..<LightTrailState.laneCount).filter { !blocked.contains($0) }
    }

    private var safeLaneText: String {
        safeLanes.map { String($0 + 1) }.joined(separator: "·")
    }

    private var routeAdvisory: String {
        let lane = state.lane(for: localPlayer)
        let energy = LightTrailState.energyLane(
            sessionID: sessionID,
            round: currentCourseRound
        )
        let blocked = LightTrailState.obstacleLanes(
            sessionID: sessionID,
            round: currentCourseRound
        )
        if blocked.contains(lane) { return "CURRENT LANE BLOCKED" }
        if lane == energy { return "ENERGY ALIGNED" }
        if energy < lane { return "ENERGY LEFT" }
        if energy > lane { return "ENERGY RIGHT" }
        return "HOLD COURSE"
    }

    private var track: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [VeilTheme.background, VeilTheme.panelSoft, VeilTheme.obsidian]),
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            ))
            let laneWidth = size.width / CGFloat(LightTrailState.laneCount)
            for lane in 1..<LightTrailState.laneCount {
                var line = Path()
                line.move(to: CGPoint(x: CGFloat(lane) * laneWidth, y: 0))
                line.addLine(to: CGPoint(x: CGFloat(lane) * laneWidth, y: size.height))
                context.stroke(line, with: .color(VeilTheme.gold.opacity(0.15)), style: StrokeStyle(lineWidth: 1, dash: [5, 8]))
            }

            let round = state.turn / 2
            for depth in 0..<4 {
                let courseRound = min(LightTrailState.rounds - 1, round + depth)
                let y = size.height * (0.18 + CGFloat(depth) * 0.18)
                for lane in LightTrailState.obstacleLanes(sessionID: sessionID, round: courseRound) {
                    let rect = CGRect(x: CGFloat(lane) * laneWidth + 7, y: y, width: laneWidth - 14, height: 13)
                    context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(VeilTheme.danger.opacity(depth == 0 ? 0.9 : 0.48)))
                }
                let energyLane = LightTrailState.energyLane(sessionID: sessionID, round: courseRound)
                let energyPoint = CGPoint(x: (CGFloat(energyLane) + 0.5) * laneWidth, y: y - 14)
                context.fill(Path(ellipseIn: CGRect(x: energyPoint.x - 5, y: energyPoint.y - 5, width: 10, height: 10)), with: .color(VeilTheme.goldBright.opacity(depth == 0 ? 0.95 : 0.54)))
            }

            drawShip(localPlayer, lane: state.lane(for: localPlayer), y: size.height - 42, color: VeilTheme.goldBright, context: &context, laneWidth: laneWidth)
            drawShip(localPlayer.opponent, lane: state.lane(for: localPlayer.opponent), y: size.height - 88, color: VeilTheme.secondaryText, context: &context, laneWidth: laneWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("二维光轨赛道，当前第 \(state.round + 1) 赛段，我方在第 \(state.lane(for: localPlayer) + 1) 轨")
        .accessibilityValue("护盾 \(state.shield(for: localPlayer))，能量 \(state.energy(for: localPlayer))")
        .accessibilityHint(enabled ? "选择左移、直行或右移，避开红色障碍" : "等待对方完成回合")
    }

    private func drawShip(_ player: MiniGamePlayer, lane: Int, y: CGFloat, color: Color, context: inout GraphicsContext, laneWidth: CGFloat) {
        let centerX = (CGFloat(lane) + 0.5) * laneWidth
        var ship = Path()
        ship.move(to: CGPoint(x: centerX, y: y - 15))
        ship.addLine(to: CGPoint(x: centerX - 12, y: y + 13))
        ship.addLine(to: CGPoint(x: centerX, y: y + 7))
        ship.addLine(to: CGPoint(x: centerX + 12, y: y + 13))
        ship.closeSubpath()
        context.fill(ship, with: .color(color))
        var trail = Path()
        trail.move(to: CGPoint(x: centerX, y: y + 9))
        trail.addLine(to: CGPoint(x: centerX, y: y + 34))
        context.stroke(trail, with: .linearGradient(Gradient(colors: [color.opacity(0.7), .clear]), startPoint: CGPoint(x: centerX, y: y + 8), endPoint: CGPoint(x: centerX, y: y + 35)), lineWidth: 3)
    }

    private func shiftButton(_ shift: Int, title: String, icon: String) -> some View {
        let destination = state.lane(for: localPlayer) + shift
        return Button { onShift(shift) } label: {
            Label(title, systemImage: icon)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(VeilPhysicalButtonStyle())
        .disabled(!enabled || !(0..<LightTrailState.laneCount).contains(destination))
        .accessibilityLabel(title)
        .accessibilityHint((0..<LightTrailState.laneCount).contains(destination) ? "移动到第 \(destination + 1) 轨" : "已到达赛道边缘")
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VeilLCDDisplay(title: title, value: value)
            .frame(maxWidth: .infinity)
    }
}

struct MagneticHockeyGameView: View {
    let state: MagneticHockeyState
    let sessionID: String
    let localPlayer: MiniGamePlayer
    let enabled: Bool
    let onShoot: (Int, Int) -> Void

    @State private var angle: Double
    @State private var power = 64.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        state: MagneticHockeyState,
        sessionID: String,
        localPlayer: MiniGamePlayer,
        enabled: Bool,
        onShoot: @escaping (Int, Int) -> Void
    ) {
        self.state = state
        self.sessionID = sessionID
        self.localPlayer = localPlayer
        self.enabled = enabled
        self.onShoot = onShoot
        _angle = State(initialValue: localPlayer == .host ? 0 : 180)
    }

    var body: some View {
        VStack(spacing: 11) {
            HStack(spacing: 8) {
                score("YOU", state.score(for: localPlayer))
                VeilLCDDisplay(
                    title: "FIELD",
                    value: "\(polarity >= 0 ? "+" : "")\(polarity)"
                )
                .frame(width: 92)
                score("RIVAL", state.score(for: localPlayer.opponent))
            }

            HStack(spacing: 8) {
                VeilInstrumentLabel(title: "SHOT MODEL", value: shotForecastText, active: enabled)
                Spacer()
                VeilInstrumentLabel(title: "TURN", value: "\(state.turn + 1)/\(MagneticHockeyState.maximumTurns)", active: true)
            }
            .padding(.horizontal, 4)

            rink
                .frame(height: 230)
                .padding(5)
                .background(Color.black.opacity(0.26))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.46), lineWidth: 1.2))
            VeilInstrumentBay(title: "击球控制", role: .input, active: enabled) {
                slider("方向", value: $angle, range: 0...359, suffix: "°")
                    .accessibilityHint(localPlayer == .host ? "零度朝右侧球门" : "一百八十度朝左侧球门")
                slider("力度", value: $power, range: 10...100, suffix: "%")
                Button {
                    onShoot(Int(angle.rounded()) % 360, Int(power.rounded()))
                } label: {
                    Label(enabled ? "击球" : "等待对方击球", systemImage: "circle.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                .disabled(!enabled)
            }
            if let shot = state.lastShot {
                Text(shot.scoredPlayer == nil
                     ? "固定步 \(shot.fixedStepCount) · 反弹 \(shot.wallBounces) 次"
                     : "进球！冰球已回到中场")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(shot.scoredPlayer == nil ? VeilTheme.secondaryText : VeilTheme.goldBright)
            }
        }
        .padding(12)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                emphasized: true
            )
        )
        .animation(VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion), value: state.turn)
    }

    private var polarity: Int { MagneticHockeyState.fieldPolarity(sessionID: sessionID, turn: state.turn) }

    private var predictedShot: MagneticHockeyShot? {
        guard enabled else { return nil }
        var candidate = state
        guard candidate.apply(
            angle: Int(angle.rounded()) % 360,
            power: Int(power.rounded()),
            actor: localPlayer,
            sessionID: sessionID
        ) else { return nil }
        return candidate.lastShot
    }

    private var shotForecastText: String {
        guard let predictedShot else { return "WAIT" }
        if predictedShot.scoredPlayer == localPlayer { return "GOAL VECTOR" }
        if predictedShot.scoredPlayer == localPlayer.opponent { return "OWN GOAL RISK" }
        return "BOUNCE \(predictedShot.wallBounces) / \(predictedShot.fixedStepCount)T"
    }

    private var rink: some View {
        Canvas { context, size in
            let sx = size.width / MagneticHockeyState.fieldWidth
            let sy = size.height / MagneticHockeyState.fieldHeight
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [VeilTheme.panelSoft, VeilTheme.obsidian]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            ))

            var center = Path()
            center.move(to: CGPoint(x: size.width / 2, y: 0))
            center.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            context.stroke(center, with: .color(VeilTheme.gold.opacity(0.20)), style: StrokeStyle(lineWidth: 1, dash: [5, 6]))
            context.stroke(Path(ellipseIn: CGRect(x: size.width / 2 - 27, y: size.height / 2 - 27, width: 54, height: 54)), with: .color(VeilTheme.gold.opacity(0.18)), lineWidth: 1)

            let goalY = CGFloat(MagneticHockeyState.goalMinimumY) * sy
            let goalHeight = CGFloat(MagneticHockeyState.goalMaximumY - MagneticHockeyState.goalMinimumY) * sy
            context.fill(Path(CGRect(x: 0, y: goalY, width: 5, height: goalHeight)), with: .color(VeilTheme.gold.opacity(0.65)))
            context.fill(Path(CGRect(x: size.width - 5, y: goalY, width: 5, height: goalHeight)), with: .color(VeilTheme.gold.opacity(0.65)))

            if let shot = state.lastShot, shot.scoredPlayer == nil {
                var trail = Path()
                trail.move(to: CGPoint(x: CGFloat(shot.start.x) * sx, y: CGFloat(shot.start.y) * sy))
                trail.addLine(to: CGPoint(x: CGFloat(shot.end.x) * sx, y: CGFloat(shot.end.y) * sy))
                context.stroke(trail, with: .color(VeilTheme.gold.opacity(0.32)), style: StrokeStyle(lineWidth: 2, dash: [3, 5]))
            }

            let puck = CGPoint(x: CGFloat(state.puckPosition.x) * sx, y: CGFloat(state.puckPosition.y) * sy)
            context.fill(Path(ellipseIn: CGRect(x: puck.x - 9, y: puck.y - 9, width: 18, height: 18)), with: .color(VeilTheme.paleMetal))
            context.stroke(Path(ellipseIn: CGRect(x: puck.x - 12, y: puck.y - 12, width: 24, height: 24)), with: .color(VeilTheme.gold.opacity(0.35)), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("磁轨冰球场")
        .accessibilityValue("我方 \(state.score(for: localPlayer)) 球，对方 \(state.score(for: localPlayer.opponent)) 球，第 \(state.turn + 1) 杆，磁场 \(polarity)")
        .accessibilityHint(enabled ? "调整方向和力度后击球" : "等待对方")
    }

    private func score(_ title: String, _ value: Int) -> some View {
        VeilLCDDisplay(
            title: title,
            value: "\(value)/\(MagneticHockeyState.winningScore)"
        )
        .frame(maxWidth: .infinity)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VeilHardwareSlider(
            title: title,
            value: value,
            range: range,
            step: 1,
            suffix: suffix
        )
    }
}
