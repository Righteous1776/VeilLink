import SpriteKit
import UIKit

@MainActor
final class RhythmNeonScene: SKScene {
    private enum Z {
        static let background: CGFloat = -20
        static let grid: CGFloat = -10
        static let beats: CGFloat = 10
        static let player: CGFloat = 20
        static let hud: CGFloat = 30
        static let overlay: CGFloat = 50
    }

    private let seed: UInt64
    private var engine: RhythmRunEngine
    private var lastUpdateTime: TimeInterval = 0
    private var targetPlayerX: CGFloat = 0
    private var fallingBeats: [RhythmFallingBeatNode] = []
    private var stars: [SKShapeNode] = []

    private let worldNode = SKNode()
    private let gridNode = SKNode()
    private let beatNode = SKNode()
    private let effectsNode = SKNode()
    private let playerNode = SKNode()
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let shieldLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let chargeTrack = SKShapeNode()
    private let chargeFill = SKShapeNode()
    private let overdriveButton = SKShapeNode()
    private let overdriveLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let messageNode = SKNode()
    private let messageTitle = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let messageSubtitle = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var playerTrail: SKEmitterNode?

    private let cyan = UIColor(red: 0.18, green: 0.95, blue: 1.0, alpha: 1)
    private let magenta = UIColor(red: 1.0, green: 0.18, blue: 0.72, alpha: 1)
    private let violet = UIColor(red: 0.46, green: 0.25, blue: 1.0, alpha: 1)
    private let amber = UIColor(red: 1.0, green: 0.77, blue: 0.20, alpha: 1)
    private var pausedByLifecycle = false

    init(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000)) {
        self.seed = seed
        engine = RhythmRunEngine(seed: seed)
        super.init(size: CGSize(width: 390, height: 720))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.015, green: 0.018, blue: 0.055, alpha: 1)
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        guard worldNode.parent == nil else { return }
        view.isMultipleTouchEnabled = true
        view.ignoresSiblingOrder = true
        addChild(worldNode)
        worldNode.addChild(gridNode)
        worldNode.addChild(beatNode)
        worldNode.addChild(effectsNode)
        configureBackground()
        configurePlayer()
        configureHUD()
        configureMessage()
        layoutScene()
        showReadyMessage()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        if engine.state.phase == .running {
            pausedByLifecycle = true
            setGamePaused(true)
        }
    }

    func resumeAfterLifecyclePause() {
        guard pausedByLifecycle else { return }
        pausedByLifecycle = false
        setGamePaused(false)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard worldNode.parent != nil else { return }
        configureBackground()
        layoutScene()
    }

    override func update(_ currentTime: TimeInterval) {
        let delta: TimeInterval
        if lastUpdateTime == 0 {
            delta = 0
        } else {
            delta = min(max(currentTime - lastUpdateTime, 0), 0.12)
        }
        lastUpdateTime = currentTime

        updateAmbientMotion(delta: delta, time: currentTime)
        guard engine.state.phase == .running else { return }

        let step = engine.advance(deltaTime: delta)
        if step.didCrossBeat { animateBeatPulse() }
        for event in step.spawnedEvents { spawn(event) }
        updatePlayer(delta: delta)
        updateFallingBeats()
        updateHUD()

        if step.didAdvanceLevel {
            beginNextLevel()
        } else if step.didFinish || engine.state.phase == .finished {
            finishRun()
        }
    }

    func restartGame() {
        engine.restart()
        clearFallingBeats()
        effectsNode.removeAllChildren()
        playerNode.alpha = 1
        playerNode.setScale(1)
        engine.start()
        hideMessage()
        showTransientMessage("LEVEL 1", subtitle: "跟随节拍 · 滑动闪避")
        updateHUD()
    }

    func setGamePaused(_ paused: Bool) {
        if paused {
            engine.pause()
        } else if engine.state.phase == .paused {
            engine.start()
            lastUpdateTime = 0
        }
    }

    @discardableResult
    func toggleGamePaused() -> Bool {
        switch engine.state.phase {
        case .running:
            setGamePaused(true)
        case .paused:
            setGamePaused(false)
        case .ready, .finished:
            break
        }
        return engine.state.phase == .paused
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        switch engine.state.phase {
        case .ready:
            engine.start()
            hideMessage()
            showTransientMessage("LEVEL 1", subtitle: "滑动飞梭，避开障碍")
        case .finished:
            restartGame()
        case .paused:
            return
        case .running:
            if overdriveButton.contains(location) || touch.tapCount >= 2 {
                triggerOverdrive()
            }
        }
        updateTarget(with: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        updateTarget(with: touch.location(in: self))
    }

    private var laneWidth: CGFloat {
        max(52, (size.width - 32) / CGFloat(RhythmLevelConfiguration.laneCount))
    }

    private var playfieldLeft: CGFloat {
        (size.width - laneWidth * CGFloat(RhythmLevelConfiguration.laneCount)) / 2
    }

    private var playerY: CGFloat { max(112, size.height * 0.18) }

    private func laneX(_ lane: Int) -> CGFloat {
        playfieldLeft + (CGFloat(lane) + 0.5) * laneWidth
    }

    private func configureBackground() {
        gridNode.removeAllChildren()
        stars.removeAll()
        gridNode.zPosition = Z.grid

        let backdrop = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        backdrop.fillColor = backgroundColor
        backdrop.strokeColor = .clear
        backdrop.zPosition = Z.background
        gridNode.addChild(backdrop)

        for lane in 0...RhythmLevelConfiguration.laneCount {
            let x = playfieldLeft + CGFloat(lane) * laneWidth
            let line = SKShapeNode(rectOf: CGSize(width: 1, height: size.height))
            line.position = CGPoint(x: x, y: size.height / 2)
            line.fillColor = UIColor(red: 0, green: 0.9, blue: 0.9, alpha: 0.08)
            line.strokeColor = UIColor(red: 0, green: 1, blue: 1, alpha: 0.11)
            gridNode.addChild(line)
        }

        for row in 0..<9 {
            let width = size.width * (0.22 + CGFloat(row) * 0.11)
            let y = playerY + CGFloat(row) * max(42, (size.height - playerY) / 8)
            let line = SKShapeNode(rectOf: CGSize(width: width, height: 1))
            line.position = CGPoint(x: size.width / 2, y: y)
            line.strokeColor = UIColor(red: 0, green: 0.9, blue: 0.9, alpha: 0.1)
            gridNode.addChild(line)
        }

        let starCount = min(72, max(30, Int(size.width * size.height / 5_500)))
        for index in 0..<starCount {
            let radius = CGFloat((index * 17) % 3 + 1) * 0.55
            let star = SKShapeNode(circleOfRadius: radius)
            star.fillColor = index.isMultiple(of: 4) ? cyan : UIColor.white
            star.strokeColor = .clear
            star.alpha = 0.12 + CGFloat((index * 29) % 50) / 100
            star.position = CGPoint(
                x: CGFloat((index * 83 + 31) % max(Int(size.width), 1)),
                y: CGFloat((index * 137 + 53) % max(Int(size.height), 1))
            )
            star.userData = ["speed": CGFloat(12 + (index * 11) % 38)]
            gridNode.addChild(star)
            stars.append(star)
        }
    }

    private func configurePlayer() {
        playerNode.zPosition = Z.player
        playerNode.removeAllChildren()

        let glowPath = CGMutablePath()
        glowPath.move(to: CGPoint(x: 0, y: 25))
        glowPath.addLine(to: CGPoint(x: -18, y: -18))
        glowPath.addLine(to: CGPoint(x: 0, y: -10))
        glowPath.addLine(to: CGPoint(x: 18, y: -18))
        glowPath.closeSubpath()

        let glow = SKShapeNode(path: glowPath)
        glow.fillColor = cyan.withAlphaComponent(0.22)
        glow.strokeColor = cyan
        glow.lineWidth = 2
        glow.glowWidth = 12
        playerNode.addChild(glow)

        let core = SKShapeNode(path: glowPath)
        core.setScale(0.72)
        core.fillColor = UIColor.white.withAlphaComponent(0.96)
        core.strokeColor = cyan
        core.lineWidth = 2
        core.glowWidth = 4
        playerNode.addChild(core)

        let engineLight = SKShapeNode(circleOfRadius: 4)
        engineLight.position = CGPoint(x: 0, y: -15)
        engineLight.fillColor = magenta
        engineLight.strokeColor = .white
        engineLight.glowWidth = 8
        playerNode.addChild(engineLight)

        let trail = makeEmitter(color: cyan, birthRate: 65, lifetime: 0.48, scale: 0.12)
        trail.particlePositionRange = CGVector(dx: 10, dy: 3)
        trail.emissionAngle = -.pi / 2
        trail.emissionAngleRange = 0.22
        trail.particleSpeed = 62
        trail.particleSpeedRange = 20
        trail.position = CGPoint(x: 0, y: -17)
        playerNode.addChild(trail)
        playerTrail = trail

        playerNode.position = CGPoint(x: size.width / 2, y: playerY)
        targetPlayerX = playerNode.position.x
        worldNode.addChild(playerNode)
    }

    private func configureHUD() {
        scoreLabel.fontSize = 21
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.zPosition = Z.hud
        addChild(scoreLabel)

        levelLabel.fontSize = 12
        levelLabel.fontColor = cyan
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .center
        levelLabel.zPosition = Z.hud
        addChild(levelLabel)

        shieldLabel.fontSize = 14
        shieldLabel.fontColor = UIColor.white.withAlphaComponent(0.84)
        shieldLabel.horizontalAlignmentMode = .right
        shieldLabel.verticalAlignmentMode = .center
        shieldLabel.zPosition = Z.hud
        addChild(shieldLabel)

        comboLabel.fontSize = 26
        comboLabel.fontColor = amber
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.verticalAlignmentMode = .center
        comboLabel.zPosition = Z.hud
        addChild(comboLabel)

        chargeTrack.fillColor = UIColor.white.withAlphaComponent(0.08)
        chargeTrack.strokeColor = UIColor.white.withAlphaComponent(0.14)
        chargeTrack.lineWidth = 1
        chargeTrack.zPosition = Z.hud
        addChild(chargeTrack)

        chargeFill.fillColor = magenta
        chargeFill.strokeColor = .clear
        chargeFill.glowWidth = 5
        chargeFill.zPosition = Z.hud + 1
        addChild(chargeFill)

        overdriveButton.fillColor = violet.withAlphaComponent(0.22)
        overdriveButton.strokeColor = magenta.withAlphaComponent(0.8)
        overdriveButton.lineWidth = 1.5
        overdriveButton.glowWidth = 4
        overdriveButton.zPosition = Z.hud
        addChild(overdriveButton)

        overdriveLabel.text = "超载"
        overdriveLabel.fontSize = 11
        overdriveLabel.fontColor = UIColor.white.withAlphaComponent(0.7)
        overdriveLabel.verticalAlignmentMode = .center
        overdriveLabel.zPosition = Z.hud + 2
        addChild(overdriveLabel)
        updateHUD()
    }

    private func configureMessage() {
        messageNode.zPosition = Z.overlay
        let panel = SKShapeNode(rectOf: CGSize(width: min(330, size.width - 42), height: 142), cornerRadius: 24)
        panel.name = "messagePanel"
        panel.fillColor = UIColor(red: 0.035, green: 0.035, blue: 0.11, alpha: 0.92)
        panel.strokeColor = cyan.withAlphaComponent(0.7)
        panel.lineWidth = 1.5
        panel.glowWidth = 8
        messageNode.addChild(panel)

        messageTitle.fontSize = 29
        messageTitle.fontColor = .white
        messageTitle.verticalAlignmentMode = .center
        messageTitle.position = CGPoint(x: 0, y: 23)
        messageNode.addChild(messageTitle)

        messageSubtitle.fontSize = 13
        messageSubtitle.fontColor = UIColor.white.withAlphaComponent(0.66)
        messageSubtitle.verticalAlignmentMode = .center
        messageSubtitle.position = CGPoint(x: 0, y: -25)
        messageNode.addChild(messageSubtitle)
        addChild(messageNode)
    }

    private func layoutScene() {
        let safeTop = max(30, view?.safeAreaInsets.top ?? 0)
        scoreLabel.position = CGPoint(x: 18, y: size.height - safeTop - 31)
        levelLabel.position = CGPoint(x: 18, y: size.height - safeTop - 56)
        shieldLabel.position = CGPoint(x: size.width - 18, y: size.height - safeTop - 34)
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height - safeTop - 40)

        let chargeWidth = max(100, size.width - 158)
        let chargeY = size.height - safeTop - 78
        chargeTrack.path = CGPath(roundedRect: CGRect(x: -chargeWidth / 2, y: -3, width: chargeWidth, height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil)
        chargeTrack.position = CGPoint(x: 18 + chargeWidth / 2, y: chargeY)
        overdriveButton.path = CGPath(roundedRect: CGRect(x: -27, y: -14, width: 54, height: 28), cornerWidth: 10, cornerHeight: 10, transform: nil)
        overdriveButton.position = CGPoint(x: size.width - 46, y: chargeY)
        overdriveLabel.position = overdriveButton.position
        messageNode.position = CGPoint(x: size.width / 2, y: size.height * 0.57)

        playerNode.position.y = playerY
        playerNode.position.x = min(max(playerNode.position.x, playfieldLeft + 22), size.width - playfieldLeft - 22)
        targetPlayerX = playerNode.position.x
    }

    private func updateTarget(with location: CGPoint) {
        guard engine.state.phase == .running else { return }
        targetPlayerX = min(max(location.x, playfieldLeft + 20), size.width - playfieldLeft - 20)
    }

    private func updatePlayer(delta: TimeInterval) {
        let response = min(1, CGFloat(delta) * 16)
        let previousX = playerNode.position.x
        playerNode.position.x += (targetPlayerX - playerNode.position.x) * response
        let velocity = delta > 0 ? (playerNode.position.x - previousX) / CGFloat(delta) : 0
        playerNode.zRotation = min(0.30, max(-0.30, -velocity / 1_100))
        playerTrail?.particleBirthRate = engine.state.isOverdriveActive ? 145 : 65
        playerNode.setScale(engine.state.isOverdriveActive ? 1.12 : 1)
    }

    private func spawn(_ event: RhythmBeatEvent) {
        let node = RhythmFallingBeatNode(event: event, laneWidth: laneWidth, cyan: cyan, magenta: magenta, amber: amber)
        node.position = CGPoint(x: laneX(event.lane), y: size.height + 50)
        node.zPosition = Z.beats
        beatNode.addChild(node)
        fallingBeats.append(node)
    }

    private func updateFallingBeats() {
        let currentTime = engine.state.elapsed
        let travelDuration = engine.configuration.travelDuration
        let startY = size.height + 50
        let endY = playerY - 86

        for node in fallingBeats where !node.wasResolved {
            let startTime = node.event.arrivalTime - travelDuration
            let progress = CGFloat((currentTime - startTime) / travelDuration)
            node.position.y = startY + (endY - startY) * progress
            node.visualRotation += CGFloat(0.018 * node.event.speedScale)

            guard node.position.y <= playerY + 24 else { continue }
            node.wasResolved = true
            let distance = abs(node.position.x - playerNode.position.x)
            resolve(node, horizontalDistance: distance)
        }

        fallingBeats.removeAll { node in
            if node.position.y < -90 || node.wasResolved {
                if node.wasResolved {
                    node.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
                } else {
                    node.removeFromParent()
                }
                return true
            }
            return false
        }
    }

    private func resolve(_ node: RhythmFallingBeatNode, horizontalDistance distance: CGFloat) {
        let contactRadius = node.event.kind == .spinner ? laneWidth * 0.43 : laneWidth * 0.34
        if node.event.kind == .energyOrb {
            if distance < contactRadius + 11 {
                _ = engine.register(.energyCollected)
                burst(at: node.position, color: amber, count: 42)
                showFloatingText("能量 +24", at: node.position, color: amber)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                _ = engine.register(.energyMissed)
            }
            return
        }

        if distance < contactRadius + 15 {
            if engine.state.isOverdriveActive {
                _ = engine.register(.perfectDodge)
                burst(at: node.position, color: magenta, count: 54)
                showFloatingText("击穿", at: node.position, color: magenta)
            } else if engine.register(.collision) {
                burst(at: playerNode.position, color: magenta, count: 62)
                flashDamage()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        } else if distance < laneWidth * 1.15 {
            _ = engine.register(.perfectDodge)
            burst(at: node.position, color: cyan, count: 20)
            showFloatingText("PERFECT", at: CGPoint(x: node.position.x, y: playerY + 48), color: cyan)
        } else {
            _ = engine.register(.dodge)
        }

        if engine.state.phase == .finished { finishRun() }
    }

    private func triggerOverdrive() {
        guard engine.activateOverdrive() else {
            overdriveButton.run(.sequence([
                .scale(to: 0.9, duration: 0.06),
                .scale(to: 1, duration: 0.12)
            ]))
            return
        }
        burst(at: playerNode.position, color: magenta, count: 90)
        showTransientMessage("OVERDRIVE", subtitle: "4.5 秒无敌 · 双倍得分")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func animateBeatPulse() {
        let ring = SKShapeNode(circleOfRadius: 26)
        ring.position = CGPoint(x: playerNode.position.x, y: playerY)
        ring.strokeColor = engine.state.isOverdriveActive ? magenta : cyan
        ring.lineWidth = 2
        ring.glowWidth = 6
        ring.zPosition = Z.grid + 1
        effectsNode.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 3.8, duration: engine.configuration.beatInterval * 0.82), .fadeOut(withDuration: engine.configuration.beatInterval * 0.82)]),
            .removeFromParent()
        ]))
        comboLabel.run(.sequence([.scale(to: 1.13, duration: 0.06), .scale(to: 1, duration: 0.16)]))
    }

    private func updateAmbientMotion(delta: TimeInterval, time: TimeInterval) {
        for (index, star) in stars.enumerated() {
            let speed = (star.userData?["speed"] as? CGFloat) ?? 18
            star.position.y -= speed * CGFloat(delta)
            if star.position.y < -4 {
                star.position.y = size.height + 4
                star.position.x = CGFloat((index * 97 + Int(time * 31)) % max(Int(size.width), 1))
            }
        }
        let breathe = 1 + CGFloat(sin(time * 4.5)) * 0.025
        if engine.state.phase != .finished { playerNode.setScale((engine.state.isOverdriveActive ? 1.12 : 1) * breathe) }
    }

    private func updateHUD() {
        let state = engine.state
        scoreLabel.text = String(format: "%07d", state.score)
        levelLabel.text = "LEVEL \(state.level)  ·  \(Int(engine.configuration.bpm)) BPM"
        shieldLabel.text = "护盾 " + String(repeating: "◆", count: state.shield) + String(repeating: "◇", count: 3 - state.shield)
        comboLabel.text = state.combo > 1 ? "×\(state.combo)" : ""

        let width = max(100, size.width - 158)
        let fillWidth = width * CGFloat(state.overdriveCharge) / 100
        chargeFill.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -3, width: max(fillWidth, 0.1), height: 6), cornerWidth: 3, cornerHeight: 3, transform: nil)
        chargeFill.position = CGPoint(x: 18 + width / 2, y: chargeTrack.position.y)
        overdriveLabel.text = state.isOverdriveActive ? "×2" : (state.overdriveCharge >= 100 ? "启动" : "超载")
        overdriveButton.strokeColor = state.overdriveCharge >= 100 || state.isOverdriveActive ? amber : magenta.withAlphaComponent(0.55)
        overdriveButton.fillColor = state.isOverdriveActive ? magenta.withAlphaComponent(0.48) : violet.withAlphaComponent(0.22)
    }

    private func beginNextLevel() {
        clearFallingBeats()
        showTransientMessage("LEVEL \(engine.state.level)", subtitle: "\(Int(engine.configuration.bpm)) BPM · 速度提升")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func finishRun() {
        clearFallingBeats()
        playerNode.run(.sequence([.scale(to: 0.82, duration: 0.12), .fadeAlpha(to: 0.45, duration: 0.18)]))
        messageTitle.text = engine.state.shield == 0 ? "信号失联" : "航道完成"
        messageSubtitle.text = "得分 \(engine.state.score) · 最佳连击 ×\(engine.state.bestCombo) · 触摸重试"
        messageNode.removeAllActions()
        messageNode.alpha = 0
        messageNode.setScale(0.88)
        messageNode.run(.group([.fadeIn(withDuration: 0.25), .scale(to: 1, duration: 0.34)]))
    }

    private func showReadyMessage() {
        messageTitle.text = "NEON BEAT"
        messageSubtitle.text = "触摸开始 · 滑动闪避 · 双击释放超载"
        messageNode.alpha = 1
        messageNode.setScale(1)
    }

    private func hideMessage() {
        messageNode.removeAllActions()
        messageNode.run(.sequence([.group([.fadeOut(withDuration: 0.18), .scale(to: 1.08, duration: 0.18)])]))
    }

    private func showTransientMessage(_ title: String, subtitle: String) {
        messageTitle.text = title
        messageSubtitle.text = subtitle
        messageNode.removeAllActions()
        messageNode.alpha = 0
        messageNode.setScale(0.82)
        messageNode.run(.sequence([
            .group([.fadeIn(withDuration: 0.16), .scale(to: 1, duration: 0.24)]),
            .wait(forDuration: 0.72),
            .group([.fadeOut(withDuration: 0.24), .scale(to: 1.08, duration: 0.24)])
        ]))
    }

    private func clearFallingBeats() {
        fallingBeats.removeAll()
        beatNode.removeAllChildren()
    }

    private func burst(at position: CGPoint, color: UIColor, count: Int) {
        let emitter = makeEmitter(color: color, birthRate: 0, lifetime: 0.58, scale: 0.17)
        emitter.position = position
        emitter.particleSpeed = 105
        emitter.particleSpeedRange = 75
        emitter.emissionAngleRange = .pi * 2
        emitter.numParticlesToEmit = count
        emitter.particleBirthRate = CGFloat(count) * 8
        emitter.zPosition = Z.player + 3
        effectsNode.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 0.9), .removeFromParent()]))
    }

    private func makeEmitter(color: UIColor, birthRate: CGFloat, lifetime: CGFloat, scale: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = RhythmParticleTexture.shared
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBirthRate = birthRate
        emitter.particleLifetime = lifetime
        emitter.particleLifetimeRange = lifetime * 0.28
        emitter.particleAlpha = 0.86
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = scale
        emitter.particleScaleRange = scale * 0.45
        emitter.particleScaleSpeed = -0.12
        emitter.particleBlendMode = .add
        return emitter
    }

    private func showFloatingText(_ text: String, at position: CGPoint, color: UIColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 13
        label.fontColor = color
        label.position = position
        label.zPosition = Z.overlay - 1
        effectsNode.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 34, duration: 0.5), .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))
    }

    private func flashDamage() {
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = magenta.withAlphaComponent(0.26)
        flash.strokeColor = .clear
        flash.zPosition = Z.overlay - 2
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
        worldNode.run(.sequence([
            .moveBy(x: -7, y: 2, duration: 0.035),
            .moveBy(x: 13, y: -3, duration: 0.045),
            .moveBy(x: -6, y: 1, duration: 0.04)
        ]))
    }
}

private final class RhythmFallingBeatNode: SKNode {
    let event: RhythmBeatEvent
    var wasResolved = false
    private let visualNode = SKNode()

    var visualRotation: CGFloat {
        get { visualNode.zRotation }
        set { visualNode.zRotation = newValue }
    }

    init(event: RhythmBeatEvent, laneWidth: CGFloat, cyan: UIColor, magenta: UIColor, amber: UIColor) {
        self.event = event
        super.init()
        addChild(visualNode)

        switch event.kind {
        case .gate:
            let width = laneWidth * 0.58
            let path = CGPath(roundedRect: CGRect(x: -width / 2, y: -11, width: width, height: 22), cornerWidth: 7, cornerHeight: 7, transform: nil)
            addNeonLayers(path: path, color: magenta, fillAlpha: 0.35)
            let notch = SKShapeNode(rectOf: CGSize(width: width * 0.55, height: 2))
            notch.fillColor = .white
            notch.strokeColor = cyan
            notch.glowWidth = 4
            visualNode.addChild(notch)
        case .spinner:
            let radius = laneWidth * 0.27
            let ring = SKShapeNode(circleOfRadius: radius)
            ring.fillColor = UIColor.clear
            ring.strokeColor = magenta
            ring.lineWidth = 5
            ring.glowWidth = 9
            visualNode.addChild(ring)
            for rotation in [CGFloat.zero, .pi / 2] {
                let bar = SKShapeNode(rectOf: CGSize(width: radius * 2.25, height: 5), cornerRadius: 2.5)
                bar.fillColor = cyan
                bar.strokeColor = .white
                bar.glowWidth = 5
                bar.zRotation = rotation
                visualNode.addChild(bar)
            }
        case .energyOrb:
            let outer = SKShapeNode(circleOfRadius: 18)
            outer.fillColor = amber.withAlphaComponent(0.28)
            outer.strokeColor = amber
            outer.lineWidth = 3
            outer.glowWidth = 13
            visualNode.addChild(outer)
            let core = SKShapeNode(circleOfRadius: 6)
            core.fillColor = .white
            core.strokeColor = amber
            core.glowWidth = 7
            visualNode.addChild(core)
            visualNode.run(.repeatForever(.sequence([.scale(to: 1.16, duration: 0.28), .scale(to: 0.92, duration: 0.28)])))
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addNeonLayers(path: CGPath, color: UIColor, fillAlpha: CGFloat) {
        let glow = SKShapeNode(path: path)
        glow.fillColor = color.withAlphaComponent(fillAlpha)
        glow.strokeColor = color
        glow.lineWidth = 3
        glow.glowWidth = 10
        visualNode.addChild(glow)
    }
}

private enum RhythmParticleTexture {
    static let shared: SKTexture = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        let image = renderer.image { context in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }
            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: 8, y: 8),
                startRadius: 0,
                endCenter: CGPoint(x: 8, y: 8),
                endRadius: 8,
                options: []
            )
        }
        return SKTexture(image: image)
    }()
}
