import SpriteKit
import CoreImage
import UIKit

final class RainlineLastTrainScene: SKScene {
    var onSnapshot: ((RainlineSnapshot) -> Void)?

    private var state: RainlineState
    private var input = RainlineInput()
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0

    private let cameraNode = SKCameraNode()
    private let skylineFar = SKNode()
    private let skylineNear = SKNode()
    private let roadReflectionLayer = SKNode()
    private let trainLayer = SKNode()
    private let trainGlowLayer = SKEffectNode()
    private let weatherLayer = SKNode()
    private let glassLayer = SKNode()
    private let stormOverlay = SKShapeNode()
    private let lightningOverlay = SKShapeNode()

    private let playerNode = SKNode()
    private var carNodes: [SKNode] = []
    private var carLightNodes: [SKShapeNode] = []
    private var faultEmitters: [Int: SKEmitterNode] = [:]
    private var rainEmitter: SKEmitterNode?
    private let glassRain = SKSpriteNode()

    init(seed: UInt64) {
        state = RainlineState(seed: seed)
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.018, green: 0.024, blue: 0.042, alpha: 1)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var snapshot: RainlineSnapshot { state.snapshot() }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
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

        accumulator += min(0.12, max(0, currentTime - lastUpdateTime))
        lastUpdateTime = currentTime

        var catchup = 0
        while accumulator >= RainlineState.fixedDelta && catchup < 6 {
            state.step(input: input)
            accumulator -= RainlineState.fixedDelta
            catchup += 1
        }
        if catchup == 6 && accumulator >= RainlineState.fixedDelta {
            accumulator = 0
        }

        updateVisuals()
        publishSnapshot()
    }

    func setMove(_ value: Double) {
        input.move = min(1, max(-1, value))
    }

    func setRepairing(_ active: Bool) {
        input.repairing = active
    }

    func setGridBoost(_ active: Bool) {
        input.boostGrid = active
    }

    func restart(seed: UInt64) {
        state = RainlineState(seed: seed)
        input = RainlineInput()
        lastUpdateTime = 0
        accumulator = 0
        faultEmitters.values.forEach { $0.removeFromParent() }
        faultEmitters.removeAll()
        updateVisuals()
        publishSnapshot()
    }

    private func configureHierarchy() {
        addChild(skylineFar)
        addChild(skylineNear)
        addChild(roadReflectionLayer)

        trainGlowLayer.shouldRasterize = false
        trainGlowLayer.filter = CIFilter(name: "CIBloom", parameters: [
            kCIInputRadiusKey: 9.0,
            kCIInputIntensityKey: 0.58
        ])
        addChild(trainGlowLayer)
        trainGlowLayer.addChild(trainLayer)

        addChild(weatherLayer)
        addChild(glassLayer)

        addChild(cameraNode)
        camera = cameraNode
        cameraNode.addChild(stormOverlay)
        cameraNode.addChild(lightningOverlay)

        configurePlayer()
        trainLayer.addChild(playerNode)
    }

    private func rebuildForSize() {
        guard size.width > 1, size.height > 1 else { return }
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        rebuildCity()
        rebuildTrain()
        rebuildWeather()
        rebuildGlass()
        rebuildOverlays()
        updateVisuals()
    }

    private func configurePlayer() {
        let body = SKShapeNode(roundedRectOf: CGSize(width: 13, height: 26), cornerRadius: 5)
        body.fillColor = UIColor(red: 0.72, green: 0.82, blue: 0.90, alpha: 1)
        body.strokeColor = UIColor.white.withAlphaComponent(0.65)
        playerNode.addChild(body)

        let lamp = SKShapeNode(circleOfRadius: 2.7)
        lamp.position = CGPoint(x: 5, y: 7)
        lamp.fillColor = UIColor(red: 1, green: 0.73, blue: 0.27, alpha: 1)
        lamp.strokeColor = .clear
        lamp.glowWidth = 4
        playerNode.addChild(lamp)
    }

    private func rebuildCity() {
        skylineFar.removeAllChildren()
        skylineNear.removeAllChildren()
        roadReflectionLayer.removeAllChildren()

        buildSkyline(
            parent: skylineFar,
            count: 36,
            baseY: size.height * 0.58,
            minHeight: 70,
            maxHeight: 260,
            color: UIColor(red: 0.04, green: 0.055, blue: 0.09, alpha: 0.76),
            lightAlpha: 0.16,
            salt: 21
        )

        buildSkyline(
            parent: skylineNear,
            count: 24,
            baseY: size.height * 0.48,
            minHeight: 110,
            maxHeight: 360,
            color: UIColor(red: 0.025, green: 0.035, blue: 0.058, alpha: 0.96),
            lightAlpha: 0.28,
            salt: 55
        )

        for index in 0..<18 {
            let stripe = SKShapeNode(rectOf: CGSize(width: 5, height: 80), cornerRadius: 2)
            let hues: [UIColor] = [.systemPink, .systemCyan, .systemPurple, .systemOrange]
            stripe.fillColor = hues[index % hues.count].withAlphaComponent(0.06)
            stripe.strokeColor = .clear
            stripe.position = CGPoint(
                x: CGFloat(index) * size.width / 8 - size.width,
                y: size.height * 0.32
            )
            stripe.zRotation = 0.35
            roadReflectionLayer.addChild(stripe)
        }
    }

    private func buildSkyline(
        parent: SKNode,
        count: Int,
        baseY: CGFloat,
        minHeight: CGFloat,
        maxHeight: CGFloat,
        color: UIColor,
        lightAlpha: CGFloat,
        salt: UInt64
    ) {
        let span = size.width * 3.4
        let step = span / CGFloat(count)

        for index in 0..<count {
            let h = minHeight + CGFloat(procedural(index: index, salt: salt)) * (maxHeight - minHeight)
            let w = step * (0.60 + CGFloat(procedural(index: index, salt: salt + 17)) * 0.52)
            let building = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 2)
            building.fillColor = color
            building.strokeColor = .clear
            building.position = CGPoint(
                x: -size.width + CGFloat(index) * step + w / 2,
                y: baseY + h / 2
            )
            parent.addChild(building)

            let windowCount = 2 + Int(procedural(index: index, salt: salt + 31) * 5)
            for lightIndex in 0..<windowCount {
                let light = SKShapeNode(rectOf: CGSize(width: 3, height: 5), cornerRadius: 1)
                let colors: [UIColor] = [.systemYellow, .systemCyan, .systemPink]
                light.fillColor = colors[(index + lightIndex) % colors.count].withAlphaComponent(lightAlpha)
                light.strokeColor = .clear
                light.position = CGPoint(
                    x: building.position.x + CGFloat(lightIndex % 2) * 10 - 5,
                    y: baseY + 18 + CGFloat(lightIndex) * min(18, h / CGFloat(windowCount + 1))
                )
                parent.addChild(light)
            }
        }
    }

    private func rebuildTrain() {
        trainLayer.removeAllChildren()
        carNodes.removeAll()
        carLightNodes.removeAll()
        trainLayer.addChild(playerNode)

        let trainWidth = size.width * 0.94
        let carWidth = trainWidth / CGFloat(RainlineState.carCount)
        let trainY = size.height * 0.22

        for car in 0..<RainlineState.carCount {
            let node = SKNode()
            node.position = CGPoint(
                x: size.width * 0.03 + carWidth * (CGFloat(car) + 0.5),
                y: trainY
            )

            let shell = SKShapeNode(
                roundedRectOf: CGSize(width: carWidth - 3, height: 126),
                cornerRadius: 7
            )
            shell.fillColor = UIColor(red: 0.055, green: 0.07, blue: 0.085, alpha: 0.98)
            shell.strokeColor = UIColor.white.withAlphaComponent(0.11)
            shell.lineWidth = 0.8
            node.addChild(shell)

            let interior = SKShapeNode(
                roundedRectOf: CGSize(width: carWidth - 10, height: 88),
                cornerRadius: 5
            )
            interior.fillColor = UIColor(red: 0.80, green: 0.64, blue: 0.32, alpha: 0.92)
            interior.strokeColor = UIColor.white.withAlphaComponent(0.12)
            node.addChild(interior)
            carLightNodes.append(interior)

            let floor = SKShapeNode(rectOf: CGSize(width: carWidth - 9, height: 5))
            floor.position = CGPoint(x: 0, y: -44)
            floor.fillColor = UIColor(white: 0.12, alpha: 1)
            floor.strokeColor = .clear
            node.addChild(floor)

            for passenger in 0..<3 {
                let silhouette = SKShapeNode(roundedRectOf: CGSize(width: 7, height: 18), cornerRadius: 3)
                silhouette.position = CGPoint(
                    x: CGFloat(passenger - 1) * max(8, carWidth * 0.18),
                    y: -15 + CGFloat(passenger % 2) * 5
                )
                silhouette.fillColor = UIColor(white: 0.05, alpha: 0.72)
                silhouette.strokeColor = .clear
                node.addChild(silhouette)
            }

            trainLayer.addChild(node)
            carNodes.append(node)
        }
    }

    private func rebuildWeather() {
        weatherLayer.removeAllChildren()
        rainEmitter = nil

        let rain = SKEmitterNode()
        rain.particleTexture = makeRainTexture()
        rain.particleBirthRate = 320
        rain.particleLifetime = 1.05
        rain.particleLifetimeRange = 0.18
        rain.position = CGPoint(x: size.width / 2, y: size.height + 20)
        rain.particlePositionRange = CGVector(dx: size.width * 1.5, dy: 20)
        rain.particleSpeed = 900
        rain.particleSpeedRange = 220
        rain.emissionAngle = -.pi / 2.08
        rain.emissionAngleRange = 0.045
        rain.particleAlpha = 0.34
        rain.particleScale = 0.82
        rain.particleColor = UIColor(red: 0.67, green: 0.80, blue: 0.94, alpha: 1)
        rain.particleColorBlendFactor = 1
        weatherLayer.addChild(rain)
        rainEmitter = rain
    }

    private func rebuildGlass() {
        glassLayer.removeAllChildren()
        glassRain.size = size
        glassRain.anchorPoint = CGPoint(x: 0, y: 0)
        glassRain.position = .zero
        glassRain.color = .clear
        glassRain.colorBlendFactor = 0
        glassRain.shader = SKShader(source: Self.glassRainShader)
        glassRain.shader?.uniforms = [
            SKUniform(name: "u_rain", float: 0.5),
            SKUniform(name: "u_power", float: 1.0)
        ]
        glassRain.zPosition = 70
        glassLayer.addChild(glassRain)
    }

    private func rebuildOverlays() {
        let rect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )
        stormOverlay.path = CGPath(rect: rect, transform: nil)
        stormOverlay.fillColor = UIColor(red: 0.03, green: 0.055, blue: 0.11, alpha: 1)
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
        let snapshot = state.snapshot()
        updateParallax(snapshot: snapshot)
        updateTrain(snapshot: snapshot)
        updateFaultEffects(snapshot: snapshot)
        updateWeather(snapshot: snapshot)
    }

    private func updateParallax(snapshot: RainlineSnapshot) {
        let speed = 1.4 + snapshot.traction / 100 * 3.2
        skylineFar.position.x -= CGFloat(speed * 0.45)
        skylineNear.position.x -= CGFloat(speed * 1.05)
        roadReflectionLayer.position.x -= CGFloat(speed * 1.5)

        wrap(layer: skylineFar, width: size.width * 1.7)
        wrap(layer: skylineNear, width: size.width * 1.7)
        wrap(layer: roadReflectionLayer, width: size.width * 1.7)
    }

    private func updateTrain(snapshot: RainlineSnapshot) {
        let trainWidth = size.width * 0.94
        let carWidth = trainWidth / CGFloat(RainlineState.carCount)
        let baseX = size.width * 0.03

        for car in 0..<min(carNodes.count, state.carPower.count) {
            let power = CGFloat(state.carPower[car])
            let fault = state.fault(for: car)
            let warm = UIColor(red: 0.96, green: 0.73, blue: 0.34, alpha: 1)
            let dim = UIColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1)
            carLightNodes[car].fillColor = blend(dim, warm, factor: power)
            carLightNodes[car].alpha = 0.30 + power * 0.70

            if fault != nil {
                carNodes[car].xScale = 1 + CGFloat(sin(Double(state.tick) * 0.31 + Double(car))) * 0.002
            } else {
                carNodes[car].xScale = 1
            }
        }

        let px = baseX + carWidth * (CGFloat(snapshot.playerCar) + CGFloat(snapshot.playerOffset))
        playerNode.position = CGPoint(x: px, y: size.height * 0.22 - 18)
        playerNode.xScale = input.move < -0.05 ? -1 : 1
    }

    private func updateFaultEffects(snapshot: RainlineSnapshot) {
        let active = state.faults.filter { !state.repairedFaultIDs.contains($0.id) }
        let activeIDs = Set(active.map(.id))

        for id in faultEmitters.keys where !activeIDs.contains(id) {
            faultEmitters.removeValue(forKey: id)?.removeFromParent()
        }

        for fault in active where fault.car < carNodes.count {
            if faultEmitters[fault.id] == nil {
                let emitter = makeSparkEmitter()
                emitter.position = CGPoint(x: 0, y: 35)
                carNodes[fault.car].addChild(emitter)
                faultEmitters[fault.id] = emitter
            }
        }
    }

    private func updateWeather(snapshot: RainlineSnapshot) {
        let rain = CGFloat(snapshot.rain)
        rainEmitter?.particleBirthRate = 260 + rain * 260
        stormOverlay.alpha = 0.04 + rain * 0.16
        glassRain.shader?.uniformNamed("u_rain")?.floatValue = Float(rain)
        glassRain.shader?.uniformNamed("u_power")?.floatValue = Float(snapshot.trainPower / 100)

        let period = 430
        let phase = Int(state.seed % UInt64(period))
        if snapshot.rain > 0.72 && state.tick % period == phase {
            lightningOverlay.removeAllActions()
            lightningOverlay.run(.sequence([
                .fadeAlpha(to: 0.56, duration: 0.02),
                .fadeAlpha(to: 0.05, duration: 0.055),
                .fadeAlpha(to: 0.31, duration: 0.03),
                .fadeOut(withDuration: 0.15)
            ]))
        }
    }

    private func wrap(layer: SKNode, width: CGFloat) {
        if layer.position.x <= -width {
            layer.position.x += width
        }
    }

    private func makeSparkEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = makeDotTexture(diameter: 5)
        emitter.particleBirthRate = 26
        emitter.particleLifetime = 0.42
        emitter.particleLifetimeRange = 0.16
        emitter.particleSpeed = 70
        emitter.particleSpeedRange = 45
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.92
        emitter.particleAlphaSpeed = -1.9
        emitter.particleColor = .systemOrange
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        return emitter
    }

    private func makeRainTexture() -> SKTexture {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 24)).image { context in
            context.cgContext.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
            context.cgContext.fill(CGRect(x: 1, y: 0, width: 1, height: 24))
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

    private func procedural(index: Int, salt: UInt64) -> Double {
        var z = UInt64(bitPattern: Int64(index)) &+ salt &* 0x9E3779B97F4A7C15
        z ^= z >> 30
        z &*= 0xBF58476D1CE4E5B9
        z ^= z >> 27
        z &*= 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z & 0xFFFF) / Double(0xFFFF)
    }

    private func blend(_ a: UIColor, _ b: UIColor, factor: CGFloat) -> UIColor {
        let f = min(1, max(0, factor))
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(
            red: ar + (br - ar) * f,
            green: ag + (bg - ag) * f,
            blue: ab + (bb - ab) * f,
            alpha: aa + (ba - aa) * f
        )
    }

    private func publishSnapshot() {
        onSnapshot?(state.snapshot())
    }

    private static let glassRainShader = """
    void main() {
        vec2 uv = v_tex_coord;
        float rain = u_rain;
        float power = u_power;

        float column = floor(uv.x * 23.0);
        float drift = sin(column * 12.9898) * 43758.5453;
        float phase = fract(drift) * 6.28318;
        float y = fract(uv.y + u_time * (0.09 + rain * 0.16) + sin(uv.x * 31.0 + phase) * 0.028);
        float drop = smoothstep(0.034, 0.0, abs(y - 0.78)) * smoothstep(0.55, 0.0, abs(fract(uv.x * 23.0) - 0.5));

        float streak = smoothstep(0.015, 0.0, abs(fract(uv.x * 37.0 + phase) - 0.52));
        streak *= smoothstep(0.95, 0.10, y);

        float alpha = (drop * 0.24 + streak * 0.08) * rain;
        vec3 cold = vec3(0.44, 0.63, 0.82);
        vec3 emergency = vec3(0.95, 0.22, 0.12);
        vec3 color = mix(emergency, cold, power);
        gl_FragColor = vec4(color, alpha);
    }
    """
}
