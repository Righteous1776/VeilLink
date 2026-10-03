import SpriteKit
import UIKit

@MainActor
final class PlatformerScene: SKScene, SKPhysicsContactDelegate {
    private enum PhysicsCategory {
        static let player: UInt32 = 1 << 0
        static let terrain: UInt32 = 1 << 1
        static let hazard: UInt32 = 1 << 2
        static let crystal: UInt32 = 1 << 3
        static let exit: UInt32 = 1 << 4
        static let spring: UInt32 = 1 << 5
    }

    private weak var session: PlatformerGameSession?
    private var level: PlatformerLevel?
    private let worldCamera = SKCameraNode()
    private let player = SKNode()
    private let playerBody = SKShapeNode(rectOf: CGSize(width: 52, height: 67), cornerRadius: 19)
    private let visor = SKShapeNode(rectOf: CGSize(width: 35, height: 17), cornerRadius: 8)
    private let leftLeg = SKShapeNode(rectOf: CGSize(width: 12, height: 27), cornerRadius: 6)
    private let rightLeg = SKShapeNode(rectOf: CGSize(width: 12, height: 27), cornerRadius: 6)
    private let playerGlow = SKShapeNode(circleOfRadius: 40)
    private let dashTrail = SKEmitterNode()
    private var exitNode: SKNode?

    private var horizontalInput: CGFloat = 0
    private var jumpBuffered: TimeInterval = 0
    private var jumpHeld = false
    private var dashRequested = false
    private var dashCooldown: TimeInterval = 0
    private var coyoteTime: TimeInterval = 0
    private var groundContacts: Set<ObjectIdentifier> = []
    private var invulnerability: TimeInterval = 0
    private var elapsed: TimeInterval = 0
    private var lastPublishedTenth = -1
    private var lastUpdateTime: TimeInterval = 0
    private var facing: CGFloat = 1
    private var completed = false

    init(session: PlatformerGameSession) {
        self.session = session
        super.init(size: CGSize(width: 1_280, height: 720))
        scaleMode = .aspectFill
        backgroundColor = UIColor(red: 0.025, green: 0.035, blue: 0.09, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -1_650)
        physicsWorld.contactDelegate = self
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("PlatformerScene must be created with a game session")
    }

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = ArcadeRenderPolicy.preferredFramesPerSecond
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
    }

    func start(level: PlatformerLevel) {
        removeAllActions()
        removeAllChildren()
        self.level = level
        completed = false
        horizontalInput = 0
        jumpBuffered = 0
        jumpHeld = false
        dashRequested = false
        dashCooldown = 0
        coyoteTime = 0
        groundContacts.removeAll()
        invulnerability = 0
        elapsed = 0
        lastPublishedTenth = -1
        lastUpdateTime = 0
        physicsWorld.gravity = CGVector(dx: 0, dy: -1_650)
        physicsWorld.contactDelegate = self
        isPaused = false

        buildCameraEnvironment()
        buildLevel(level)
        buildPlayer(at: level.spawn)
        worldCamera.position = cameraTarget(for: level.spawn, level: level)
        camera = worldCamera
    }

    func setHorizontalInput(_ direction: CGFloat) {
        horizontalInput = min(1, max(-1, direction))
        if abs(horizontalInput) > 0.05 { facing = horizontalInput > 0 ? 1 : -1 }
    }

    func requestJump() {
        jumpBuffered = 0.16
        jumpHeld = true
    }

    func releaseJump() {
        jumpHeld = false
        guard let body = player.physicsBody, body.velocity.dy > 130 else { return }
        body.velocity.dy *= 0.48
    }

    func requestDash() {
        dashRequested = true
    }

    func finishLevel() {
        completed = true
        setHorizontalInput(0)
        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        burst(at: player.position, color: .cyan, count: 42, speed: 310)
        run(.sequence([.wait(forDuration: 1.05), .run { [weak self] in
            self?.session?.advanceToNextLevel()
        }]))
    }

    func celebrateCampaign() {
        completed = true
        setHorizontalInput(0)
        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        let colors: [UIColor] = [.cyan, .systemPink, .systemYellow, .systemMint]
        for (index, color) in colors.enumerated() {
            run(.sequence([
                .wait(forDuration: Double(index) * 0.18),
                .run { [weak self] in
                    guard let self else { return }
                    self.burst(
                        at: CGPoint(x: self.player.position.x + CGFloat(index - 2) * 90, y: self.player.position.y + 90),
                        color: color,
                        count: 55,
                        speed: 380
                    )
                }
            ]))
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard let session, session.phase == .playing, !completed, let level,
              let body = player.physicsBody else { return }

        let rawDelta = lastUpdateTime == 0 ? 1.0 / 60.0 : currentTime - lastUpdateTime
        let delta = min(1.0 / 20.0, max(1.0 / 240.0, rawDelta))
        lastUpdateTime = currentTime
        elapsed += delta
        jumpBuffered = max(0, jumpBuffered - delta)
        coyoteTime = groundContacts.isEmpty ? max(0, coyoteTime - delta) : 0.13
        invulnerability = max(0, invulnerability - delta)
        dashCooldown = max(0, dashCooldown - delta)

        let targetSpeed = horizontalInput * 350
        let acceleration: CGFloat = groundContacts.isEmpty ? 1_450 : 2_300
        let maximumChange = acceleration * CGFloat(delta)
        let speedDelta = min(maximumChange, max(-maximumChange, targetSpeed - body.velocity.dx))
        body.velocity.dx += speedDelta

        if jumpBuffered > 0, coyoteTime > 0 {
            body.velocity.dy = 610
            jumpBuffered = 0
            coyoteTime = 0
            groundContacts.removeAll()
            burst(at: CGPoint(x: player.position.x, y: player.position.y - 35), color: .systemMint, count: 10, speed: 105)
        }

        if dashRequested, dashCooldown <= 0 {
            dashRequested = false
            dashCooldown = 0.9
            body.velocity.dx = facing * 760
            body.velocity.dy = max(55, body.velocity.dy * 0.35)
            dashTrail.particleBirthRate = 240
            run(.sequence([.wait(forDuration: 0.16), .run { [weak self] in
                self?.dashTrail.particleBirthRate = 28
            }]))
            burst(at: player.position, color: .systemPink, count: 18, speed: 245)
        } else {
            dashRequested = false
        }

        if !jumpHeld, body.velocity.dy > 130 { body.velocity.dy *= 0.985 }
        body.velocity.dy = max(-940, body.velocity.dy)
        session.setDashReady(dashCooldown <= 0)

        animatePlayer(delta: delta, velocity: body.velocity)
        updateCamera(delta: delta, level: level)

        let tenth = Int(elapsed * 10)
        if tenth != lastPublishedTenth {
            lastPublishedTenth = tenth
            session.setElapsedTime(elapsed)
        }

        if player.position.y < -160 { hitHazard() }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        handleContact(contact, began: true)
    }

    func didEnd(_ contact: SKPhysicsContact) {
        handleContact(contact, began: false)
    }

    private func handleContact(_ contact: SKPhysicsContact, began: Bool) {
        let bodyA = contact.bodyA
        let bodyB = contact.bodyB
        let playerBody: SKPhysicsBody
        let otherBody: SKPhysicsBody
        if bodyA.categoryBitMask == PhysicsCategory.player {
            playerBody = bodyA
            otherBody = bodyB
        } else if bodyB.categoryBitMask == PhysicsCategory.player {
            playerBody = bodyB
            otherBody = bodyA
        } else {
            return
        }
        _ = playerBody

        switch otherBody.categoryBitMask {
        case PhysicsCategory.terrain:
            let identifier = ObjectIdentifier(otherBody)
            if began {
                let surfaceY = otherBody.node?.calculateAccumulatedFrame().maxY ?? -.greatestFiniteMagnitude
                if player.position.y - 35 >= surfaceY - 18 {
                    groundContacts.insert(identifier)
                }
            } else {
                groundContacts.remove(identifier)
            }
        case PhysicsCategory.crystal where began:
            collectCrystal(otherBody.node)
        case PhysicsCategory.hazard where began:
            hitHazard()
        case PhysicsCategory.spring where began:
            if let body = player.physicsBody {
                body.velocity.dy = 875
                coyoteTime = 0
                burst(at: CGPoint(x: player.position.x, y: player.position.y - 35), color: .systemYellow, count: 20, speed: 210)
            }
        case PhysicsCategory.exit where began:
            if let session {
                if session.collectedCrystals >= session.requiredCrystals {
                    session.completeLevel()
                } else {
                    session.reachLockedExit()
                    exitNode?.run(.sequence([
                        .scale(to: 1.15, duration: 0.08),
                        .scale(to: 1.0, duration: 0.14)
                    ]))
                }
            }
        default:
            break
        }
    }

    private func buildCameraEnvironment() {
        worldCamera.removeAllChildren()
        worldCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        worldCamera.zPosition = 1_000
        addChild(worldCamera)

        let backdrop = SKSpriteNode(
            color: UIColor(red: 0.025, green: 0.035, blue: 0.09, alpha: 1),
            size: CGSize(width: 1_700, height: 1_100)
        )
        backdrop.zPosition = -1_200
        worldCamera.addChild(backdrop)

        for index in 0..<26 {
            let radius = CGFloat(1 + (index * 7) % 4)
            let star = SKShapeNode(circleOfRadius: radius)
            star.fillColor = index % 4 == 0 ? .systemTeal : UIColor.white.withAlphaComponent(0.72)
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat((index * 173) % 1_500) - 750,
                y: CGFloat((index * 97) % 860) - 360
            )
            star.alpha = 0.38 + CGFloat(index % 5) * 0.1
            star.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.2, duration: 0.8 + Double(index % 4) * 0.25),
                .fadeAlpha(to: 0.9, duration: 0.9 + Double(index % 3) * 0.3)
            ])))
            star.zPosition = -1_190
            worldCamera.addChild(star)
        }

        for index in 0..<5 {
            let band = SKShapeNode(rectOf: CGSize(width: 1_600, height: CGFloat(95 + index * 34)), cornerRadius: 55)
            band.fillColor = UIColor(
                red: 0.12 + CGFloat(index) * 0.015,
                green: 0.08 + CGFloat(index) * 0.02,
                blue: 0.32 + CGFloat(index) * 0.035,
                alpha: 0.12
            )
            band.strokeColor = .clear
            band.position = CGPoint(x: 0, y: -345 + CGFloat(index * 36))
            band.zRotation = CGFloat(index - 2) * 0.025
            band.zPosition = -1_180 + CGFloat(index)
            worldCamera.addChild(band)
        }
    }

    private func buildLevel(_ level: PlatformerLevel) {
        for (index, platform) in level.platforms.enumerated() {
            let node = SKSpriteNode(color: platformColor(platform.style), size: platform.frame.size)
            node.position = CGPoint(x: platform.frame.midX, y: platform.frame.midY)
            node.name = "platform-\(index)"
            node.zPosition = 1
            node.physicsBody = SKPhysicsBody(rectangleOf: platform.frame.size)
            node.physicsBody?.isDynamic = false
            node.physicsBody?.categoryBitMask = PhysicsCategory.terrain
            node.physicsBody?.collisionBitMask = PhysicsCategory.player
            node.physicsBody?.contactTestBitMask = PhysicsCategory.player
            node.physicsBody?.friction = 0.15
            addChild(node)

            let rim = SKSpriteNode(color: platformRimColor(platform.style), size: CGSize(width: platform.frame.width, height: 6))
            rim.position = CGPoint(x: 0, y: platform.frame.height / 2 - 3)
            rim.zPosition = 2
            node.addChild(rim)

            let shadow = SKSpriteNode(color: UIColor.black.withAlphaComponent(0.25), size: CGSize(width: platform.frame.width - 10, height: 7))
            shadow.position = CGPoint(x: 0, y: -platform.frame.height / 2 + 7)
            node.addChild(shadow)
        }

        for hazard in level.hazards { buildHazard(hazard) }
        for (index, crystal) in level.crystals.enumerated() { buildCrystal(at: crystal, index: index) }
        for spring in level.springs { buildSpring(at: spring) }
        for (index, patrol) in level.patrols.enumerated() { buildPatrol(patrol, index: index) }
        buildExit(at: level.exit)
    }

    private func buildPlayer(at position: CGPoint) {
        player.removeAllActions()
        player.removeAllChildren()
        player.position = position
        player.zPosition = 30
        player.name = "pulse-runner"

        playerGlow.fillColor = UIColor.systemCyan.withAlphaComponent(0.15)
        playerGlow.strokeColor = UIColor.systemCyan.withAlphaComponent(0.28)
        playerGlow.lineWidth = 2
        playerGlow.zPosition = -2
        player.addChild(playerGlow)

        playerBody.fillColor = UIColor(red: 0.18, green: 0.87, blue: 0.9, alpha: 1)
        playerBody.strokeColor = UIColor.white.withAlphaComponent(0.86)
        playerBody.lineWidth = 3
        playerBody.zPosition = 2
        player.addChild(playerBody)

        visor.fillColor = UIColor(red: 0.045, green: 0.07, blue: 0.18, alpha: 1)
        visor.strokeColor = UIColor.systemPink.withAlphaComponent(0.85)
        visor.lineWidth = 2
        visor.position = CGPoint(x: 7, y: 9)
        visor.zPosition = 3
        player.addChild(visor)

        for leg in [leftLeg, rightLeg] {
            leg.fillColor = UIColor(red: 0.13, green: 0.67, blue: 0.82, alpha: 1)
            leg.strokeColor = UIColor.white.withAlphaComponent(0.6)
            leg.lineWidth = 2
            leg.position.y = -38
            leg.zPosition = 1
            player.addChild(leg)
        }
        leftLeg.position.x = -13
        rightLeg.position.x = 13

        configureDashTrail()
        player.addChild(dashTrail)

        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 49, height: 85), center: CGPoint(x: 0, y: -5))
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.restitution = 0
        player.physicsBody?.friction = 0.05
        player.physicsBody?.linearDamping = 0.05
        player.physicsBody?.mass = 0.8
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.collisionBitMask = PhysicsCategory.terrain
        player.physicsBody?.contactTestBitMask = PhysicsCategory.terrain
            | PhysicsCategory.hazard | PhysicsCategory.crystal
            | PhysicsCategory.exit | PhysicsCategory.spring
        addChild(player)
    }

    private func buildHazard(_ hazard: PlatformerLevel.Hazard) {
        let root = SKNode()
        root.position = CGPoint(x: hazard.frame.midX, y: hazard.frame.midY)
        root.zPosition = 4
        root.name = "ion-spikes"
        let count = max(1, Int(hazard.frame.width / 24))
        let segmentWidth = hazard.frame.width / CGFloat(count)
        for index in 0..<count {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -segmentWidth / 2, y: -hazard.frame.height / 2))
            path.addLine(to: CGPoint(x: 0, y: hazard.frame.height / 2))
            path.addLine(to: CGPoint(x: segmentWidth / 2, y: -hazard.frame.height / 2))
            path.closeSubpath()
            let spike = SKShapeNode(path: path)
            spike.fillColor = .systemPink
            spike.strokeColor = UIColor.white.withAlphaComponent(0.65)
            spike.lineWidth = 1.5
            spike.position.x = -hazard.frame.width / 2 + segmentWidth * (CGFloat(index) + 0.5)
            root.addChild(spike)
        }
        root.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: hazard.frame.width - 8, height: hazard.frame.height * 0.72))
        root.physicsBody?.isDynamic = false
        root.physicsBody?.categoryBitMask = PhysicsCategory.hazard
        root.physicsBody?.collisionBitMask = 0
        root.physicsBody?.contactTestBitMask = PhysicsCategory.player
        addChild(root)
    }

    private func buildCrystal(at position: CGPoint, index: Int) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 27))
        path.addLine(to: CGPoint(x: 18, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -27))
        path.addLine(to: CGPoint(x: -18, y: 0))
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.position = position
        node.fillColor = index.isMultiple(of: 2) ? .systemCyan : .systemMint
        node.strokeColor = .white
        node.lineWidth = 3
        node.glowWidth = 9
        node.zPosition = 12
        node.name = "star-core"
        node.physicsBody = SKPhysicsBody(circleOfRadius: 27)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.crystal
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player
        node.run(.repeatForever(.group([
            .rotate(byAngle: .pi * 2, duration: 2.6 + Double(index % 3) * 0.25),
            .sequence([.scale(to: 1.13, duration: 0.55), .scale(to: 0.9, duration: 0.55)])
        ])))
        addChild(node)
    }

    private func buildSpring(at position: CGPoint) {
        let root = SKNode()
        root.position = position
        root.zPosition = 6
        root.name = "pulse-spring"
        let base = SKShapeNode(rectOf: CGSize(width: 72, height: 24), cornerRadius: 8)
        base.fillColor = .systemYellow
        base.strokeColor = .white
        base.lineWidth = 2
        root.addChild(base)
        let core = SKShapeNode(rectOf: CGSize(width: 45, height: 7), cornerRadius: 3)
        core.fillColor = .white
        core.strokeColor = .clear
        core.position.y = 8
        root.addChild(core)
        root.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 70, height: 28))
        root.physicsBody?.isDynamic = false
        root.physicsBody?.categoryBitMask = PhysicsCategory.spring
        root.physicsBody?.collisionBitMask = 0
        root.physicsBody?.contactTestBitMask = PhysicsCategory.player
        root.run(.repeatForever(.sequence([
            .scaleY(to: 0.78, duration: 0.45), .scaleY(to: 1.0, duration: 0.45)
        ])))
        addChild(root)
    }

    private func buildPatrol(_ patrol: PlatformerLevel.Patrol, index: Int) {
        let node = SKShapeNode(circleOfRadius: 27)
        node.position = patrol.origin
        node.zPosition = 14
        node.name = "prism-drone-\(index)"
        node.fillColor = UIColor(red: 0.55, green: 0.16, blue: 0.8, alpha: 1)
        node.strokeColor = .systemPink
        node.lineWidth = 4
        node.glowWidth = 6
        let eye = SKShapeNode(rectOf: CGSize(width: 26, height: 8), cornerRadius: 4)
        eye.fillColor = .white
        eye.strokeColor = .clear
        node.addChild(eye)
        node.physicsBody = SKPhysicsBody(circleOfRadius: 29)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.categoryBitMask = PhysicsCategory.hazard
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player
        let left = SKAction.moveTo(x: patrol.origin.x - patrol.travel, duration: patrol.duration)
        let right = SKAction.moveTo(x: patrol.origin.x + patrol.travel, duration: patrol.duration * 2)
        let center = SKAction.moveTo(x: patrol.origin.x, duration: patrol.duration)
        node.run(.repeatForever(.sequence([left, right, center])))
        addChild(node)
    }

    private func buildExit(at position: CGPoint) {
        let root = SKNode()
        root.position = position
        root.zPosition = 10
        root.name = "aurora-gate"
        for index in 0..<3 {
            let ring = SKShapeNode(ellipseOf: CGSize(width: 72 + index * 16, height: 120 + index * 22))
            ring.strokeColor = index == 1 ? .systemPink : .systemCyan
            ring.fillColor = .clear
            ring.lineWidth = 5 - CGFloat(index)
            ring.alpha = 0.9 - CGFloat(index) * 0.18
            ring.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.25, duration: 0.6 + Double(index) * 0.15),
                .fadeAlpha(to: 0.9, duration: 0.65 + Double(index) * 0.12)
            ])))
            root.addChild(ring)
        }
        let core = SKShapeNode(ellipseOf: CGSize(width: 50, height: 96))
        core.fillColor = UIColor.systemCyan.withAlphaComponent(0.18)
        core.strokeColor = .clear
        root.addChild(core)
        root.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 86, height: 128))
        root.physicsBody?.isDynamic = false
        root.physicsBody?.categoryBitMask = PhysicsCategory.exit
        root.physicsBody?.collisionBitMask = 0
        root.physicsBody?.contactTestBitMask = PhysicsCategory.player
        addChild(root)
        exitNode = root
    }

    private func configureDashTrail() {
        dashTrail.targetNode = self
        dashTrail.particleTexture = Self.sparkTexture
        dashTrail.particleBirthRate = 28
        dashTrail.particleLifetime = 0.32
        dashTrail.particleLifetimeRange = 0.12
        dashTrail.particlePositionRange = CGVector(dx: 18, dy: 45)
        dashTrail.particleSpeed = 42
        dashTrail.particleSpeedRange = 28
        dashTrail.emissionAngleRange = .pi * 2
        dashTrail.particleAlpha = 0.75
        dashTrail.particleAlphaSpeed = -2.4
        dashTrail.particleScale = 0.55
        dashTrail.particleScaleRange = 0.3
        dashTrail.particleScaleSpeed = -0.9
        dashTrail.particleColor = .systemCyan
        dashTrail.particleColorBlendFactor = 1
        dashTrail.zPosition = -1
    }

    private func collectCrystal(_ node: SKNode?) {
        guard let node, node.parent != nil else { return }
        node.physicsBody = nil
        session?.collectCrystal()
        burst(at: node.position, color: node.name == "star-core" ? .systemCyan : .white, count: 24, speed: 220)
        node.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.16), .fadeOut(withDuration: 0.16)]),
            .removeFromParent()
        ]))
    }

    private func hitHazard() {
        guard invulnerability <= 0, let session, session.phase == .playing, let level else { return }
        invulnerability = 1.25
        session.registerHazardHit()
        burst(at: player.position, color: .systemPink, count: 30, speed: 275)
        if session.phase == .gameOver {
            player.physicsBody?.velocity = .zero
            player.physicsBody?.isDynamic = false
            completed = true
            return
        }
        player.position = level.spawn
        player.physicsBody?.velocity = .zero
        groundContacts.removeAll()
        let blink = SKAction.sequence([.fadeAlpha(to: 0.2, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08)])
        player.run(.repeat(blink, count: 5))
    }

    private func animatePlayer(delta: TimeInterval, velocity: CGVector) {
        let moving = min(1, abs(velocity.dx) / 260)
        let stride = sin(elapsed * (7 + Double(moving) * 10)) * Double(moving)
        leftLeg.zRotation = CGFloat(stride) * 0.48
        rightLeg.zRotation = CGFloat(-stride) * 0.48
        playerBody.position.y = CGFloat(abs(stride)) * 2
        visor.xScale = facing
        visor.position.x = facing * 7
        playerGlow.setScale(1 + 0.07 * CGFloat(sin(elapsed * 5)))
        let tilt = max(-0.16, min(0.16, velocity.dx / 2_200))
        player.zRotation += (tilt - player.zRotation) * min(1, CGFloat(delta) * 10)
    }

    private func updateCamera(delta: TimeInterval, level: PlatformerLevel) {
        let target = cameraTarget(
            for: CGPoint(x: player.position.x + facing * 115, y: player.position.y + 35),
            level: level
        )
        let response = 1 - CGFloat(exp(-7.5 * delta))
        worldCamera.position.x += (target.x - worldCamera.position.x) * response
        worldCamera.position.y += (target.y - worldCamera.position.y) * response
    }

    private func cameraTarget(for position: CGPoint, level: PlatformerLevel) -> CGPoint {
        CGPoint(
            x: min(level.worldSize.width - size.width / 2, max(size.width / 2, position.x)),
            y: min(level.worldSize.height - size.height / 2, max(size.height / 2, position.y))
        )
    }

    private func burst(at position: CGPoint, color: UIColor, count: Int, speed: CGFloat) {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 100
        emitter.particleTexture = Self.sparkTexture
        emitter.particleBirthRate = CGFloat(count) * 18
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = 0.65
        emitter.particleLifetimeRange = 0.22
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.45
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.95
        emitter.particleAlphaSpeed = -1.4
        emitter.particleScale = 0.75
        emitter.particleScaleRange = 0.35
        emitter.particleScaleSpeed = -0.8
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.yAcceleration = -260
        addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    private func platformColor(_ style: PlatformerLevel.Platform.Style) -> UIColor {
        switch style {
        case .ground: return UIColor(red: 0.075, green: 0.11, blue: 0.2, alpha: 1)
        case .floating: return UIColor(red: 0.105, green: 0.12, blue: 0.26, alpha: 1)
        case .glass: return UIColor(red: 0.08, green: 0.24, blue: 0.31, alpha: 0.92)
        }
    }

    private func platformRimColor(_ style: PlatformerLevel.Platform.Style) -> UIColor {
        switch style {
        case .ground: return .systemIndigo
        case .floating: return .systemPink
        case .glass: return .systemCyan
        }
    }

    private static let sparkTexture: SKTexture = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 1, y: 1, width: 10, height: 10))
        }
        return SKTexture(image: image)
    }()
}
