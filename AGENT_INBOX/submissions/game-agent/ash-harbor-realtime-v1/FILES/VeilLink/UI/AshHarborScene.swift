import SpriteKit
import UIKit

final class AshHarborScene: SKScene {
    enum RenderTier: Equatable {
        case full
        case constrained

        static var recommended: RenderTier {
            let p = ProcessInfo.processInfo
            return p.isLowPowerModeEnabled || p.processorCount <= 2 || p.physicalMemory < 3_000_000_000
                ? .constrained : .full
        }

        var rainBirthRate: CGFloat { self == .full ? 220 : 86 }
        var fogCount: Int { self == .full ? 5 : 2 }
        var sprayCount: Int { self == .full ? 28 : 12 }
    }

    var onSnapshot: ((AshHarborSnapshot) -> Void)?
    var onEvent: ((AshHarborEvent) -> Void)?

    private var state: AshHarborState
    private var input = AshHarborInput()
    private let tier: RenderTier
    private var reduceMotion = false
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0

    private let cameraNode = SKCameraNode()
    private let skyLayer = SKNode()
    private let farHarborLayer = SKNode()
    private let midHarborLayer = SKNode()
    private let waterLayer = SKNode()
    private let hazardLayer = SKNode()
    private let actorLayer = SKNode()
    private let fogLayer = SKNode()
    private let weatherLayer = SKNode()

    private let boatNode = SKNode()
    private let searchlightNode = SKShapeNode()
    private let waterSurface = SKSpriteNode()
    private let stormOverlay = SKShapeNode()
    private let lightningOverlay = SKShapeNode()
    private let rescueRing = SKShapeNode(circleOfRadius: 34)

    private var rainEmitter: SKEmitterNode?
    private var debrisNodes: [Int: SKNode] = [:]
    private var rescueNodes: [Int: SKNode] = [:]

    init(seed: UInt64, level: AshHarborLevel = .prologue, renderTier: RenderTier = .recommended) {
        state = AshHarborState(seed: seed, level: level)
        tier = renderTier
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.018, green: 0.027, blue: 0.041, alpha: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var snapshot: AshHarborSnapshot { state.snapshot() }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = tier == .full ? 60 : 45
        if children.isEmpty { configureHierarchy() }
        rebuildForSize()
        publishSnapshot()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        rebuildForSize()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            updateVisuals()
            return
        }

        accumulator += min(0.10, max(0, currentTime - lastUpdateTime))
        lastUpdateTime = currentTime

        var catchup = 0
        while accumulator >= AshHarborState.fixedDelta && catchup < 5 {
            state.step(input: input)
            state.events.forEach(handle(event:))
            accumulator -= AshHarborState.fixedDelta
            catchup += 1
        }

        if catchup == 5 && accumulator >= AshHarborState.fixedDelta {
            accumulator = 0
        }

        updateVisuals()
        publishSnapshot()
    }

    func setThrottle(_ value: Double) { input.throttle = min(1, max(0, value)) }
    func setRudder(_ value: Double) { input.rudder = min(1, max(-1, value)) }
    func setRescuing(_ active: Bool) { input.rescuing = active }
    func setSearchlight(_ active: Bool) { input.searchlight = active }

    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled
        rebuildWeather()
    }

    func restart(seed: UInt64) {
        state = AshHarborState(seed: seed, level: state.level)
        input = AshHarborInput()
        lastUpdateTime = 0
        accumulator = 0
        debrisNodes.values.forEach { $0.removeFromParent() }
        rescueNodes.values.forEach { $0.removeFromParent() }
        debrisNodes.removeAll()
        rescueNodes.removeAll()
        cameraNode.removeAllActions()
        updateVisuals()
        publishSnapshot()
    }

    private func configureHierarchy() {
        [skyLayer, farHarborLayer, midHarborLayer, waterLayer, hazardLayer, actorLayer, fogLayer, weatherLayer]
            .forEach(addChild)

        configureBoat()
        actorLayer.addChild(boatNode)
        actorLayer.addChild(rescueRing)

        addChild(cameraNode)
        camera = cameraNode
        cameraNode.addChild(stormOverlay)
        cameraNode.addChild(lightningOverlay)
    }

    private func rebuildForSize() {
        guard size.width > 1, size.height > 1 else { return }
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        rebuildBackdrop()
        rebuildWater()
        rebuildWeather()
        rebuildOverlays()
        updateVisuals()
    }

    private func configureBoat() {
        let hullPath = CGMutablePath()
        hullPath.move(to: CGPoint(x: 36, y: 0))
        hullPath.addLine(to: CGPoint(x: 20, y: -12))
        hullPath.addLine(to: CGPoint(x: -30, y: -12))
        hullPath.addLine(to: CGPoint(x: -41, y: 1))
        hullPath.addLine(to: CGPoint(x: 28, y: 7))
        hullPath.closeSubpath()

        let hull = SKShapeNode(path: hullPath)
        hull.fillColor = UIColor(red: 0.18, green: 0.27, blue: 0.32, alpha: 1)
        hull.strokeColor = UIColor.white.withAlphaComponent(0.55)
        hull.lineWidth = 1.2
        boatNode.addChild(hull)

        let cabin = SKShapeNode(rectOf: CGSize(width: 26, height: 16), cornerRadius: 5)
        cabin.position = CGPoint(x: 2, y: 12)
        cabin.fillColor = UIColor(red: 0.10, green: 0.16, blue: 0.19, alpha: 1)
        cabin.strokeColor = UIColor.cyan.withAlphaComponent(0.45)
        boatNode.addChild(cabin)

        let lamp = SKShapeNode(circleOfRadius: 3.5)
        lamp.position = CGPoint(x: 17, y: 17)
        lamp.fillColor = UIColor(red: 1, green: 0.82, blue: 0.36, alpha: 1)
        lamp.strokeColor = .clear
        boatNode.addChild(lamp)

        searchlightNode.fillColor = UIColor(red: 1, green: 0.86, blue: 0.47, alpha: 0.07)
        searchlightNode.strokeColor = UIColor(red: 1, green: 0.88, blue: 0.52, alpha: 0.16)
        searchlightNode.lineWidth = 0.8
        searchlightNode.zPosition = -1
        boatNode.addChild(searchlightNode)

        rescueRing.strokeColor = UIColor.cyan.withAlphaComponent(0.72)
        rescueRing.fillColor = UIColor.cyan.withAlphaComponent(0.025)
        rescueRing.lineWidth = 1.4
        rescueRing.isHidden = true
    }

    private func rebuildBackdrop() {
        skyLayer.removeAllChildren()
        farHarborLayer.removeAllChildren()
        midHarborLayer.removeAllChildren()

        let sky = SKSpriteNode(
            color: UIColor(red: 0.028, green: 0.049, blue: 0.073, alpha: 1),
            size: size
        )
        sky.anchorPoint = CGPoint(x: 0, y: 0)
        skyLayer.addChild(sky)

        buildHarborLayer(
            farHarborLayer,
            count: tier == .full ? 34 : 22,
            baseY: size.height * 0.36,
            minHeight: 42,
            maxHeight: 130,
            color: UIColor(red: 0.055, green: 0.071, blue: 0.087, alpha: 0.82),
            salt: 19
        )

        buildHarborLayer(
            midHarborLayer,
            count: tier == .full ? 24 : 16,
            baseY: size.height * 0.31,
            minHeight: 66,
            maxHeight: 180,
            color: UIColor(red: 0.035, green: 0.047, blue: 0.058, alpha: 0.96),
            salt: 47
        )
    }

    private func buildHarborLayer(
        _ parent: SKNode,
        count: Int,
        baseY: CGFloat,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        color: UIColor,
        salt: UInt64
    ) {
        let span = size.width * 3.2
        let step = span / CGFloat(max(1, count))

        for index in 0..<count {
            let n = CGFloat(procedural(index: index, salt: salt))
            let height = minHeight + (maxHeight - minHeight) * n
            let width = step * (0.55 + CGFloat(procedural(index: index, salt: salt + 11)) * 0.72)

            let building = SKShapeNode(
                rectOf: CGSize(width: width, height: height),
                cornerRadius: 1.5
            )
            building.fillColor = color
            building.strokeColor = .clear
            building.position = CGPoint(
                x: -size.width + CGFloat(index) * step + width / 2,
                y: baseY + height / 2
            )
            parent.addChild(building)

            if index % 3 == 0 {
                let light = SKShapeNode(rectOf: CGSize(width: 3, height: 2))
                light.fillColor = UIColor(red: 1, green: 0.74, blue: 0.36, alpha: 0.35)
                light.strokeColor = .clear
                light.position = CGPoint(
                    x: building.position.x + width * 0.18,
                    y: baseY + height * 0.55
                )
                parent.addChild(light)
            }
        }
    }

    private func rebuildWater() {
        waterLayer.removeAllChildren()
        waterSurface.size = CGSize(width: size.width * 1.7, height: size.height * 0.42)
        waterSurface.anchorPoint = CGPoint(x: 0.5, y: 0)
        waterSurface.position = CGPoint(x: size.width / 2, y: 0)
        waterSurface.color = UIColor(red: 0.025, green: 0.105, blue: 0.145, alpha: 1)
        waterSurface.colorBlendFactor = 1

        let shader = SKShader(source: Self.waterShaderSource)
        shader.uniforms = [
            SKUniform(name: "u_storm", float: 0.4),
            SKUniform(name: "u_progress", float: 0.0)
        ]
        waterSurface.shader = shader
        waterLayer.addChild(waterSurface)
    }

    private func rebuildWeather() {
        weatherLayer.removeAllChildren()
        fogLayer.removeAllChildren()
        rainEmitter = nil

        let rain = SKEmitterNode()
        rain.particleTexture = makeRainTexture()
        rain.particleBirthRate = tier.rainBirthRate
        rain.particleLifetime = 1.05
        rain.particleLifetimeRange = 0.22
        rain.position = CGPoint(x: size.width / 2, y: size.height + 24)
        rain.particlePositionRange = CGVector(dx: size.width * 1.45, dy: 30)
        rain.particleSpeed = 760
        rain.particleSpeedRange = 170
        rain.emissionAngle = -.pi / 2.10
        rain.emissionAngleRange = 0.045
        rain.particleAlpha = 0.27
        rain.particleScale = tier == .full ? 0.84 : 0.64
        rain.particleColor = UIColor(red: 0.65, green: 0.78, blue: 0.90, alpha: 1)
        rain.particleColorBlendFactor = 1
        weatherLayer.addChild(rain)
        rainEmitter = rain

        for index in 0..<tier.fogCount {
            let fog = SKShapeNode(
                rectOf: CGSize(width: size.width * 0.9, height: size.height * 0.11),
                cornerRadius: size.height * 0.05
            )
            fog.fillColor = UIColor(white: 0.8, alpha: 0.025 + CGFloat(index) * 0.008)
            fog.strokeColor = .clear
            fog.position = CGPoint(
                x: -size.width * 0.35 + CGFloat(index) * size.width * 0.25,
                y: size.height * (0.47 + CGFloat(index) * 0.06)
            )
            fogLayer.addChild(fog)

            if !reduceMotion {
                let distance = size.width * (1.4 + CGFloat(index) * 0.16)
                fog.run(.repeatForever(.sequence([
                    .moveBy(x: distance, y: 0, duration: 18 + Double(index) * 4),
                    .moveBy(x: -distance, y: 0, duration: 0)
                ])))
            }
        }
    }

    private func rebuildOverlays() {
        let rect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )

        stormOverlay.path = CGPath(rect: rect, transform: nil)
        stormOverlay.fillColor = UIColor(red: 0.03, green: 0.08, blue: 0.13, alpha: 1)
        stormOverlay.strokeColor = .clear
        stormOverlay.zPosition = 100

        lightningOverlay.path = CGPath(rect: rect, transform: nil)
        lightningOverlay.fillColor = .white
        lightningOverlay.strokeColor = .clear
        lightningOverlay.blendMode = .add
        lightningOverlay.alpha = 0
        lightningOverlay.zPosition = 110
    }

    private func updateVisuals() {
        let boatX = size.width * 0.30
        let yFraction = CGFloat(
            (state.y - AshHarborState.minimumY) /
            (AshHarborState.maximumY - AshHarborState.minimumY)
        )
        let boatY = 54 + yFraction * max(80, size.height * 0.34)

        boatNode.position = CGPoint(x: boatX, y: boatY)
        boatNode.zRotation = CGFloat(state.velocityY / 620).clamped(to: -0.20...0.20)

        updateSearchlight()
        updateParallax()
        updateWorldNodes(boatX: boatX)
        updateWeatherMood()
    }

    private func updateSearchlight() {
        let length: CGFloat = input.searchlight && state.battery > 0 ? 180 : 0
        let half: CGFloat = 38
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 18, y: 13))
        path.addLine(to: CGPoint(x: 18 + length, y: half))
        path.addLine(to: CGPoint(x: 18 + length, y: -half))
        path.closeSubpath()
        searchlightNode.path = path
        searchlightNode.alpha = CGFloat(0.32 + 0.55 * state.battery / 100)
    }

    private func updateParallax() {
        let width = max(1, Double(size.width))
        farHarborLayer.position.x = -CGFloat((state.x * 0.028).truncatingRemainder(dividingBy: width))
        midHarborLayer.position.x = -CGFloat((state.x * 0.058).truncatingRemainder(dividingBy: width))
    }

    private func updateWorldNodes(boatX: CGFloat) {
        let visibleMin = state.x - 300
        let visibleMax = state.x + 900

        let visibleDebris = state.level.debris.filter { $0.x >= visibleMin && $0.x <= visibleMax }
        let debrisIDs = Set(visibleDebris.map(.id))
        for id in debrisNodes.keys where !debrisIDs.contains(id) {
            debrisNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for debris in visibleDebris {
            let node = debrisNodes[debris.id] ?? {
                let newNode = makeDebrisNode(debris)
                hazardLayer.addChild(newNode)
                debrisNodes[debris.id] = newNode
                return newNode
            }()
            node.position = mapWorld(x: debris.x, y: debris.y, boatX: boatX)
        }

        let visibleRescues = state.level.rescueSites.filter { $0.x >= visibleMin && $0.x <= visibleMax }
        let rescueIDs = Set(visibleRescues.map(.id))
        for id in rescueNodes.keys where !rescueIDs.contains(id) {
            rescueNodes.removeValue(forKey: id)?.removeFromParent()
        }

        for site in visibleRescues {
            let node = rescueNodes[site.id] ?? {
                let newNode = makeRescueNode(site)
                hazardLayer.addChild(newNode)
                rescueNodes[site.id] = newNode
                return newNode
            }()
            node.position = mapWorld(x: site.x, y: site.y, boatX: boatX)
            node.alpha = state.rescuedSiteIDs.contains(site.id) ? 0.16 : 1
        }

        if let active = state.activeRescueID,
           let node = rescueNodes[active] {
            rescueRing.isHidden = false
            rescueRing.position = node.position
            rescueRing.setScale(CGFloat(0.9 + state.snapshot().rescueProgress * 0.28))
        } else {
            rescueRing.isHidden = true
        }
    }

    private func mapWorld(x: Double, y: Double, boatX: CGFloat) -> CGPoint {
        let relative = x - state.x
        let screenX = boatX + CGFloat(relative / 850) * size.width
        let yFraction = CGFloat(
            (y - AshHarborState.minimumY) /
            (AshHarborState.maximumY - AshHarborState.minimumY)
        )
        return CGPoint(
            x: screenX,
            y: 54 + yFraction * max(80, size.height * 0.34)
        )
    }

    private func makeDebrisNode(_ debris: AshHarborDebris) -> SKNode {
        let root = SKNode()
        let body = SKShapeNode(rectOf: CGSize(width: 42, height: 17), cornerRadius: 4)
        body.fillColor = UIColor(red: 0.18, green: 0.13, blue: 0.10, alpha: 0.92)
        body.strokeColor = UIColor.white.withAlphaComponent(0.11)
        body.zRotation = CGFloat(procedural(index: debris.id, salt: 9) - 0.5) * 0.55
        root.addChild(body)
        return root
    }

    private func makeRescueNode(_ site: AshHarborRescueSite) -> SKNode {
        let root = SKNode()

        let buoy = SKShapeNode(circleOfRadius: 10)
        buoy.fillColor = UIColor(red: 0.92, green: 0.32, blue: 0.18, alpha: 1)
        buoy.strokeColor = UIColor.white.withAlphaComponent(0.55)
        root.addChild(buoy)

        let flare = SKShapeNode(circleOfRadius: 4)
        flare.position = CGPoint(x: 0, y: 17)
        flare.fillColor = UIColor(red: 1, green: 0.73, blue: 0.30, alpha: 1)
        flare.strokeColor = .clear
        flare.glowWidth = tier == .full ? 5 : 2
        root.addChild(flare)

        return root
    }

    private func updateWeatherMood() {
        let storm = CGFloat(state.stormIntensity)
        stormOverlay.alpha = 0.05 + storm * 0.16
        rainEmitter?.particleBirthRate = tier.rainBirthRate * (0.70 + storm * 0.62)
        waterSurface.shader?.uniformNamed("u_storm")?.floatValue = Float(storm)
        waterSurface.shader?.uniformNamed("u_progress")?.floatValue = Float(state.progress)
    }

    private func handle(event: AshHarborEvent) {
        onEvent?(event)

        switch event.kind {
        case .impact:
            spawnSpray(at: boatNode.position, color: .systemRed)
            shakeCamera()
        case .rescueStarted:
            break
        case .rescueCompleted:
            spawnSpray(at: rescueRing.position, color: .systemCyan)
        case .radio:
            break
        case .reachedHarbor:
            flash(color: UIColor(red: 1, green: 0.73, blue: 0.30, alpha: 1), peak: 0.34)
        case .hullLost:
            spawnSpray(at: boatNode.position, color: .systemOrange, multiplier: 2)
        case .timeExpired:
            flash(color: .white, peak: 0.16)
        }
    }

    private func spawnSpray(at position: CGPoint, color: UIColor, multiplier: Int = 1) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particleTexture = makeDotTexture(diameter: 6)
        emitter.particleBirthRate = 0
        emitter.numParticlesToEmit = tier.sprayCount * multiplier
        emitter.particleLifetime = 0.72
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 70
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.1
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    private func shakeCamera() {
        guard !reduceMotion else { return }
        let amplitude: CGFloat = tier == .full ? 7 : 3.5
        cameraNode.removeAction(forKey: "ash-shake")
        cameraNode.run(.sequence([
            .moveBy(x: amplitude, y: -amplitude * 0.3, duration: 0.025),
            .moveBy(x: -amplitude * 1.5, y: amplitude * 0.6, duration: 0.035),
            .moveBy(x: amplitude * 0.5, y: -amplitude * 0.3, duration: 0.045)
        ]), withKey: "ash-shake")
    }

    private func flash(color: UIColor, peak: CGFloat) {
        lightningOverlay.fillColor = color
        lightningOverlay.removeAllActions()
        lightningOverlay.run(.sequence([
            .fadeAlpha(to: peak, duration: 0.025),
            .fadeOut(withDuration: reduceMotion ? 0.01 : 0.18)
        ]))
    }

    private func publishSnapshot() {
        onSnapshot?(state.snapshot())
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
            UIBezierPath(
                ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)
            ).fill()
        }
        return SKTexture(image: image)
    }

    private func procedural(index: Int, salt: UInt64) -> Double {
        var z = UInt64(bitPattern: Int64(index)) &+ salt &* 0x9E3779B97F4A7C15
        z ^= z >> 30
        z &*= 0xBF58476D1CE4E5B9
        z ^= z >> 27
        z &*= 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z & 0xFFFF) / Double(0xFFFF)
    }

    private static let waterShaderSource = """
    void main() {
        vec2 uv = v_tex_coord;
        float storm = u_storm;
        float progress = u_progress;

        float waveA = sin((uv.x * 19.0) + (u_time * (2.0 + storm * 1.6)));
        float waveB = sin((uv.x * 41.0) - (u_time * 1.3) + uv.y * 8.0);
        float crest = smoothstep(0.52, 0.96, (waveA * 0.55 + waveB * 0.45 + 1.0) * 0.5);

        vec3 deep = vec3(0.015, 0.075, 0.11);
        vec3 cold = vec3(0.06, 0.22, 0.29);
        vec3 dawn = vec3(0.42, 0.20, 0.09);

        vec3 color = mix(deep, cold, uv.y * 0.55 + crest * 0.18);
        color = mix(color, dawn, progress * progress * 0.18);
        color += crest * vec3(0.06, 0.09, 0.10) * (0.5 + storm * 0.5);

        gl_FragColor = vec4(color, 1.0);
    }
    """
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
