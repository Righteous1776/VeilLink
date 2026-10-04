import SpriteKit
import UIKit

@MainActor
final class AfterglowConvoyScene: SKScene {
    enum RenderTier: Equatable {
        case full
        case constrained

        static var recommended: RenderTier {
            let p = ProcessInfo.processInfo
            return p.isLowPowerModeEnabled || p.processorCount <= 2 || p.physicalMemory < 3_000_000_000
                ? .constrained : .full
        }

        var rainBirthRate: CGFloat { self == .full ? 180 : 72 }
        var fogCount: Int { self == .full ? 4 : 2 }
        var burstCount: Int { self == .full ? 32 : 14 }
        var shake: CGFloat { self == .full ? 8 : 4 }
    }

    var onSnapshot: ((AfterglowConvoySnapshot) -> Void)?
    var onEvent: ((AfterglowConvoyEvent) -> Void)?

    private var state: AfterglowConvoyState
    private var input = AfterglowConvoyInput()
    private var tier: RenderTier
    private var reduceMotion = false
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0
    private var lastLightningTick = -1

    private let farLayer = SKNode()
    private let midLayer = SKNode()
    private let nearLayer = SKNode()
    private let fogLayer = SKNode()
    private let hazardLayer = SKNode()
    private let actorLayer = SKNode()
    private let weatherLayer = SKNode()
    private let cameraNode = SKCameraNode()

    private let skiffNode = SKNode()
    private let beaconNode = SKNode()
    private let tetherNode = SKShapeNode()
    private let shieldNode = SKShapeNode(circleOfRadius: 36)
    private let stormOverlay = SKShapeNode()
    private let dawnOverlay = SKShapeNode()
    private let flashOverlay = SKShapeNode()
    private let lowEnergyEmitter = SKEmitterNode()
    private var rainEmitter: SKEmitterNode?
    private var beaconGlow: SKSpriteNode?
    private var hazardNodes: [Int: SKNode] = [:]

    init(seed: UInt64, renderTier: RenderTier = .recommended) {
        state = AfterglowConvoyState(seed: seed)
        tier = renderTier
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.025, green: 0.035, blue: 0.055, alpha: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var currentSnapshot: AfterglowConvoySnapshot {
        state.snapshot(shielding: input.shielding)
    }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = tier == .full ? ArcadeRenderPolicy.preferredFramesPerSecond : 45
        if children.isEmpty { configureHierarchy() }
        rebuildForSize()
        publishSnapshot()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildForSize()
    }

    override func update(_ currentTime: TimeInterval) {
        guard state.outcome == .running else { return }
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            updateVisualState()
            return
        }

        accumulator += min(0.10, max(0, currentTime - lastUpdateTime))
        lastUpdateTime = currentTime

        var catchup = 0
        var producedEvent = false
        while accumulator >= AfterglowConvoyState.fixedDelta && catchup < 5 {
            state.step(input: input)
            producedEvent = producedEvent || !state.events.isEmpty
            handle(events: state.events)
            accumulator -= AfterglowConvoyState.fixedDelta
            catchup += 1
        }
        if catchup == 5 && accumulator >= AfterglowConvoyState.fixedDelta {
            accumulator = 0
        }

        updateVisualState()
        if producedEvent || (catchup > 0 && state.tick.isMultiple(of: 2)) {
            publishSnapshot()
        }
    }

    func setVerticalSteering(_ value: Double) {
        input.vertical = min(1, max(-1, value))
    }

    func setShielding(_ enabled: Bool) {
        input.shielding = enabled
    }

    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled
        rebuildWeather()
    }

    func restart(seed: UInt64) {
        state = AfterglowConvoyState(seed: seed)
        input = AfterglowConvoyInput()
        lastUpdateTime = 0
        accumulator = 0
        lastLightningTick = -1
        hazardLayer.removeAllChildren()
        hazardNodes.removeAll()
        cameraNode.removeAllActions()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        updateVisualState()
        publishSnapshot()
    }

    private func configureHierarchy() {
        [farLayer, midLayer, fogLayer, nearLayer, hazardLayer, actorLayer, weatherLayer]
            .forEach(addChild)
        actorLayer.addChild(tetherNode)
        actorLayer.addChild(skiffNode)
        actorLayer.addChild(beaconNode)
        configureActors()

        addChild(cameraNode)
        camera = cameraNode
        cameraNode.addChild(stormOverlay)
        cameraNode.addChild(dawnOverlay)
        cameraNode.addChild(flashOverlay)
    }

    private func rebuildForSize() {
        guard size.width > 1, size.height > 1 else { return }
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        rebuildBackdrop()
        rebuildWeather()
        rebuildOverlays()
        updateVisualState()
    }

    private func configureActors() {
        let hull = SKShapeNode()
        let hullPath = CGMutablePath()
        hullPath.move(to: CGPoint(x: 25, y: 0))
        hullPath.addLine(to: CGPoint(x: -18, y: 13))
        hullPath.addLine(to: CGPoint(x: -10, y: 0))
        hullPath.addLine(to: CGPoint(x: -18, y: -13))
        hullPath.closeSubpath()
        hull.path = hullPath
        hull.fillColor = UIColor(red: 0.63, green: 0.78, blue: 0.88, alpha: 1)
        hull.strokeColor = UIColor.white.withAlphaComponent(0.72)
        skiffNode.addChild(hull)

        let cabin = SKShapeNode(circleOfRadius: 6)
        cabin.fillColor = UIColor(red: 0.08, green: 0.15, blue: 0.20, alpha: 1)
        cabin.strokeColor = UIColor.cyan.withAlphaComponent(0.68)
        skiffNode.addChild(cabin)

        let core = SKShapeNode(circleOfRadius: 8)
        core.fillColor = UIColor(red: 1, green: 0.78, blue: 0.28, alpha: 1)
        core.strokeColor = UIColor.white.withAlphaComponent(0.85)
        beaconNode.addChild(core)

        let glow = SKSpriteNode(texture: makeGlowTexture(size: 112))
        glow.size = CGSize(width: 84, height: 84)
        glow.blendMode = .add
        glow.zPosition = -1
        beaconNode.addChild(glow)
        beaconGlow = glow

        lowEnergyEmitter.particleTexture = makeDotTexture(diameter: 5)
        lowEnergyEmitter.particleLifetime = 0.7
        lowEnergyEmitter.particleSpeed = 42
        lowEnergyEmitter.particleSpeedRange = 24
        lowEnergyEmitter.emissionAngleRange = .pi * 2
        lowEnergyEmitter.particleAlpha = 0.72
        lowEnergyEmitter.particleAlphaSpeed = -0.9
        lowEnergyEmitter.particleColor = .orange
        lowEnergyEmitter.particleColorBlendFactor = 1
        lowEnergyEmitter.particleBlendMode = .add
        beaconNode.addChild(lowEnergyEmitter)

        shieldNode.fillColor = UIColor.cyan.withAlphaComponent(0.035)
        shieldNode.strokeColor = UIColor.cyan.withAlphaComponent(0.72)
        shieldNode.glowWidth = 3
        shieldNode.isHidden = true
        skiffNode.addChild(shieldNode)

        tetherNode.strokeColor = UIColor(red: 0.93, green: 0.68, blue: 0.26, alpha: 0.42)
        tetherNode.lineWidth = 1.4
    }

    private func rebuildBackdrop() {
        farLayer.removeAllChildren()
        midLayer.removeAllChildren()
        nearLayer.removeAllChildren()

        buildRuinLayer(farLayer, count: tier == .full ? 36 : 24, range: 0.10...0.30, baseline: 0.16, salt: 11,
                       color: UIColor(red: 0.08, green: 0.11, blue: 0.15, alpha: 0.68))
        buildRuinLayer(midLayer, count: tier == .full ? 28 : 18, range: 0.14...0.42, baseline: 0.10, salt: 37,
                       color: UIColor(red: 0.05, green: 0.075, blue: 0.10, alpha: 0.88))
        buildRuinLayer(nearLayer, count: tier == .full ? 18 : 12, range: 0.08...0.28, baseline: 0.035, salt: 73,
                       color: UIColor(red: 0.025, green: 0.04, blue: 0.055, alpha: 0.96))
    }

    private func buildRuinLayer(
        _ node: SKNode,
        count: Int,
        range: ClosedRange<CGFloat>,
        baseline: CGFloat,
        salt: UInt64,
        color: UIColor
    ) {
        let span = size.width * 3.2
        let step = span / CGFloat(max(1, count))
        for index in 0..<count {
            let n = CGFloat(procedural(index: index, salt: salt))
            let height = size.height * (range.lowerBound + (range.upperBound - range.lowerBound) * n)
            let width = step * (0.52 + CGFloat(procedural(index: index, salt: salt + 19)) * 0.66)
            let building = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 2)
            building.fillColor = color
            building.strokeColor = .clear
            building.position = CGPoint(x: -size.width + CGFloat(index) * step + width / 2,
                                        y: size.height * baseline + height / 2)
            node.addChild(building)
        }
    }

    private func rebuildWeather() {
        weatherLayer.removeAllChildren()
        fogLayer.removeAllChildren()
        rainEmitter = nil

        let rain = SKEmitterNode()
        rain.particleTexture = makeRainTexture()
        rain.particleBirthRate = tier.rainBirthRate
        rain.particleLifetime = 1.15
        rain.particleLifetimeRange = 0.25
        rain.position = CGPoint(x: size.width / 2, y: size.height + 20)
        rain.particlePositionRange = CGVector(dx: size.width * 1.35, dy: 30)
        rain.particleSpeed = 720
        rain.particleSpeedRange = 180
        rain.emissionAngle = -.pi / 2.13
        rain.emissionAngleRange = 0.05
        rain.particleAlpha = 0.25
        rain.particleScale = tier == .full ? 0.82 : 0.62
        rain.particleColor = UIColor(red: 0.66, green: 0.80, blue: 0.92, alpha: 1)
        rain.particleColorBlendFactor = 1
        weatherLayer.addChild(rain)
        rainEmitter = rain

        for index in 0..<tier.fogCount {
            let fog = SKShapeNode(rectOf: CGSize(width: size.width * 0.8, height: size.height * 0.13),
                                  cornerRadius: size.height * 0.06)
            fog.fillColor = UIColor(white: 0.74, alpha: 0.032 + CGFloat(index) * 0.009)
            fog.strokeColor = .clear
            fog.position = CGPoint(x: -size.width * 0.4 + CGFloat(index) * size.width * 0.28,
                                   y: size.height * (0.28 + CGFloat(index) * 0.16))
            fogLayer.addChild(fog)

            if !reduceMotion {
                let distance = size.width * (1.5 + CGFloat(index) * 0.2)
                fog.run(.repeatForever(.sequence([
                    .moveBy(x: distance, y: 0, duration: 16 + Double(index) * 4),
                    .moveBy(x: -distance, y: 0, duration: 0)
                ])))
            }
        }
    }

    private func rebuildOverlays() {
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        [stormOverlay, dawnOverlay, flashOverlay].forEach {
            $0.path = CGPath(rect: rect, transform: nil)
            $0.strokeColor = .clear
        }
        stormOverlay.fillColor = UIColor(red: 0.05, green: 0.12, blue: 0.20, alpha: 1)
        stormOverlay.zPosition = 90
        dawnOverlay.fillColor = UIColor(red: 1, green: 0.36, blue: 0.11, alpha: 1)
        dawnOverlay.blendMode = .add
        dawnOverlay.zPosition = 91
        flashOverlay.fillColor = .white
        flashOverlay.alpha = 0
        flashOverlay.blendMode = .add
        flashOverlay.zPosition = 120
    }

    private func updateVisualState() {
        let playerX = size.width * 0.29
        let f = CGFloat((state.y - AfterglowConvoyState.minimumY) /
                        (AfterglowConvoyState.maximumY - AfterglowConvoyState.minimumY))
        let playerY = 44 + f * max(80, size.height - 88)

        skiffNode.position = CGPoint(x: playerX, y: playerY)
        skiffNode.zRotation = CGFloat(state.velocityY / 520).clamped(to: -0.24...0.24)
        beaconNode.position = CGPoint(x: playerX - 46, y: playerY - 8 + CGFloat(sin(Double(state.tick) * 0.065)) * 3)

        let tether = CGMutablePath()
        tether.move(to: skiffNode.position)
        tether.addQuadCurve(to: beaconNode.position,
                            control: CGPoint(x: (skiffNode.position.x + beaconNode.position.x) / 2,
                                             y: min(skiffNode.position.y, beaconNode.position.y) - 12))
        tetherNode.path = tether

        let beaconFraction = CGFloat(state.beacon / 100)
        beaconGlow?.alpha = 0.22 + beaconFraction * 0.68
        beaconGlow?.setScale(0.72 + beaconFraction * 0.42)
        lowEnergyEmitter.particleBirthRate = state.beacon < 35 ? (tier == .full ? 14 : 6) : 0
        shieldNode.isHidden = !(input.shielding && state.shield > 0)
        shieldNode.alpha = CGFloat(0.32 + 0.58 * state.shield / 100)

        updateParallax()
        updateHazards(playerX: playerX)
        updateMood()
        updateLightning()
    }

    private func updateParallax() {
        let width = max(1, Double(size.width))
        farLayer.position.x = -CGFloat((state.x * 0.035).truncatingRemainder(dividingBy: width))
        midLayer.position.x = -CGFloat((state.x * 0.075).truncatingRemainder(dividingBy: width))
        nearLayer.position.x = -CGFloat((state.x * 0.14).truncatingRemainder(dividingBy: width))
    }

    private func updateHazards(playerX: CGFloat) {
        let current = Int(state.x / AfterglowConvoyState.segmentLength)
        let visible = Set((max(1, current - 1))...(current + 5))
        let stale = hazardNodes.keys.filter { !visible.contains($0) }
        for segment in stale {
            hazardNodes.removeValue(forKey: segment)?.removeFromParent()
        }

        for segment in visible.sorted() {
            let hazard = state.hazard(for: segment)
            let node = hazardNodes[segment] ?? {
                let new = makeHazardNode(hazard)
                hazardLayer.addChild(new)
                hazardNodes[segment] = new
                return new
            }()
            let relative = Double(segment) * AfterglowConvoyState.segmentLength - state.x
            let x = playerX + CGFloat(relative / 860) * size.width
            let yf = CGFloat((hazard.centerY - AfterglowConvoyState.minimumY) /
                             (AfterglowConvoyState.maximumY - AfterglowConvoyState.minimumY))
            node.position = CGPoint(x: x, y: 44 + yf * max(80, size.height - 88))
            node.isHidden = x < -100 || x > size.width + 100
        }
    }

    private func makeHazardNode(_ hazard: AfterglowHazard) -> SKNode {
        let root = SKNode()
        if hazard.isEmberCache {
            let ring = SKShapeNode(circleOfRadius: 17)
            ring.strokeColor = UIColor(red: 1, green: 0.68, blue: 0.18, alpha: 0.78)
            ring.fillColor = UIColor(red: 1, green: 0.54, blue: 0.12, alpha: 0.055)
            ring.glowWidth = tier == .full ? 5 : 2
            root.addChild(ring)
            let core = SKShapeNode(circleOfRadius: 4.5)
            core.fillColor = UIColor(red: 1, green: 0.86, blue: 0.38, alpha: 1)
            core.strokeColor = .clear
            root.addChild(core)
        } else {
            let rock = SKShapeNode(circleOfRadius: CGFloat(min(34, max(18, hazard.radius * 0.42))))
            rock.fillColor = UIColor(red: 0.16, green: 0.14, blue: 0.16, alpha: 0.92)
            rock.strokeColor = UIColor(red: 0.78, green: 0.28, blue: 0.20, alpha: 0.36)
            root.addChild(rock)
        }
        return root
    }

    private func updateMood() {
        let storm = CGFloat(state.stormIntensity)
        stormOverlay.alpha = 0.06 + storm * 0.18
        dawnOverlay.alpha = CGFloat(pow(state.progress, 3)) * (tier == .full ? 0.22 : 0.12)
        rainEmitter?.particleBirthRate = tier.rainBirthRate * (0.68 + storm * 0.70)
    }

    private func updateLightning() {
        let period = tier == .full ? 410 : 620
        let phase = Int(state.seed % UInt64(period))
        guard state.stormIntensity > 0.68, state.tick % period == phase, state.tick != lastLightningTick else { return }
        lastLightningTick = state.tick
        let peak: CGFloat = tier == .full ? 0.42 : 0.23
        flashOverlay.removeAllActions()
        flashOverlay.run(.sequence([
            .fadeAlpha(to: peak, duration: 0.025),
            .fadeAlpha(to: 0.04, duration: 0.055),
            .fadeAlpha(to: peak * 0.55, duration: 0.035),
            .fadeOut(withDuration: 0.13)
        ]))
    }

    private func handle(events: [AfterglowConvoyEvent]) {
        for event in events {
            onEvent?(event)
            switch event.kind {
            case .impact:
                spawnBurst(at: skiffNode.position, color: .systemRed)
                shakeCamera()
            case .emberRecovered:
                spawnBurst(at: beaconNode.position, color: .systemYellow)
            case .arrived:
                dawnOverlay.run(.fadeAlpha(to: 0.38, duration: reduceMotion ? 0.01 : 1.2))
            case .signalLost:
                beaconGlow?.run(.fadeOut(withDuration: reduceMotion ? 0.01 : 0.6))
            case .hullLost:
                spawnBurst(at: skiffNode.position, color: .systemOrange, multiplier: 2)
            case .storyBeat:
                break
            }
        }
    }

    private func spawnBurst(at position: CGPoint, color: UIColor, multiplier: Int = 1) {
        let e = SKEmitterNode()
        e.position = position
        e.particleTexture = makeDotTexture(diameter: 6)
        e.particleBirthRate = 0
        e.numParticlesToEmit = tier.burstCount * multiplier
        e.particleLifetime = 0.7
        e.particleSpeed = 110
        e.particleSpeedRange = 65
        e.emissionAngleRange = .pi * 2
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -1
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        addChild(e)
        e.run(.sequence([.wait(forDuration: 1.1), .removeFromParent()]))
    }

    private func shakeCamera() {
        guard !reduceMotion else { return }
        let a = tier.shake
        cameraNode.removeAction(forKey: "impact-shake")
        cameraNode.run(.sequence([
            .moveBy(x: a, y: -a * 0.45, duration: 0.025),
            .moveBy(x: -a * 1.7, y: a * 0.8, duration: 0.035),
            .moveBy(x: a * 0.7, y: -a * 0.35, duration: 0.045)
        ]), withKey: "impact-shake")
    }

    private func publishSnapshot() {
        onSnapshot?(state.snapshot(shielding: input.shielding))
    }

    private func makeRainTexture() -> SKTexture {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 20)).image { context in
            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.88).cgColor)
            context.cgContext.fill(CGRect(x: 1, y: 0, width: 1, height: 20))
        }
        return SKTexture(image: image)
    }

    private func makeDotTexture(diameter: CGFloat) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter)).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).fill()
        }
        return SKTexture(image: image)
    }

    private func makeGlowTexture(size: CGFloat) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
            let colors = [
                UIColor(red: 1, green: 0.75, blue: 0.22, alpha: 0.92).cgColor,
                UIColor(red: 1, green: 0.55, blue: 0.12, alpha: 0.28).cgColor,
                UIColor.clear.cgColor
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors,
                                            locations: [0, 0.28, 1]) else { return }
            let center = CGPoint(x: size / 2, y: size / 2)
            context.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                                 endCenter: center, endRadius: size / 2,
                                                 options: [.drawsAfterEndLocation])
        }
        return SKTexture(image: image)
    }

    private func procedural(index: Int, salt: UInt64) -> Double {
        var value = UInt64(bitPattern: Int64(index)) &+ salt &* 0x9E3779B97F4A7C15
        value ^= value >> 30
        value &*= 0xBF58476D1CE4E5B9
        value ^= value >> 27
        value &*= 0x94D049BB133111EB
        value ^= value >> 31
        return Double(value & 0xFFFF) / Double(0xFFFF)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, self))
    }
}
