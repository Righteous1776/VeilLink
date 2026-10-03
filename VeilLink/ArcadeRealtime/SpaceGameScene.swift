import SpriteKit
import UIKit

@MainActor
protocol SpaceGameSceneOutput: AnyObject {
    func spaceScene(_ scene: SpaceGameScene, didRender snapshot: SpaceGameSnapshot)
}

@MainActor
final class SpaceGameScene: SKScene {
    private let configuration: SpaceGameConfiguration
    private var simulation: SpaceSimulation
    private var movement = SpaceVector.zero
    private var previousUpdateTime: TimeInterval?
    private var activeTouch: UITouch?
    private var touchOrigin = CGPoint.zero
    private var lastPublishedSecond = -1
    private var lastPublishedScore = -1
    private var lastPublishedHealth = -1
    private var lastPublishedWave = -1

    private let world = SKNode()
    private let effects = SKNode()
    private let playerNode = SKNode()
    private let joystickBase = SKShapeNode(circleOfRadius: 46)
    private let joystickKnob = SKShapeNode(circleOfRadius: 20)
    private var enemyNodes: [Int: SKNode] = [:]
    private var projectileNodes: [Int: SKNode] = [:]
    private var starNodes: [SKShapeNode] = []

    weak var output: SpaceGameSceneOutput?

    init(configuration: SpaceGameConfiguration = .standard, seed: UInt64 = 0x5645_494C_5350_4143) {
        self.configuration = configuration
        self.simulation = SpaceSimulation(configuration: configuration, seed: seed)
        super.init(size: CGSize(width: configuration.arenaWidth, height: configuration.arenaHeight))
        scaleMode = .aspectFill
        backgroundColor = UIColor(red: 0.012, green: 0.018, blue: 0.07, alpha: 1)
        anchorPoint = .zero
        isUserInteractionEnabled = true
        buildScene()
        render(simulation.snapshot, animated: false)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("SpaceGameScene does not support storyboard decoding")
    }

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        previousUpdateTime = nil
        publishSnapshot(force: true)
    }

    func setGamePaused(_ paused: Bool) {
        simulation.setPaused(paused)
        previousUpdateTime = nil
        movement = .zero
        publishSnapshot(force: true)
    }

    func restart(seed: UInt64 = 0x5645_494C_5350_4143) {
        simulation.restart(seed: seed)
        previousUpdateTime = nil
        movement = .zero
        enemyNodes.values.forEach { $0.removeFromParent() }
        projectileNodes.values.forEach { $0.removeFromParent() }
        enemyNodes.removeAll(keepingCapacity: true)
        projectileNodes.removeAll(keepingCapacity: true)
        effects.removeAllChildren()
        render(simulation.snapshot, animated: false)
        publishSnapshot(force: true)
    }

    override func update(_ currentTime: TimeInterval) {
        let delta: Double
        if let previousUpdateTime {
            delta = min(0.1, max(0, currentTime - previousUpdateTime))
        } else {
            delta = configuration.fixedTimeStep
        }
        previousUpdateTime = currentTime

        let events = simulation.advance(frameDelta: delta, input: SpaceInput(movement: movement))
        let snapshot = simulation.snapshot
        handle(events)
        render(snapshot, animated: true)
        animateWorld(at: currentTime, snapshot: snapshot)
        publishSnapshot(force: !events.isEmpty)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first, simulation.snapshot.phase == .playing else { return }
        activeTouch = touch
        touchOrigin = touch.location(in: self)
        joystickBase.position = touchOrigin
        joystickKnob.position = touchOrigin
        joystickBase.isHidden = false
        joystickKnob.isHidden = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        let location = activeTouch.location(in: self)
        let delta = CGPoint(x: location.x - touchOrigin.x, y: location.y - touchOrigin.y)
        let distance = hypot(delta.x, delta.y)
        let radius: CGFloat = 46
        let scale = distance > radius ? radius / distance : 1
        let limited = CGPoint(x: delta.x * scale, y: delta.y * scale)
        joystickKnob.position = CGPoint(x: touchOrigin.x + limited.x, y: touchOrigin.y + limited.y)
        movement = SpaceVector(x: Double(limited.x / radius), y: Double(limited.y / radius))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(ifContainedIn: touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch(ifContainedIn: touches)
    }

    private func finishTouch(ifContainedIn touches: Set<UITouch>) {
        guard let activeTouch, touches.contains(activeTouch) else { return }
        self.activeTouch = nil
        movement = .zero
        joystickBase.isHidden = true
        joystickKnob.isHidden = true
    }

    private func buildScene() {
        addChild(world)
        world.addChild(buildStarField())

        let vignette = SKShapeNode(rectOf: size, cornerRadius: 44)
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.strokeColor = UIColor.systemCyan.withAlphaComponent(0.18)
        vignette.lineWidth = 4
        vignette.glowWidth = 14
        vignette.fillColor = .clear
        vignette.zPosition = 2
        world.addChild(vignette)

        buildPlayer()
        playerNode.zPosition = 30
        world.addChild(playerNode)
        effects.zPosition = 80
        world.addChild(effects)

        joystickBase.fillColor = UIColor.black.withAlphaComponent(0.24)
        joystickBase.strokeColor = UIColor.white.withAlphaComponent(0.22)
        joystickBase.lineWidth = 2
        joystickBase.zPosition = 500
        joystickBase.isHidden = true
        addChild(joystickBase)

        joystickKnob.fillColor = UIColor.systemCyan.withAlphaComponent(0.42)
        joystickKnob.strokeColor = UIColor.white.withAlphaComponent(0.7)
        joystickKnob.glowWidth = 7
        joystickKnob.zPosition = 501
        joystickKnob.isHidden = true
        addChild(joystickKnob)
    }

    private func buildStarField() -> SKNode {
        let container = SKNode()
        container.zPosition = -100
        starNodes.removeAll(keepingCapacity: true)
        var state: UInt64 = 0xA57E_11A7
        func random() -> CGFloat {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return CGFloat(Double(state >> 11) / Double(1 << 53))
        }
        for index in 0..<150 {
            let radius = 0.7 + random() * 1.8
            let star = SKShapeNode(circleOfRadius: radius)
            star.fillColor = index.isMultiple(of: 9)
                ? UIColor.systemCyan.withAlphaComponent(0.72)
                : UIColor.white.withAlphaComponent(0.30 + random() * 0.45)
            star.strokeColor = .clear
            star.position = CGPoint(x: random() * size.width, y: random() * size.height)
            star.name = "star"
            star.userData = NSMutableDictionary(dictionary: [
                "depth": 0.15 + random() * 0.85,
                "baseX": star.position.x,
                "baseY": star.position.y
            ])
            container.addChild(star)
            starNodes.append(star)
        }
        return container
    }

    private func buildPlayer() {
        let hullPath = CGMutablePath()
        hullPath.move(to: CGPoint(x: 25, y: 0))
        hullPath.addLine(to: CGPoint(x: -18, y: 16))
        hullPath.addLine(to: CGPoint(x: -10, y: 0))
        hullPath.addLine(to: CGPoint(x: -18, y: -16))
        hullPath.closeSubpath()
        let hull = SKShapeNode(path: hullPath)
        hull.fillColor = UIColor(red: 0.10, green: 0.84, blue: 1, alpha: 1)
        hull.strokeColor = UIColor.white.withAlphaComponent(0.95)
        hull.lineWidth = 2
        hull.glowWidth = 8
        hull.name = "hull"
        playerNode.addChild(hull)

        let canopy = SKShapeNode(ellipseOf: CGSize(width: 17, height: 10))
        canopy.position = CGPoint(x: 5, y: 0)
        canopy.fillColor = UIColor(red: 0.04, green: 0.12, blue: 0.30, alpha: 1)
        canopy.strokeColor = UIColor.systemTeal
        canopy.lineWidth = 1.5
        playerNode.addChild(canopy)

        let engine = makeEmitter(
            color: UIColor.systemCyan,
            birthRate: 95,
            lifetime: 0.34,
            speed: 82,
            scale: 0.10,
            scaleRange: 0.06
        )
        engine.position = CGPoint(x: -18, y: 0)
        engine.emissionAngle = .pi
        engine.emissionAngleRange = 0.28
        engine.targetNode = world
        engine.name = "engine"
        playerNode.addChild(engine)
    }

    private func makeEnemyNode(_ enemy: SpaceEnemySnapshot) -> SKNode {
        let container = SKNode()
        let body: SKShapeNode
        switch enemy.kind {
        case .hunter:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 19, y: 0))
            path.addLine(to: CGPoint(x: -13, y: 15))
            path.addLine(to: CGPoint(x: -7, y: 0))
            path.addLine(to: CGPoint(x: -13, y: -15))
            path.closeSubpath()
            body = SKShapeNode(path: path)
            body.fillColor = UIColor(red: 0.94, green: 0.20, blue: 0.48, alpha: 1)
        case .charger:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 23, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 19))
            path.addLine(to: CGPoint(x: -21, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -19))
            path.closeSubpath()
            body = SKShapeNode(path: path)
            body.fillColor = UIColor(red: 1, green: 0.48, blue: 0.08, alpha: 1)
        case .gunship:
            body = SKShapeNode(rectOf: CGSize(width: 45, height: 39), cornerRadius: 10)
            body.fillColor = UIColor(red: 0.59, green: 0.22, blue: 0.96, alpha: 1)
            let core = SKShapeNode(circleOfRadius: 8)
            core.fillColor = UIColor.systemPink
            core.strokeColor = UIColor.white.withAlphaComponent(0.8)
            core.glowWidth = 7
            container.addChild(core)
        }
        body.strokeColor = UIColor.white.withAlphaComponent(0.78)
        body.lineWidth = 1.7
        body.glowWidth = 6
        body.name = "body"
        container.addChild(body)

        let healthBack = SKShapeNode(rectOf: CGSize(width: CGFloat(enemy.radius * 1.7), height: 4), cornerRadius: 2)
        healthBack.fillColor = UIColor.black.withAlphaComponent(0.55)
        healthBack.strokeColor = .clear
        healthBack.position = CGPoint(x: 0, y: CGFloat(enemy.radius + 10))
        healthBack.name = "healthBack"
        container.addChild(healthBack)
        let health = SKShapeNode(rectOf: CGSize(width: CGFloat(enemy.radius * 1.7), height: 3), cornerRadius: 1.5)
        health.fillColor = UIColor.systemMint
        health.strokeColor = .clear
        health.position = healthBack.position
        health.name = "health"
        health.xScale = CGFloat(enemy.healthFraction)
        container.addChild(health)
        container.zPosition = 20
        return container
    }

    private func makeProjectileNode(_ projectile: SpaceProjectileSnapshot) -> SKNode {
        let radius = CGFloat(projectile.radius)
        let node = SKShapeNode(ellipseOf: CGSize(width: radius * 3.2, height: radius * 1.4))
        let color: UIColor = projectile.owner == .player ? .systemCyan : .systemPink
        node.fillColor = color
        node.strokeColor = UIColor.white.withAlphaComponent(0.9)
        node.lineWidth = 1
        node.glowWidth = 9
        node.zPosition = 25
        return node
    }

    private func render(_ snapshot: SpaceGameSnapshot, animated: Bool) {
        playerNode.position = point(snapshot.player.position)
        if snapshot.player.velocity.lengthSquared > 10 {
            playerNode.zRotation = CGFloat(atan2(snapshot.player.velocity.y, snapshot.player.velocity.x))
        }
        let flicker = snapshot.player.invulnerabilityRemaining > 0 && Int(snapshot.elapsedTime * 20).isMultiple(of: 2)
        playerNode.alpha = flicker ? 0.35 : 1
        playerNode.childNode(withName: "engine")?.alpha = snapshot.player.velocity.length > 24 ? 1 : 0.38

        let liveEnemyIDs = Set(snapshot.enemies.map(\.id))
        for enemy in snapshot.enemies {
            let node: SKNode
            if let existing = enemyNodes[enemy.id] {
                node = existing
            } else {
                node = makeEnemyNode(enemy)
                enemyNodes[enemy.id] = node
                world.addChild(node)
                node.setScale(0.2)
                node.run(.scale(to: 1, duration: 0.18))
            }
            node.position = point(enemy.position)
            if enemy.velocity.lengthSquared > 1 {
                node.zRotation = CGFloat(atan2(enemy.velocity.y, enemy.velocity.x))
                node.childNode(withName: "healthBack")?.zRotation = -node.zRotation
                node.childNode(withName: "health")?.zRotation = -node.zRotation
            }
            if let health = node.childNode(withName: "health") {
                health.xScale = CGFloat(max(0.02, enemy.healthFraction))
            }
        }
        for id in Array(enemyNodes.keys) where !liveEnemyIDs.contains(id) {
            enemyNodes.removeValue(forKey: id)?.removeFromParent()
        }

        let liveProjectileIDs = Set(snapshot.projectiles.map(\.id))
        for projectile in snapshot.projectiles {
            let node: SKNode
            if let existing = projectileNodes[projectile.id] {
                node = existing
            } else {
                node = makeProjectileNode(projectile)
                projectileNodes[projectile.id] = node
                world.addChild(node)
            }
            node.position = point(projectile.position)
            node.zRotation = CGFloat(atan2(projectile.velocity.y, projectile.velocity.x))
        }
        for id in Array(projectileNodes.keys) where !liveProjectileIDs.contains(id) {
            projectileNodes.removeValue(forKey: id)?.removeFromParent()
        }
    }

    private func animateWorld(at time: TimeInterval, snapshot: SpaceGameSnapshot) {
        let parallaxX = CGFloat(snapshot.player.position.x / configuration.arenaWidth - 0.5)
        let parallaxY = CGFloat(snapshot.player.position.y / configuration.arenaHeight - 0.5)
        starNodes.forEach { star in
            let depth = CGFloat((star.userData?["depth"] as? NSNumber)?.doubleValue ?? 0.5)
            let baseX = CGFloat((star.userData?["baseX"] as? NSNumber)?.doubleValue ?? Double(star.position.x))
            let baseY = CGFloat((star.userData?["baseY"] as? NSNumber)?.doubleValue ?? Double(star.position.y))
            star.position.x = baseX + sin(CGFloat(time) * (0.32 + depth * 0.15)) * 2.5 - parallaxX * depth * 28
            star.position.y = baseY + cos(CGFloat(time) * (0.22 + depth * 0.12)) * 2 - parallaxY * depth * 22
            star.xScale = 0.92 + 0.16 * sin(CGFloat(time) * (1.3 + depth))
            star.yScale = star.xScale
            star.alpha = 0.68 + 0.30 * sin(CGFloat(time) * (1.1 + depth))
            star.position.x -= parallaxX * depth * 0.018
            star.position.y -= parallaxY * depth * 0.018
        }
    }

    private func handle(_ events: [SpaceGameEvent]) {
        for event in events {
            switch event {
            case let .playerFired(position):
                addBurst(at: position, color: .systemCyan, count: 6, speed: 68)
            case let .enemyFired(position):
                addBurst(at: position, color: .systemPink, count: 5, speed: 55)
            case let .impact(position, hostile):
                addBurst(at: position, color: hostile ? .systemPink : .white, count: 10, speed: 105)
            case let .enemyDestroyed(position, kind):
                let color: UIColor
                switch kind {
                case .hunter: color = .systemPink
                case .charger: color = .systemOrange
                case .gunship: color = .systemPurple
                }
                addBurst(at: position, color: color, count: 32, speed: 205)
                pulse(at: position, color: color)
            case let .playerDamaged(position):
                addBurst(at: position, color: .systemRed, count: 26, speed: 170)
                shakeWorld()
            case .waveStarted:
                pulse(at: simulation.snapshot.player.position, color: .systemCyan)
            case .gameOver:
                addBurst(at: simulation.snapshot.player.position, color: .systemCyan, count: 48, speed: 230)
                shakeWorld()
            }
        }
    }

    private func addBurst(at position: SpaceVector, color: UIColor, count: Int, speed: CGFloat) {
        let emitter = makeEmitter(
            color: color,
            birthRate: CGFloat(count) * 70,
            lifetime: 0.42,
            speed: speed,
            scale: 0.09,
            scaleRange: 0.07
        )
        emitter.position = point(position)
        emitter.emissionAngleRange = .pi * 2
        emitter.numParticlesToEmit = count
        emitter.targetNode = world
        effects.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.9), .removeFromParent()]))
    }

    private func makeEmitter(
        color: UIColor,
        birthRate: CGFloat,
        lifetime: CGFloat,
        speed: CGFloat,
        scale: CGFloat,
        scaleRange: CGFloat
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Self.particleTexture
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBirthRate = birthRate
        emitter.particleLifetime = lifetime
        emitter.particleLifetimeRange = lifetime * 0.25
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.45
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = scale
        emitter.particleScaleRange = scaleRange
        emitter.particleScaleSpeed = -0.08
        return emitter
    }

    private func pulse(at position: SpaceVector, color: UIColor) {
        let ring = SKShapeNode(circleOfRadius: 12)
        ring.position = point(position)
        ring.fillColor = .clear
        ring.strokeColor = color
        ring.lineWidth = 5
        ring.glowWidth = 12
        effects.addChild(ring)
        ring.run(.group([
            .scale(to: 6.2, duration: 0.38),
            .sequence([.fadeOut(withDuration: 0.38), .removeFromParent()])
        ]))
    }

    private func shakeWorld() {
        let sequence = SKAction.sequence([
            .moveBy(x: -8, y: 5, duration: 0.025),
            .moveBy(x: 14, y: -9, duration: 0.035),
            .moveBy(x: -9, y: 7, duration: 0.035),
            .moveBy(x: 3, y: -3, duration: 0.03)
        ])
        world.run(sequence, withKey: "impactShake")
    }

    private func publishSnapshot(force: Bool) {
        let snapshot = simulation.snapshot
        let second = Int(snapshot.elapsedTime)
        let health = Int(snapshot.player.health.rounded())
        guard force || second != lastPublishedSecond || snapshot.score != lastPublishedScore ||
                health != lastPublishedHealth || snapshot.wave != lastPublishedWave else { return }
        lastPublishedSecond = second
        lastPublishedScore = snapshot.score
        lastPublishedHealth = health
        lastPublishedWave = snapshot.wave
        output?.spaceScene(self, didRender: snapshot)
    }

    private func point(_ vector: SpaceVector) -> CGPoint {
        CGPoint(x: vector.x, y: vector.y)
    }

    private static let particleTexture: SKTexture = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image = renderer.image { context in
            let cg = context.cgContext
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            cg.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 10, y: 10),
                startRadius: 0,
                endCenter: CGPoint(x: 10, y: 10),
                endRadius: 10,
                options: []
            )
        }
        return SKTexture(image: image)
    }()
}
