import SpriteKit
import CoreImage
import UIKit

final class SignalDiveScene: SKScene {
    var onSnapshot: ((SignalDiveSnapshot) -> Void)?
    var onEvent: ((SignalDiveEvent) -> Void)?

    private var state: SignalDiveState
    private var input = SignalDiveInput()
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0

    private let cameraNode = SKCameraNode()
    private let abyssBack = SKNode()
    private let abyssMid = SKNode()
    private let terrainLayer = SKNode()
    private let biologicalLayer = SKNode()
    private let unknownLayer = SKNode()
    private let beaconLayer = SKNode()
    private let actorLayer = SKNode()
    private let particleLayer = SKNode()
    private let effectLayer = SKNode()

    private let submarineNode = SKNode()
    private let floodlightCone = SKShapeNode()
    private let floodlightBloom = SKEffectNode()
    private let fogOverlay = SKSpriteNode()
    private let pressureOverlay = SKShapeNode()
    private let flashOverlay = SKShapeNode()

    private var particulateEmitter: SKEmitterNode?
    private var obstacleNodes: [Int: SKNode] = [:]
    private var biologicalNodes: [Int: SKNode] = [:]
    private var beaconNodes: [Int: SKNode] = [:]
    private var unknownNodes: [Int: SKNode] = [:]
    private var reduceMotion = false
    private let assetRuntime =
        RealtimeGameAssetRuntime()

    private var renderProfile =
        RealtimeGameRenderProfile.resolve(
            sceneSize: CGSize(
                width: 390,
                height: 844
            ),
            reduceMotion: false
        )

    init(seed: UInt64) {
        state = SignalDiveState(seed: seed)
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(
            red: 0.006,
            green: 0.018,
            blue: 0.031,
            alpha: 1
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var snapshot: SignalDiveSnapshot {
        state.snapshot()
    }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60

        if children.isEmpty {
            configureHierarchy()
        }

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

        accumulator += min(
            0.11,
            max(
                0,
                currentTime - lastUpdateTime
            )
        )
        lastUpdateTime = currentTime

        var catchup = 0

        while accumulator >= SignalDiveState.fixedDelta,
              catchup < 6 {
            state.step(input: input)

            for event in state.events {
                handle(event: event)
            }

            input.sonarPulse = false
            accumulator -= SignalDiveState.fixedDelta
            catchup += 1
        }

        if catchup == 6,
           accumulator >= SignalDiveState.fixedDelta {
            accumulator = 0
        }

        updateVisuals()
        publishSnapshot()
    }

    func setThrust(
        x: Double,
        y: Double
    ) {
        input.thrustX = min(1, max(-1, x))
        input.thrustY = min(1, max(-1, y))
    }

    func triggerSonar() {
        input.sonarPulse = true
    }

    func setFloodlight(_ enabled: Bool) {
        input.floodlight = enabled
    }

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        renderProfile =
            RealtimeGameRenderProfile
                .resolve(
                    sceneSize: size,
                    reduceMotion:
                        reduceMotion
                )

        particulateEmitter?
            .particleBirthRate =
            78 *
            renderProfile
                .particleMultiplier
    }

    func restart(seed: UInt64) {
        state = SignalDiveState(seed: seed)
        input = SignalDiveInput()
        lastUpdateTime = 0
        accumulator = 0

        obstacleNodes.values.forEach {
            $0.removeFromParent()
        }
        biologicalNodes.values.forEach {
            $0.removeFromParent()
        }
        beaconNodes.values.forEach {
            $0.removeFromParent()
        }
        unknownNodes.values.forEach {
            $0.removeFromParent()
        }

        obstacleNodes.removeAll()
        biologicalNodes.removeAll()
        beaconNodes.removeAll()
        unknownNodes.removeAll()
        effectLayer.removeAllChildren()

        updateVisuals()
        publishSnapshot()
    }

    private func configureHierarchy() {
        [
            abyssBack,
            abyssMid,
            unknownLayer,
            terrainLayer,
            biologicalLayer,
            beaconLayer,
            actorLayer,
            particleLayer,
            effectLayer
        ].forEach(addChild)

        configureSubmarine()
        actorLayer.addChild(submarineNode)

        addChild(cameraNode)
        camera = cameraNode

        cameraNode.addChild(fogOverlay)
        cameraNode.addChild(pressureOverlay)
        cameraNode.addChild(flashOverlay)
    }

    private func configureSubmarine() {
        let hullPath = CGMutablePath()

        hullPath.move(
            to: CGPoint(
                x: 34,
                y: 0
            )
        )

        hullPath.addQuadCurve(
            to: CGPoint(
                x: -26,
                y: 15
            ),
            control: CGPoint(
                x: 8,
                y: 17
            )
        )

        hullPath.addLine(
            to: CGPoint(
                x: -39,
                y: 4
            )
        )

        hullPath.addLine(
            to: CGPoint(
                x: -39,
                y: -4
            )
        )

        hullPath.addQuadCurve(
            to: CGPoint(
                x: -26,
                y: -15
            ),
            control: CGPoint(
                x: 8,
                y: -17
            )
        )

        hullPath.closeSubpath()

        let hull = SKShapeNode(path: hullPath)
        hull.fillColor = UIColor(
            red: 0.18,
            green: 0.29,
            blue: 0.34,
            alpha: 1
        )
        hull.strokeColor =
            UIColor(
                red: 0.64,
                green: 0.85,
                blue: 0.89,
                alpha: 0.48
            )
        hull.lineWidth = 1.1

        submarineNode.addChild(hull)

        let cockpit = SKShapeNode(
            circleOfRadius: 7
        )
        cockpit.position = CGPoint(
            x: 9,
            y: 3
        )
        cockpit.fillColor = UIColor(
            red: 0.05,
            green: 0.19,
            blue: 0.24,
            alpha: 1
        )
        cockpit.strokeColor =
            UIColor.cyan.withAlphaComponent(0.55)

        submarineNode.addChild(cockpit)

        let lamp = SKShapeNode(
            circleOfRadius: 3.4
        )
        lamp.position = CGPoint(
            x: 31,
            y: 0
        )
        lamp.fillColor = UIColor(
            red: 0.72,
            green: 0.94,
            blue: 1,
            alpha: 1
        )
        lamp.strokeColor = .clear
        lamp.glowWidth = 5

        submarineNode.addChild(lamp)

        floodlightBloom.shouldRasterize = false

        if let bloom = CIFilter(
            name: "CIBloom"
        ) {
            bloom.setValue(
                10.0,
                forKey: kCIInputRadiusKey
            )
            bloom.setValue(
                0.78,
                forKey: kCIInputIntensityKey
            )
            floodlightBloom.filter = bloom
        }

        floodlightCone.fillColor =
            UIColor(
                red: 0.35,
                green: 0.80,
                blue: 0.92,
                alpha: 0.075
            )
        floodlightCone.strokeColor =
            UIColor(
                red: 0.48,
                green: 0.90,
                blue: 1,
                alpha: 0.14
            )
        floodlightCone.lineWidth = 0.8

        floodlightBloom.addChild(
            floodlightCone
        )

        submarineNode.addChild(
            floodlightBloom
        )
    }

    private func rebuildForSize() {
        guard size.width > 1,
              size.height > 1 else {
            return
        }

        renderProfile =
            RealtimeGameRenderProfile
                .resolve(
                    sceneSize: size,
                    reduceMotion:
                        reduceMotion
                )

        floodlightBloom.filter?
            .setValue(
                0.78 *
                renderProfile
                    .bloomMultiplier,
                forKey:
                    kCIInputIntensityKey
            )

        cameraNode.position = CGPoint(
            x: size.width / 2,
            y: size.height / 2
        )
        cameraNode.setScale(
            renderProfile.cameraScale
        )

        rebuildAbyss()
        rebuildParticles()
        rebuildOverlays()
        updateVisuals()
    }

    private func rebuildAbyss() {
        abyssBack.removeAllChildren()
        abyssMid.removeAllChildren()

        let top = SKSpriteNode(
            color: UIColor(
                red: 0.018,
                green: 0.055,
                blue: 0.078,
                alpha: 1
            ),
            size: CGSize(
                width: size.width * 1.5,
                height: size.height
            )
        )

        top.anchorPoint = CGPoint(
            x: 0.5,
            y: 0.5
        )
        top.position = CGPoint(
            x: size.width / 2,
            y: size.height / 2
        )

        abyssBack.addChild(top)

        for index in 0..<18 {
            let depthBand =
                CGFloat(index) / 17

            let silhouette = SKShapeNode(
                rectOf: CGSize(
                    width:
                        32 +
                        CGFloat(
                            procedural(
                                index: index,
                                salt: 31
                            )
                        ) * 110,
                    height:
                        80 +
                        CGFloat(
                            procedural(
                                index: index,
                                salt: 47
                            )
                        ) * 300
                ),
                cornerRadius: 18
            )

            silhouette.position = CGPoint(
                x:
                    -size.width * 0.35 +
                    CGFloat(index) *
                    size.width * 0.10,
                y:
                    size.height *
                    (
                        0.17 +
                        depthBand * 0.32
                    )
            )

            silhouette.zRotation =
                CGFloat(
                    procedural(
                        index: index,
                        salt: 59
                    ) - 0.5
                ) * 0.34

            silhouette.fillColor = UIColor(
                red: 0.01,
                green:
                    0.025 +
                    0.018 * depthBand,
                blue:
                    0.04 +
                    0.025 * depthBand,
                alpha: 0.42
            )
            silhouette.strokeColor = .clear

            abyssMid.addChild(
                silhouette
            )
        }
    }

    private func rebuildParticles() {
        particleLayer.removeAllChildren()

        let emitter = SKEmitterNode()

        emitter.particleTexture =
            makeDotTexture(
                diameter: 4
            )
        emitter.particleBirthRate =
            78 *
            renderProfile
                .particleMultiplier
        emitter.particleLifetime = 7.2
        emitter.particleLifetimeRange = 2.5
        emitter.particlePositionRange =
            CGVector(
                dx: size.width * 1.3,
                dy: size.height * 1.1
            )
        emitter.position = CGPoint(
            x: size.width / 2,
            y: size.height / 2
        )
        emitter.particleSpeed = 7
        emitter.particleSpeedRange = 7
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.23
        emitter.particleAlphaRange = 0.15
        emitter.particleScale = 0.45
        emitter.particleScaleRange = 0.35
        emitter.particleColor = UIColor(
            red: 0.62,
            green: 0.82,
            blue: 0.86,
            alpha: 1
        )
        emitter.particleColorBlendFactor = 1

        particleLayer.addChild(
            emitter
        )

        particulateEmitter = emitter
    }

    private func rebuildOverlays() {
        let rect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )

        fogOverlay.size = size
        fogOverlay.position = .zero
        fogOverlay.anchorPoint = CGPoint(
            x: 0.5,
            y: 0.5
        )
        fogOverlay.color = .white
        fogOverlay.colorBlendFactor = 0
        fogOverlay.zPosition = 90

        let fogShader = SKShader(
            source: Self.abyssFogShader
        )
        fogShader.uniforms = [
            SKUniform(
                name: "u_depth",
                float: 0.2
            ),
            SKUniform(
                name: "u_noise",
                float: 0.0
            ),
            SKUniform(
                name: "u_power",
                float: 1.0
            )
        ]
        fogOverlay.shader = fogShader

        pressureOverlay.path =
            CGPath(
                rect: rect,
                transform: nil
            )
        pressureOverlay.fillColor =
            UIColor(
                red: 0.01,
                green: 0.015,
                blue: 0.03,
                alpha: 1
            )
        pressureOverlay.strokeColor = .clear
        pressureOverlay.zPosition = 95

        flashOverlay.path =
            CGPath(
                rect: rect,
                transform: nil
            )
        flashOverlay.fillColor = .cyan
        flashOverlay.strokeColor = .clear
        flashOverlay.blendMode = .add
        flashOverlay.alpha = 0
        flashOverlay.zPosition = 120
    }

    private func updateVisuals() {
        let snap = state.snapshot()
        let screenX = size.width * 0.33

        let depthFraction = CGFloat(
            (
                snap.depth -
                SignalDiveState.minimumDepth
            ) /
            max(
                1,
                state.level.maxDepth -
                SignalDiveState.minimumDepth
            )
        )

        let screenY =
            size.height *
            (
                0.76 -
                depthFraction * 0.52
            )

        submarineNode.position = CGPoint(
            x: screenX,
            y: screenY
        )

        submarineNode.zRotation =
            CGFloat(
                snap.velocityY / 190
            )
            .clamped(
                to: -0.22...0.22
            )

        submarineNode.xScale =
            snap.velocityX < -1
            ? -1
            : 1

        updateFloodlight()
        updateParallax(
            snapshot: snap
        )
        updateWorldNodes(
            snapshot: snap,
            submarineX: screenX
        )
        updateMood(
            snapshot: snap
        )
    }

    private func updateFloodlight() {
        let enabled =
            input.floodlight &&
            state.power > 0

        let length: CGFloat =
            enabled ? 210 : 12
        let width: CGFloat =
            enabled ? 62 : 5

        let path = CGMutablePath()
        path.move(
            to: CGPoint(
                x: 28,
                y: 0
            )
        )
        path.addLine(
            to: CGPoint(
                x: 28 + length,
                y: width
            )
        )
        path.addLine(
            to: CGPoint(
                x: 28 + length,
                y: -width
            )
        )
        path.closeSubpath()

        floodlightCone.path = path

        floodlightBloom.alpha =
            enabled
            ? CGFloat(
                0.28 +
                state.power / 100 * 0.72
            )
            : 0.08
    }

    private func updateParallax(
        snapshot: SignalDiveSnapshot
    ) {
        let width = max(
            1,
            Double(size.width)
        )

        abyssBack.position.x =
            -CGFloat(
                (snapshot.x * 0.012)
                    .truncatingRemainder(
                        dividingBy: width
                    )
            )

        abyssMid.position.x =
            -CGFloat(
                (snapshot.x * 0.035)
                    .truncatingRemainder(
                        dividingBy: width
                    )
            )

        abyssMid.position.y =
            CGFloat(
                snapshot.depth * 0.025
            )
    }

    private func updateWorldNodes(
        snapshot: SignalDiveSnapshot,
        submarineX: CGFloat
    ) {
        let range = 1_050.0

        let visibleObstacles =
            state.level.obstacles.filter {
                abs(
                    $0.x -
                    snapshot.x
                ) <= range
            }

        let obstacleIDs =
            Set(
                visibleObstacles.map(
                    \.id
                )
            )

        for id in obstacleNodes.keys
        where !obstacleIDs.contains(id) {
            obstacleNodes
                .removeValue(forKey: id)?
                .removeFromParent()
        }

        for obstacle in visibleObstacles {
            let node =
                obstacleNodes[obstacle.id] ??
                {
                    let created =
                        makeObstacleNode(
                            obstacle
                        )
                    terrainLayer.addChild(
                        created
                    )
                    obstacleNodes[obstacle.id] =
                        created
                    return created
                }()

            node.position = mapWorld(
                x: obstacle.x,
                depth: obstacle.depth,
                snapshot: snapshot,
                submarineX: submarineX
            )
        }

        let visibleBeacons =
            state.level.beacons.filter {
                !state.recoveredBeaconIDs
                    .contains($0.id) &&
                abs(
                    $0.x -
                    snapshot.x
                ) <= range
            }

        let beaconIDs =
            Set(
                visibleBeacons.map(
                    \.id
                )
            )

        for id in beaconNodes.keys
        where !beaconIDs.contains(id) {
            beaconNodes
                .removeValue(forKey: id)?
                .removeFromParent()
        }

        for beacon in visibleBeacons {
            let node =
                beaconNodes[beacon.id] ??
                {
                    let created =
                        makeBeaconNode(
                            beacon
                        )
                    beaconLayer.addChild(
                        created
                    )
                    beaconNodes[beacon.id] =
                        created
                    return created
                }()

            node.position = mapWorld(
                x: beacon.x,
                depth: beacon.depth,
                snapshot: snapshot,
                submarineX: submarineX
            )
        }

        updateBiologicalSchools(
            snapshot: snapshot,
            submarineX: submarineX
        )

        updateUnknownSilhouettes(
            snapshot: snapshot,
            submarineX: submarineX
        )
    }

    private func updateBiologicalSchools(
        snapshot: SignalDiveSnapshot,
        submarineX: CGFloat
    ) {
        let contacts = state
            .sonarContacts(maxRange: 1_100)
            .compactMap { contact -> (Int, SignalDiveContact)? in
                guard case let .biological(id) = contact.kind else {
                    return nil
                }

                return (id, contact)
            }

        let wanted = Set(contacts.map { $0.0 })

        for id in biologicalNodes.keys
        where !wanted.contains(id) {
            biologicalNodes
                .removeValue(forKey: id)?
                .removeFromParent()
        }

        for (id, contact) in contacts {
            let node =
                biologicalNodes[id] ??
                {
                    let created =
                        makeBiologicalNode(
                            id: id
                        )
                    biologicalLayer.addChild(
                        created
                    )
                    biologicalNodes[id] =
                        created
                    return created
                }()

            let distanceScale =
                CGFloat(
                    contact.distance / 900
                )

            node.position = CGPoint(
                x:
                    submarineX +
                    cos(
                        CGFloat(
                            contact.bearing
                        )
                    ) *
                    distanceScale *
                    size.width,
                y:
                    submarineNode.position.y -
                    sin(
                        CGFloat(
                            contact.bearing
                        )
                    ) *
                    distanceScale *
                    size.height *
                    0.58
            )

            node.alpha =
                CGFloat(
                    0.20 +
                    max(
                        0,
                        1 -
                        contact.distance / 1_100
                    ) * 0.48
                )
        }
    }

    private func makeBiologicalNode(
        id: Int
    ) -> SKNode {
        let root = SKNode()

        for index in 0..<5 {
            let fish = SKNode()
            let alias =
                "signal_dive_kenney_fish_\((id + index) % 3 + 1)"

            if let image =
                assetRuntime.image(
                        named: alias
                    ) {
                let sprite =
                    SKSpriteNode(
                        texture:
                            SKTexture(
                                image: image
                            )
                    )

                sprite.size = CGSize(
                    width: 26,
                    height: 15
                )
                sprite.alpha = 0.72

                assetRuntime.applyNightGrade(
                        to: sprite,
                        scene:
                            .signalDive,
                        intensity: 0.72
                    )

                fish.addChild(
                    sprite
                )
            } else if let vector =
                SignalDiveKenneyVectorArt
                    .makeNode(
                        variant:
                            (id + index) % 2
                    ) {
                fish.addChild(
                    vector
                )
            } else {
                let body =
                    SKShapeNode(
                        ellipseOf:
                            CGSize(
                                width: 22,
                                height: 9
                            )
                    )

                body.fillColor =
                    UIColor(
                        red: 0.16,
                        green: 0.35,
                        blue: 0.38,
                        alpha: 0.42
                    )
                body.strokeColor =
                    UIColor.cyan
                        .withAlphaComponent(
                            0.08
                        )
                fish.addChild(
                    body
                )

                let tailPath =
                    CGMutablePath()
                tailPath.move(
                    to: CGPoint(
                        x: -10,
                        y: 0
                    )
                )
                tailPath.addLine(
                    to: CGPoint(
                        x: -18,
                        y: 6
                    )
                )
                tailPath.addLine(
                    to: CGPoint(
                        x: -18,
                        y: -6
                    )
                )
                tailPath.closeSubpath()

                let tail =
                    SKShapeNode(
                        path: tailPath
                    )
                tail.fillColor =
                    body.fillColor
                tail.strokeColor =
                    .clear
                fish.addChild(
                    tail
                )
            }

            fish.position = CGPoint(
                x:
                    CGFloat(
                        index - 2
                    ) * 18,
                y:
                    CGFloat(
                        (index % 2) * 2 - 1
                    ) * 9
            )

            fish.xScale =
                index % 2 == 0
                ? 1
                : -1

            root.addChild(
                fish
            )
        }

        return root
    }

    private func updateUnknownSilhouettes(
        snapshot: SignalDiveSnapshot,
        submarineX: CGFloat
    ) {
        let segment =
            Int(snapshot.x / 900)

        let wanted =
            Set(
                (
                    max(
                        1,
                        segment - 1
                    )
                )...(segment + 1)
            )

        for id in unknownNodes.keys
        where !wanted.contains(id) {
            unknownNodes
                .removeValue(forKey: id)?
                .removeFromParent()
        }

        for id in wanted
        where unknownNodes[id] == nil {
            let node =
                makeUnknownNode(id: id)

            unknownLayer.addChild(
                node
            )
            unknownNodes[id] = node
        }

        for id in wanted {
            guard let node =
                    unknownNodes[id] else {
                continue
            }

            let anchorX =
                Double(id) * 900 + 280

            let anchorDepth =
                680 +
                seededProcedural(
                    index: id,
                    salt: 0xD33F
                ) * 610

            var point = mapWorld(
                x: anchorX,
                depth: anchorDepth,
                snapshot: snapshot,
                submarineX: submarineX
            )

            point.x +=
                size.width * 0.13

            node.position = point
            node.alpha =
                CGFloat(
                    0.035 +
                    snapshot.noise * 0.08 +
                    snapshot.pressure * 0.03
                )
        }
    }

    private func mapWorld(
        x: Double,
        depth: Double,
        snapshot: SignalDiveSnapshot,
        submarineX: CGFloat
    ) -> CGPoint {
        let dx = x - snapshot.x
        let dy = depth - snapshot.depth

        return CGPoint(
            x:
                submarineX +
                CGFloat(dx / 900) *
                size.width,
            y:
                submarineNode.position.y -
                CGFloat(dy / 850) *
                size.height * 0.58
        )
    }

    private func makeObstacleNode(
        _ obstacle: SignalDiveObstacle
    ) -> SKNode {
        let root = SKNode()

        let radius =
            CGFloat(
                min(
                    58,
                    max(
                        24,
                        obstacle.radius * 0.48
                    )
                )
            )

        let rock = SKShapeNode(
            circleOfRadius: radius
        )
        rock.fillColor = UIColor(
            red: 0.025,
            green: 0.04,
            blue: 0.048,
            alpha: 0.98
        )
        rock.strokeColor = UIColor(
            red: 0.12,
            green: 0.22,
            blue: 0.24,
            alpha: 0.20
        )
        rock.lineWidth = 1.2
        rock.xScale = 1.4
        rock.yScale = 0.82

        root.addChild(rock)

        return root
    }

    private func makeBeaconNode(
        _ beacon: SignalDiveBeacon
    ) -> SKNode {
        let root = SKNode()

        let stem = SKShapeNode(
            rectOf: CGSize(
                width: 3,
                height: 28
            ),
            cornerRadius: 1.5
        )
        stem.position.y = -12
        stem.fillColor =
            UIColor(
                white: 0.42,
                alpha: 0.72
            )
        stem.strokeColor = .clear

        root.addChild(stem)

        let core = SKShapeNode(
            circleOfRadius: 6
        )
        core.fillColor =
            UIColor(
                red: 0.94,
                green: 0.57,
                blue: 0.21,
                alpha: 1
            )
        core.strokeColor =
            UIColor.white
                .withAlphaComponent(0.72)
        core.glowWidth = 5

        root.addChild(core)

        core.run(
            .repeatForever(
                .sequence([
                    .fadeAlpha(
                        to: 0.45,
                        duration: 0.72
                    ),
                    .fadeAlpha(
                        to: 1.0,
                        duration: 0.72
                    )
                ])
            )
        )

        return root
    }

    private func makeUnknownNode(
        id: Int
    ) -> SKNode {
        let root = SKNode()

        let width: CGFloat =
            210 +
            CGFloat(
                procedural(
                    index: id,
                    salt: 77
                )
            ) * 180

        let height: CGFloat =
            46 +
            CGFloat(
                procedural(
                    index: id,
                    salt: 93
                )
            ) * 55

        let body = SKShapeNode(
            ellipseOf: CGSize(
                width: width,
                height: height
            )
        )

        body.fillColor = UIColor(
            red: 0.005,
            green: 0.012,
            blue: 0.018,
            alpha: 1
        )
        body.strokeColor =
            UIColor.cyan
                .withAlphaComponent(0.015)

        root.addChild(body)

        for finIndex in 0..<3 {
            let fin =
                SKShapeNode(
                    roundedRectOf:
                        CGSize(
                            width:
                                width * 0.24,
                            height:
                                5 +
                                CGFloat(
                                    finIndex
                                ) * 2
                        ),
                    cornerRadius: 3
                )

            fin.position = CGPoint(
                x:
                    -width * 0.12 +
                    CGFloat(finIndex) *
                    width * 0.14,
                y:
                    -height * 0.42 -
                    CGFloat(finIndex) * 5
            )

            fin.zRotation =
                -0.22 +
                CGFloat(finIndex) * 0.17

            fin.fillColor =
                body.fillColor
            fin.strokeColor = .clear

            root.addChild(fin)
        }

        return root
    }

    private func updateMood(
        snapshot: SignalDiveSnapshot
    ) {
        fogOverlay.shader?
            .uniformNamed("u_depth")?
            .floatValue =
            Float(snapshot.pressure)

        fogOverlay.shader?
            .uniformNamed("u_noise")?
            .floatValue =
            Float(snapshot.noise)

        fogOverlay.shader?
            .uniformNamed("u_power")?
            .floatValue =
            Float(
                snapshot.power / 100
            )

        pressureOverlay.alpha =
            CGFloat(
                max(
                    0,
                    snapshot.pressure - 0.30
                )
            ) * 0.19

        particulateEmitter?
            .particleBirthRate =
            CGFloat(
                66 +
                snapshot.pressure *
                70
            ) *
            renderProfile
                .particleMultiplier
    }

    private func handle(
        event: SignalDiveEvent
    ) {
        onEvent?(event)

        switch event.kind {
        case let .sonar(contacts):
            spawnSonarPulse(
                contacts: contacts
            )

        case .beaconRecovered:
            spawnRecoveryFlash()

        case .impact:
            spawnImpactBurst()
            shakeCamera()

        case .radio:
            break

        case .surfaced:
            flash(
                color: .white,
                peak: 0.32
            )

        case .hullFailure:
            flash(
                color: .systemRed,
                peak: 0.24
            )

        case .powerLoss:
            floodlightBloom.run(
                .fadeAlpha(
                    to: 0.02,
                    duration: 0.7
                )
            )
        }
    }

    private func spawnSonarPulse(
        contacts: [SignalDiveContact]
    ) {
        let ring = SKShapeNode(
            circleOfRadius: 24
        )

        ring.position =
            submarineNode.position
        ring.strokeColor = UIColor(
            red: 0.25,
            green: 0.90,
            blue: 1,
            alpha: 0.85
        )
        ring.lineWidth = 1.4
        ring.glowWidth = 4
        ring.fillColor = .clear

        effectLayer.addChild(ring)

        ring.run(
            .sequence([
                .group([
                    .scale(
                        to: 12.0,
                        duration: 1.15
                    ),
                    .fadeOut(
                        withDuration: 1.15
                    )
                ]),
                .removeFromParent()
            ])
        )

        for (
            index,
            contact
        ) in contacts.prefix(12).enumerated() {
            let normalized =
                CGFloat(
                    min(
                        1,
                        contact.distance / 760
                    )
                )

            let distance =
                normalized *
                min(
                    size.width,
                    size.height
                ) * 0.42

            let point = CGPoint(
                x:
                    submarineNode.position.x +
                    cos(
                        CGFloat(
                            contact.bearing
                        )
                    ) * distance,
                y:
                    submarineNode.position.y -
                    sin(
                        CGFloat(
                            contact.bearing
                        )
                    ) * distance
            )

            let blip = SKShapeNode(
                circleOfRadius:
                    contactRadius(
                        contact.kind
                    )
            )

            blip.position = point
            blip.fillColor =
                contactColor(
                    contact.kind
                )
                .withAlphaComponent(0.06)
            blip.strokeColor =
                contactColor(
                    contact.kind
                )
                .withAlphaComponent(0.82)
            blip.lineWidth = 1
            blip.glowWidth = 3
            blip.alpha = 0

            effectLayer.addChild(blip)

            blip.run(
                .sequence([
                    .wait(
                        forDuration:
                            Double(index) * 0.025 +
                            Double(normalized) * 0.22
                    ),
                    .fadeIn(
                        withDuration: 0.06
                    ),
                    .wait(
                        forDuration: 0.55
                    ),
                    .fadeOut(
                        withDuration: 0.38
                    ),
                    .removeFromParent()
                ])
            )
        }

        flash(
            color: .cyan,
            peak: 0.08
        )
    }

    private func contactRadius(
        _ kind: SignalDiveContact.Kind
    ) -> CGFloat {
        switch kind {
        case .terrain:
            return 4

        case .beacon:
            return 6

        case .biological:
            return 8

        case .massiveUnknown:
            return 16
        }
    }

    private func contactColor(
        _ kind: SignalDiveContact.Kind
    ) -> UIColor {
        switch kind {
        case .terrain:
            return UIColor(
                red: 0.30,
                green: 0.73,
                blue: 0.82,
                alpha: 1
            )

        case .beacon:
            return .systemOrange

        case .biological:
            return UIColor(
                red: 0.32,
                green: 0.86,
                blue: 0.62,
                alpha: 1
            )

        case .massiveUnknown:
            return UIColor(
                red: 0.40,
                green: 0.92,
                blue: 1,
                alpha: 1
            )
        }
    }

    private func spawnRecoveryFlash() {
        let emitter =
            makeBurstEmitter(
                color: .systemOrange,
                count: 32
            )

        emitter.position =
            submarineNode.position

        effectLayer.addChild(
            emitter
        )

        emitter.run(
            .sequence([
                .wait(
                    forDuration: 1.0
                ),
                .removeFromParent()
            ])
        )
    }

    private func spawnImpactBurst() {
        let emitter =
            makeBurstEmitter(
                color: .systemCyan,
                count: 38
            )

        emitter.position =
            submarineNode.position

        effectLayer.addChild(
            emitter
        )

        emitter.run(
            .sequence([
                .wait(
                    forDuration: 1.0
                ),
                .removeFromParent()
            ])
        )
    }

    private func makeBurstEmitter(
        color: UIColor,
        count: Int
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()

        emitter.particleTexture =
            makeDotTexture(
                diameter: 6
            )
        emitter.particleBirthRate = 0
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = 0.72
        emitter.particleSpeed = 105
        emitter.particleSpeedRange = 64
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.1
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add

        return emitter
    }

    private func shakeCamera() {
        guard !reduceMotion else { return }

        let amplitude: CGFloat = 6

        cameraNode.removeAction(
            forKey: "dive-shake"
        )

        cameraNode.run(
            .sequence([
                .moveBy(
                    x: amplitude,
                    y: -amplitude * 0.4,
                    duration: 0.025
                ),
                .moveBy(
                    x: -amplitude * 1.5,
                    y: amplitude * 0.7,
                    duration: 0.035
                ),
                .moveBy(
                    x: amplitude * 0.5,
                    y: -amplitude * 0.3,
                    duration: 0.045
                )
            ]),
            withKey: "dive-shake"
        )
    }

    private func flash(
        color: UIColor,
        peak: CGFloat
    ) {
        flashOverlay.fillColor = color
        flashOverlay.removeAllActions()

        flashOverlay.run(
            .sequence([
                .fadeAlpha(
                    to: peak,
                    duration: 0.025
                ),
                .fadeOut(
                    withDuration: 0.18
                )
            ])
        )
    }

    private func publishSnapshot() {
        onSnapshot?(
            state.snapshot()
        )
    }

    private func makeDotTexture(
        diameter: CGFloat
    ) -> SKTexture {
        let image =
            UIGraphicsImageRenderer(
                size: CGSize(
                    width: diameter,
                    height: diameter
                )
            )
            .image { _ in
                UIColor.white.setFill()

                UIBezierPath(
                    ovalIn: CGRect(
                        x: 0,
                        y: 0,
                        width: diameter,
                        height: diameter
                    )
                )
                .fill()
            }

        return SKTexture(
            image: image
        )
    }

    private func seededProcedural(
        index: Int,
        salt: UInt64
    ) -> Double {
        var z =
            state.seed ^
            UInt64(
                bitPattern:
                    Int64(index)
            ) ^
            salt

        z &+= 0x9E3779B97F4A7C15
        z =
            (z ^ (z >> 30)) &*
            0xBF58476D1CE4E5B9
        z =
            (z ^ (z >> 27)) &*
            0x94D049BB133111EB
        z ^= z >> 31

        return Double(z & 0xFFFF) /
            Double(0xFFFF)
    }

    private func procedural(
        index: Int,
        salt: UInt64
    ) -> Double {
        var z =
            UInt64(
                bitPattern:
                    Int64(index)
            ) +
            salt &*
            0x9E3779B97F4A7C15

        z ^= z >> 30
        z &*= 0xBF58476D1CE4E5B9
        z ^= z >> 27
        z &*= 0x94D049BB133111EB
        z ^= z >> 31

        return Double(z & 0xFFFF) /
            Double(0xFFFF)
    }

    private static let abyssFogShader = """
    float hash21(vec2 p) {
        p = fract(
            p * vec2(
                123.34,
                456.21
            )
        );

        p += dot(
            p,
            p + 45.32
        );

        return fract(
            p.x * p.y
        );
    }

    void main() {
        vec2 uv =
            v_tex_coord;

        float depth =
            clamp(
                u_depth,
                0.0,
                1.35
            );

        float noise =
            u_noise;

        float power =
            u_power;

        vec2 grid =
            uv *
            vec2(
                7.0,
                13.0
            );

        vec2 id =
            floor(grid);

        vec2 gv =
            fract(grid);

        float n =
            hash21(
                id +
                floor(
                    u_time * 0.06
                )
            );

        float drift =
            sin(
                (
                    gv.y + n
                ) * 6.28318 +
                u_time *
                (
                    0.08 +
                    n * 0.06
                )
            );

        float fog =
            0.07 +
            depth * 0.18;

        fog +=
            smoothstep(
                0.2,
                1.0,
                gv.y
            ) * 0.035;

        fog +=
            drift * 0.012;

        fog +=
            noise * 0.025;

        vec3 shallow =
            vec3(
                0.02,
                0.11,
                0.15
            );

        vec3 deep =
            vec3(
                0.004,
                0.012,
                0.025
            );

        vec3 cold =
            mix(
                shallow,
                deep,
                clamp(
                    depth,
                    0.0,
                    1.0
                )
            );

        cold +=
            vec3(
                0.01,
                0.03,
                0.04
            ) * power;

        gl_FragColor =
            vec4(
                cold,
                clamp(
                    fog,
                    0.0,
                    0.42
                )
            );
    }
    """
}

private extension CGFloat {
    func clamped(
        to range: ClosedRange<CGFloat>
    ) -> CGFloat {
        min(
            range.upperBound,
            max(
                range.lowerBound,
                self
            )
        )
    }
}
