import SceneKit
import SwiftUI
import UIKit

@MainActor
final class PrismRift3DController: NSObject, ObservableObject {
    enum RenderTier { case minimal, balanced, full }

    @Published private(set) var snapshot: PrismRiftSnapshot
    @Published private(set) var message = "拖动航向 · 按住开火 · 穿越棱镜裂隙"

    let view = SCNView(frame: .zero)
    private let scene = SCNScene()
    private let cameraNode = SCNNode()
    private let shipNode = SCNNode()
    private let engineLight = SCNLight()
    private let bossNode = SCNNode()
    private let worldNode = SCNNode()
    private let effectsNode = SCNNode()
    private var encounterNodes: [Int: SCNNode] = [:]
    private var tunnelRings: [SCNNode] = []
    private var state: PrismRiftState
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var accumulator = 0.0
    private var steeringX = 0.0
    private var steeringY = 0.0
    private var firing = false
    private var boosting = false
    private var paused = false
    private let tier: RenderTier

    init(seed: UInt64 = UInt64(Date().timeIntervalSince1970 * 1_000)) {
        state = PrismRiftState(seed: seed)
        snapshot = state.snapshot
        if VeilPerformanceOverrides.forceFullVisualEffects {
            tier = .full
        } else {
            switch VeilDevicePerformance.current.transferVisualComplexity {
            case .minimal: tier = .minimal
            case .balanced: tier = .balanced
            case .full: tier = .full
            }
        }
        super.init()
        configureScene()
    }

    func start() {
        guard displayLink == nil else { paused = false; return }
        paused = false
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        if #available(iOS 15.0, *) {
            let maximum = Float(ArcadeRenderPolicy.preferredFramesPerSecond)
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: maximum, preferred: maximum)
        }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func pause() {
        paused = true
        firing = false
        boosting = false
        lastTimestamp = 0
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        pause()
    }

    func restart() {
        state = PrismRiftState(seed: state.seed &+ 1)
        snapshot = state.snapshot
        message = "新裂隙已生成 · 航向同步"
        encounterNodes.values.forEach { $0.removeFromParentNode() }
        encounterNodes.removeAll()
        bossNode.isHidden = true
        accumulator = 0
        lastTimestamp = 0
        paused = false
    }

    func steer(horizontal: Double, vertical: Double) {
        steeringX = min(1, max(-1, horizontal))
        steeringY = min(1, max(-1, vertical))
    }

    func releaseSteering() {
        steeringX = 0
        steeringY = 0
    }

    func setFiring(_ value: Bool) { firing = value }
    func setBoosting(_ value: Bool) { boosting = value }

    private func configureScene() {
        view.scene = scene
        view.backgroundColor = UIColor(red: 0.004, green: 0.006, blue: 0.025, alpha: 1)
        view.preferredFramesPerSecond = ArcadeRenderPolicy.preferredFramesPerSecond
        view.rendersContinuously = true
        view.isPlaying = true
        view.antialiasingMode = tier == .full ? .multisampling4X : (tier == .balanced ? .multisampling2X : .none)
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false

        scene.rootNode.addChildNode(worldNode)
        scene.rootNode.addChildNode(effectsNode)
        scene.fogColor = UIColor(red: 0.015, green: 0.025, blue: 0.09, alpha: 1)
        scene.fogStartDistance = tier == .minimal ? 24 : 34
        scene.fogEndDistance = tier == .minimal ? 48 : 64

        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 68
        cameraNode.camera?.wantsHDR = tier != .minimal
        cameraNode.camera?.bloomIntensity = tier == .full ? 1.15 : 0.45
        cameraNode.camera?.bloomThreshold = 0.55
        cameraNode.camera?.bloomBlurRadius = tier == .full ? 12 : 6
        cameraNode.position = SCNVector3(0, 1.1, 8.2)
        cameraNode.eulerAngles.x = -.pi * 0.025
        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = tier == .minimal ? 180 : 260
        ambient.color = UIColor(red: 0.26, green: 0.30, blue: 0.62, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        configureShip()
        configureTunnel()
        configureStars()
        configureBoss()
        streamEncounterNodes(force: true)
    }

    private func configureShip() {
        let hull = SCNNode(geometry: SCNCone(topRadius: 0.05, bottomRadius: 0.42, height: 1.35))
        hull.geometry?.firstMaterial = material(
            diffuse: UIColor(red: 0.12, green: 0.16, blue: 0.27, alpha: 1),
            emission: UIColor(red: 0.02, green: 0.19, blue: 0.35, alpha: 1),
            metalness: 0.86,
            roughness: 0.22
        )
        hull.eulerAngles.x = -.pi / 2
        shipNode.addChildNode(hull)

        for direction: Float in [-1, 1] {
            let wing = SCNNode(geometry: SCNBox(width: 0.72, height: 0.055, length: 0.42, chamferRadius: 0.05))
            wing.geometry?.firstMaterial = material(
                diffuse: UIColor(red: 0.10, green: 0.08, blue: 0.24, alpha: 1),
                emission: UIColor(red: 0.24, green: 0.05, blue: 0.42, alpha: 1),
                metalness: 0.72,
                roughness: 0.28
            )
            wing.position = SCNVector3(direction * 0.46, -0.04, 0.08)
            wing.eulerAngles.z = direction * -0.16
            shipNode.addChildNode(wing)
        }

        let core = SCNNode(geometry: SCNSphere(radius: 0.13))
        core.geometry?.firstMaterial = material(diffuse: .white, emission: .cyan, metalness: 0.2, roughness: 0.08)
        core.position = SCNVector3(0, 0.05, 0.15)
        shipNode.addChildNode(core)

        engineLight.type = .omni
        engineLight.color = UIColor.cyan
        engineLight.intensity = tier == .full ? 1_250 : 720
        engineLight.attenuationEndDistance = 9
        let lightNode = SCNNode()
        lightNode.light = engineLight
        lightNode.position = SCNVector3(0, 0, 0.7)
        shipNode.addChildNode(lightNode)

        let trail = SCNParticleSystem()
        trail.birthRate = tier == .minimal ? 42 : (tier == .balanced ? 95 : 170)
        trail.particleLifeSpan = 0.8
        trail.particleSize = 0.055
        trail.particleColor = UIColor.cyan
        trail.emitterShape = SCNCone(topRadius: 0.02, bottomRadius: 0.18, height: 0.25)
        trail.particleVelocity = 2.2
        trail.particleVelocityVariation = 0.7
        trail.spreadingAngle = 12
        trail.blendMode = .additive
        let trailNode = SCNNode()
        trailNode.addParticleSystem(trail)
        trailNode.position = SCNVector3(0, 0, 0.7)
        trailNode.eulerAngles.x = .pi / 2
        shipNode.addChildNode(trailNode)

        shipNode.position = SCNVector3(0, 0, 0.8)
        scene.rootNode.addChildNode(shipNode)
    }

    private func configureTunnel() {
        let ringCount = tier == .minimal ? 12 : 20
        for index in 0..<ringCount {
            let ring = SCNNode(geometry: SCNTorus(ringRadius: 4.7, pipeRadius: tier == .minimal ? 0.018 : 0.028))
            let hue = CGFloat(index % 2 == 0 ? 0.53 : 0.78)
            ring.geometry?.firstMaterial = material(
                diffuse: UIColor(hue: hue, saturation: 0.8, brightness: 0.8, alpha: 0.45),
                emission: UIColor(hue: hue, saturation: 0.9, brightness: 0.7, alpha: 1),
                metalness: 0.3,
                roughness: 0.2
            )
            ring.position.z = Float(-index * 4)
            ring.eulerAngles = SCNVector3(Float(index % 3) * 0.22, Float(index % 5) * 0.13, Float(index) * 0.17)
            worldNode.addChildNode(ring)
            tunnelRings.append(ring)
        }
    }

    private func configureStars() {
        let particles = SCNParticleSystem()
        particles.birthRate = tier == .minimal ? 90 : (tier == .balanced ? 190 : 360)
        particles.particleLifeSpan = 8
        particles.particleLifeSpanVariation = 2
        particles.particleSize = tier == .full ? 0.022 : 0.014
        particles.particleColor = UIColor(white: 0.9, alpha: 0.8)
        particles.emitterShape = SCNBox(width: 9, height: 9, length: 42, chamferRadius: 0)
        particles.particleVelocity = 9
        particles.spreadingAngle = 4
        particles.blendMode = .additive
        let node = SCNNode()
        node.position = SCNVector3(0, 0, -18)
        node.eulerAngles.x = -.pi / 2
        node.addParticleSystem(particles)
        scene.rootNode.addChildNode(node)
    }

    private func configureBoss() {
        let shellGeometry = SCNSphere(radius: 1.15)
        shellGeometry.segmentCount = tier == .minimal ? 8 : 12
        let shell = SCNNode(geometry: shellGeometry)
        shell.geometry?.firstMaterial = material(
            diffuse: UIColor(red: 0.22, green: 0.015, blue: 0.12, alpha: 1),
            emission: UIColor(red: 0.65, green: 0.01, blue: 0.28, alpha: 1),
            metalness: 0.94,
            roughness: 0.16
        )
        bossNode.addChildNode(shell)
        for index in 0..<3 {
            let ring = SCNNode(geometry: SCNTorus(ringRadius: CGFloat(1.45 + Double(index) * 0.28), pipeRadius: 0.035))
            ring.geometry?.firstMaterial = material(diffuse: .black, emission: .magenta, metalness: 0.6, roughness: 0.15)
            ring.name = "boss-ring-\(index)"
            bossNode.addChildNode(ring)
        }
        let light = SCNLight()
        light.type = .omni
        light.color = UIColor.magenta
        light.intensity = tier == .full ? 1_600 : 900
        light.attenuationEndDistance = 13
        let lightNode = SCNNode()
        lightNode.light = light
        bossNode.addChildNode(lightNode)
        bossNode.position.z = -9
        bossNode.isHidden = true
        scene.rootNode.addChildNode(bossNode)
    }

    @objc private func frame(_ link: CADisplayLink) {
        guard !paused, snapshot.outcome == .running else { lastTimestamp = link.timestamp; return }
        let elapsed = lastTimestamp == 0 ? PrismRiftState.fixedDelta : min(0.1, link.timestamp - lastTimestamp)
        lastTimestamp = link.timestamp
        accumulator += elapsed
        var steps = 0
        while accumulator >= PrismRiftState.fixedDelta, steps < 5 {
            state.step(input: PrismRiftInput(horizontal: steeringX, vertical: steeringY, firing: firing, boosting: boosting))
            process(state.events)
            accumulator -= PrismRiftState.fixedDelta
            steps += 1
        }
        let latest = state.snapshot
        let publishStride = tier == .minimal ? 4 : 2
        if steps > 0,
           state.tick.isMultiple(of: publishStride)
            || latest.outcome != snapshot.outcome
            || latest.bossIndex != snapshot.bossIndex {
            snapshot = latest
        }
        updatePresentation(time: link.timestamp)
    }

    private func updatePresentation(time: TimeInterval) {
        let current = state.snapshot
        shipNode.position.x = Float(current.x * 3.25)
        shipNode.position.y = Float(current.y * 2.75)
        shipNode.eulerAngles.z = Float(-state.velocityX * 0.34)
        shipNode.eulerAngles.x = Float(state.velocityY * 0.16)
        engineLight.intensity = boosting ? (tier == .full ? 2_200 : 1_150) : (tier == .full ? 1_250 : 720)

        let worldOffset = (state.distance / PrismRiftState.segmentLength) * 4
        for (index, ring) in tunnelRings.enumerated() {
            var z = -Double(index * 4) + worldOffset.truncatingRemainder(dividingBy: Double(tunnelRings.count * 4))
            if z > 2 { z -= Double(tunnelRings.count * 4) }
            ring.position.z = Float(z)
            ring.eulerAngles.z += Float(0.0015 + Double(index % 3) * 0.0005)
        }

        if tickNeedsStreaming { streamEncounterNodes(force: false) }
        for (segment, node) in encounterNodes {
            node.position.z = Float(-(Double(segment) * 4 - worldOffset))
            node.eulerAngles.y += node.name == "pickup" ? 0.035 : 0.008
            node.eulerAngles.x += node.name == "asteroid" ? 0.006 : 0
        }

        if let index = current.bossIndex {
            bossNode.isHidden = false
            let position = state.bossPosition(index: index)
            bossNode.position.x = Float(position.x * 3.25)
            bossNode.position.y = Float(position.y * 2.75)
            bossNode.eulerAngles.y += 0.012
            bossNode.eulerAngles.z += 0.006
            for child in bossNode.childNodes where child.name?.hasPrefix("boss-ring") == true {
                child.eulerAngles.x += 0.009
                child.eulerAngles.y -= 0.014
            }
        } else {
            bossNode.isHidden = true
        }

        cameraNode.position.x += (shipNode.position.x * 0.08 - cameraNode.position.x) * 0.06
        cameraNode.position.y += (1.1 + shipNode.position.y * 0.05 - cameraNode.position.y) * 0.06
        scene.fogColor = UIColor(
            red: 0.012 + CGFloat(current.progress) * 0.08,
            green: 0.018 + CGFloat(current.progress) * 0.035,
            blue: 0.07 + CGFloat(sin(time * 0.18) * 0.02 + 0.02),
            alpha: 1
        )
    }

    private var tickNeedsStreaming: Bool { state.tick.isMultiple(of: 12) }

    private func streamEncounterNodes(force: Bool) {
        let current = state.segment
        let wanted = Set((max(0, current - 1)...min(PrismRiftState.finalSegment, current + 15)).filter {
            !PrismRiftState.bossSegments.contains($0)
        })
        for segment in Array(encounterNodes.keys) where !wanted.contains(segment) {
            encounterNodes.removeValue(forKey: segment)?.removeFromParentNode()
        }
        for segment in wanted where force || encounterNodes[segment] == nil {
            guard encounterNodes[segment] == nil else { continue }
            let encounter = state.encounter(for: segment)
            let node = makeEncounterNode(encounter)
            node.position.x = Float(encounter.x * 3.25)
            node.position.y = Float(encounter.y * 2.75)
            encounterNodes[segment] = node
            worldNode.addChildNode(node)
        }
    }

    private func makeEncounterNode(_ encounter: PrismRiftEncounter) -> SCNNode {
        let node: SCNNode
        switch encounter.kind {
        case .asteroid:
            let asteroid = SCNSphere(radius: CGFloat(0.42 + encounter.radius * 0.8))
            asteroid.segmentCount = tier == .minimal ? 6 : 8
            node = SCNNode(geometry: asteroid)
            node.name = "asteroid"
            node.scale = SCNVector3(1, 0.78, 1.25)
            node.geometry?.firstMaterial = material(diffuse: UIColor(white: 0.16, alpha: 1), emission: UIColor(red: 0.04, green: 0.01, blue: 0.08, alpha: 1), metalness: 0.35, roughness: 0.82)
        case .mine:
            node = SCNNode(geometry: SCNSphere(radius: 0.34))
            node.name = "mine"
            node.geometry?.firstMaterial = material(diffuse: .black, emission: .red, metalness: 0.8, roughness: 0.22)
            for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 3) {
                let spike = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.52))
                spike.position = SCNVector3(cos(angle) * 0.46, sin(angle) * 0.46, 0)
                spike.eulerAngles.z = Float(angle - .pi / 2)
                spike.geometry?.firstMaterial = node.geometry?.firstMaterial
                node.addChildNode(spike)
            }
        case .drone:
            node = SCNNode(geometry: SCNCapsule(capRadius: 0.18, height: 0.72))
            node.name = "drone"
            node.geometry?.firstMaterial = material(diffuse: UIColor(red: 0.12, green: 0.05, blue: 0.22, alpha: 1), emission: .purple, metalness: 0.9, roughness: 0.18)
            node.eulerAngles.z = .pi / 2
        case .energy, .repair:
            node = SCNNode(geometry: SCNPyramid(width: 0.46, height: 0.62, length: 0.46))
            node.name = "pickup"
            let color: UIColor = encounter.kind == .energy ? .cyan : .green
            node.geometry?.firstMaterial = material(diffuse: .white, emission: color, metalness: 0.25, roughness: 0.1)
            let halo = SCNNode(geometry: SCNTorus(ringRadius: 0.46, pipeRadius: 0.018))
            halo.geometry?.firstMaterial = material(diffuse: color, emission: color, metalness: 0, roughness: 0)
            node.addChildNode(halo)
        }
        return node
    }

    private func process(_ events: [PrismRiftEvent]) {
        for event in events {
            switch event.kind {
            case .impact:
                message = "护盾受击 · 重新校准航向"
                cameraNode.runAction(SCNAction.sequence([
                    SCNAction.moveBy(x: 0.13, y: -0.08, z: 0, duration: 0.035),
                    SCNAction.moveBy(x: -0.24, y: 0.15, z: 0, duration: 0.05),
                    SCNAction.moveBy(x: 0.11, y: -0.07, z: 0, duration: 0.06)
                ]))
                burst(at: shipNode.position, color: .orange, count: tier == .minimal ? 12 : 34)
            case .collected(let kind):
                message = kind == .energy ? "棱镜能量已吸收" : "纳米修复单元已接入"
                burst(at: shipNode.position, color: kind == .energy ? .cyan : .green, count: tier == .minimal ? 10 : 28)
            case .shot:
                spawnLaser()
            case .bossArrived(let index):
                message = "裂隙守卫 \(index + 1) 已锁定 · 对准核心持续开火"
            case .bossHit:
                burst(at: bossNode.position, color: .magenta, count: tier == .minimal ? 4 : 12)
            case .bossDefeated(let index):
                message = "守卫 \(index + 1) 解体 · 航道重新开放"
                burst(at: bossNode.position, color: .magenta, count: tier == .minimal ? 30 : 90)
            case .escaped:
                message = "已穿越棱镜裂隙"
            case .destroyed:
                message = "舰体失效 · 裂隙坐标已保留"
            }
        }
    }

    private func spawnLaser() {
        let laser = SCNNode(geometry: SCNCylinder(radius: 0.018, height: 1.7))
        laser.geometry?.firstMaterial = material(diffuse: .white, emission: .cyan, metalness: 0, roughness: 0)
        laser.eulerAngles.x = .pi / 2
        laser.position = shipNode.position
        laser.position.z -= 0.8
        effectsNode.addChildNode(laser)
        laser.runAction(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0, z: -18, duration: 0.24),
            SCNAction.removeFromParentNode()
        ]))
    }

    private func burst(at position: SCNVector3, color: UIColor, count: CGFloat) {
        let system = SCNParticleSystem()
        system.birthRate = 0
        system.emissionDuration = 0.05
        system.loops = false
        system.particleLifeSpan = 0.55
        system.particleLifeSpanVariation = 0.25
        system.particleSize = 0.065
        system.particleColor = color
        system.particleVelocity = 3.6
        system.particleVelocityVariation = 2.1
        system.spreadingAngle = 180
        system.blendMode = .additive
        system.birthRate = count / CGFloat(system.emissionDuration)
        let node = SCNNode()
        node.position = position
        node.addParticleSystem(system)
        effectsNode.addChildNode(node)
        node.runAction(SCNAction.sequence([
            SCNAction.wait(duration: 1.2),
            SCNAction.removeFromParentNode()
        ]))
    }

    private func material(diffuse: UIColor, emission: UIColor, metalness: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let value = SCNMaterial()
        value.lightingModel = .physicallyBased
        value.diffuse.contents = diffuse
        value.emission.contents = emission
        value.metalness.contents = metalness
        value.roughness.contents = roughness
        return value
    }
}

private struct PrismRiftSceneView: UIViewRepresentable {
    @ObservedObject var controller: PrismRift3DController

    func makeUIView(context: Context) -> SCNView {
        controller.start()
        return controller.view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    static func dismantleUIView(_ uiView: SCNView, coordinator: ()) {
        uiView.isPlaying = false
    }
}

@MainActor
struct PrismRift3DGameView: View {
    @StateObject private var controller = PrismRift3DController()
    @Environment(\.scenePhase) private var scenePhase
    @State private var controlOrigin: CGPoint?
    @State private var showsGuide = false

    var body: some View {
        ZStack {
            PrismRiftSceneView(controller: controller).ignoresSafeArea()
            controls
            if controller.snapshot.outcome != .running { resultOverlay }
        }
        .navigationTitle("棱镜裂隙 3D")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showsGuide = true } label: { Image(systemName: "questionmark.circle") }
                    .accessibilityLabel("打开棱镜裂隙教程")
            }
        }
        .sheet(isPresented: $showsGuide) {
            RealtimeGameGuideView(
                title: "棱镜裂隙 3D",
                subtitle: "穿越三维程序化隧道，管理舰体、护盾与能量，并击破三阶段裂隙守卫。",
                steps: [
                    .init(id: 1, icon: "move.3d", title: "左侧拖动航向", detail: "在左下控制区拖动，可同时改变水平和垂直位置。松手后飞船会平滑回稳。"),
                    .init(id: 2, icon: "bolt.fill", title: "按住 BOOST", detail: "加速能缩短普通航段，但会消耗能量。Boss 战期间能量会自动恢复。"),
                    .init(id: 3, icon: "scope", title: "对准核心开火", detail: "守卫出现后，拖动飞船贴近其移动核心并按住 FIRE；偏离准星不会造成伤害。"),
                    .init(id: 4, icon: "cross.case.fill", title: "识别补给", detail: "青色晶体恢复能量，绿色晶体修复舰体和护盾；红色地雷与紫色无人机需要规避。"),
                    .init(id: 5, icon: "sparkles", title: "击破三名守卫", detail: "每名守卫移动和攻击节奏不同。保留能量、维持连击，完成裂隙穿越。")
                ]
            )
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                controller.start()
            } else {
                controller.pause()
            }
        }
        .onChange(of: showsGuide) { presented in
            if presented {
                controller.pause()
            } else {
                controller.start()
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            hud
            Text(controller.message)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.42), in: Capsule())
            Spacer()
            HStack(alignment: .bottom) {
                Color.white.opacity(0.001)
                    .frame(width: 180, height: 190)
                    .contentShape(RoundedRectangle(cornerRadius: 28))
                    .overlay(alignment: .bottomLeading) {
                        Label("拖动航向", systemImage: "move.3d")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.64))
                            .padding(14)
                    }
                    .gesture(steeringGesture)
                Spacer()
                VStack(spacing: 12) {
                    holdButton(title: "BOOST", icon: "bolt.fill", color: .purple) { controller.setBoosting($0) }
                    holdButton(title: "FIRE", icon: "scope", color: .cyan) { controller.setFiring($0) }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var hud: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                valueBadge("得分", "\(controller.snapshot.score)", color: .cyan)
                valueBadge("波次", "\(controller.snapshot.wave)", color: .purple)
                Spacer()
                if let health = controller.snapshot.bossHealth {
                    valueBadge("守卫 HP", "\(Int(health.rounded()))", color: .pink)
                }
            }
            HStack(spacing: 7) {
                meter("舰体", controller.snapshot.hull, .green)
                meter("护盾", controller.snapshot.shield, .cyan)
                meter("能量", controller.snapshot.energy, .purple)
            }
            ProgressView(value: controller.snapshot.progress)
                .tint(.white)
                .accessibilityLabel("裂隙进度")
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
    }

    private var steeringGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let origin = controlOrigin ?? value.startLocation
                if controlOrigin == nil { controlOrigin = origin }
                controller.steer(
                    horizontal: Double((value.location.x - origin.x) / 72),
                    vertical: Double((origin.y - value.location.y) / 72)
                )
            }
            .onEnded { _ in
                controlOrigin = nil
                controller.releaseSteering()
            }
    }

    private func holdButton(title: String, icon: String, color: Color, action: @escaping (Bool) -> Void) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title2.bold())
            Text(title).font(.system(size: 9, weight: .black, design: .monospaced))
        }
        .foregroundColor(.white)
        .frame(width: 76, height: 64)
        .background(color.opacity(0.52), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.9), lineWidth: 1.2))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in action(true) }
                .onEnded { _ in action(false) }
        )
        .accessibilityLabel(title)
    }

    private func valueBadge(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.58))
            Text(value).font(.system(.caption, design: .monospaced).weight(.black)).foregroundColor(color)
        }
    }

    private func meter(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title) \(Int(value.rounded()))").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.7))
            GeometryReader { geometry in
                Capsule().fill(Color.white.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule().fill(color).frame(width: geometry.size.width * CGFloat(value / 100))
                    }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: controller.snapshot.outcome == .escaped ? "sparkles" : "exclamationmark.triangle.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(controller.snapshot.outcome == .escaped ? .cyan : .orange)
            Text(controller.snapshot.outcome == .escaped ? "裂隙穿越完成" : "舰体已失效")
                .font(.title2.bold()).foregroundColor(.white)
            Text("最终得分 \(controller.snapshot.score)")
                .font(.headline.monospacedDigit()).foregroundColor(.white.opacity(0.76))
            Button("生成新裂隙") { controller.restart(); controller.start() }
                .buttonStyle(.borderedProminent).tint(.cyan)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.cyan.opacity(0.34), lineWidth: 1))
    }
}
