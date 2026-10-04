import SpriteKit
import CoreImage
import UIKit
import simd

final class BlackoutDistrictScene: SKScene {
    var onSnapshot: ((BlackoutSnapshot) -> Void)?
    var onEvent: ((BlackoutEvent) -> Void)?

    private var state: BlackoutDistrictState
    private var input = BlackoutInput()
    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0

    private let worldRoot = SKNode()
    private let groundLayer = SKNode()
    private let roadLayer = SKNode()
    private let reflectionLayer = SKNode()
    private let buildingLayer = SKNode()
    private let lightBloom = SKEffectNode()
    private let gridLayer = SKNode()
    private let vehicleLayer = SKNode()
    private let weatherLayer = SKNode()
    private let effectLayer = SKNode()

    private let cameraNode = SKCameraNode()
    private let serviceTruck = SKNode()
    private let headlightCone = SKShapeNode()
    private let noiseOverlay = SKSpriteNode()
    private let lightningOverlay = SKShapeNode()
    private let repairRing = SKShapeNode(circleOfRadius: 82)

    private var nodeMarkers: [Int: SKNode] = [:]
    private var buildingWindows: [Int: [SKShapeNode]] = [:]
    private var districtGlowNodes: [Int: SKSpriteNode] = [:]
    private var gridEdgeNodes: [String: SKShapeNode] = [:]
    private var rainEmitter: SKEmitterNode?
    private var worldScale: CGFloat = 0.28

    init(seed: UInt64) {
        state = BlackoutDistrictState(seed: seed)
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = UIColor(
            red: 0.018,
            green: 0.025,
            blue: 0.038,
            alpha: 1
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var snapshot: BlackoutSnapshot {
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
            0.10,
            max(0, currentTime - lastUpdateTime)
        )
        lastUpdateTime = currentTime

        var catchup = 0

        while accumulator >= BlackoutDistrictState.fixedDelta,
              catchup < 6 {
            state.step(input: input)

            for event in state.events {
                handle(event: event)
            }

            accumulator -= BlackoutDistrictState.fixedDelta
            catchup += 1
        }

        if catchup == 6,
           accumulator >= BlackoutDistrictState.fixedDelta {
            accumulator = 0
        }

        updateVisuals()
        publishSnapshot()
    }

    func setDrive(
        throttle: Double,
        steering: Double
    ) {
        input.throttle = min(1, max(-1, throttle))
        input.steering = min(1, max(-1, steering))
    }

    func setRepairing(_ enabled: Bool) {
        input.repairing = enabled
    }

    func restart(seed: UInt64) {
        state = BlackoutDistrictState(seed: seed)
        input = BlackoutInput()
        lastUpdateTime = 0
        accumulator = 0

        nodeMarkers.removeAll()
        buildingWindows.removeAll()
        districtGlowNodes.removeAll()
        gridEdgeNodes.removeAll()

        worldRoot.removeAllChildren()
        configureWorldLayers()
        rebuildForSize()
        publishSnapshot()
    }

    private func configureHierarchy() {
        addChild(worldRoot)
        configureWorldLayers()

        addChild(weatherLayer)
        addChild(cameraNode)
        camera = cameraNode

        cameraNode.addChild(noiseOverlay)
        cameraNode.addChild(lightningOverlay)
    }

    private func configureWorldLayers() {
        [
            groundLayer,
            roadLayer,
            reflectionLayer,
            buildingLayer,
            lightBloom,
            gridLayer,
            vehicleLayer,
            effectLayer
        ].forEach {
            $0.removeAllChildren()
            worldRoot.addChild($0)
        }

        lightBloom.shouldRasterize = true

        if let bloom = CIFilter(
            name: "CIBloom"
        ) {
            bloom.setValue(
                9.0,
                forKey: kCIInputRadiusKey
            )

            bloom.setValue(
                0.82,
                forKey: kCIInputIntensityKey
            )

            lightBloom.filter = bloom
        }

        configureTruck()
        vehicleLayer.addChild(serviceTruck)
        vehicleLayer.addChild(repairRing)

        buildCity()
    }

    private func configureTruck() {
        serviceTruck.removeAllChildren()

        if let image = UIImage(
            named: "blackout_kenney_service_truck"
        ) {
            let sprite = SKSpriteNode(
                texture: SKTexture(image: image)
            )
            sprite.size = CGSize(
                width: 86,
                height: 46
            )
            serviceTruck.addChild(sprite)
        } else {
            let body = SKShapeNode(
                rectOf: CGSize(
                    width: 82,
                    height: 42
                ),
                cornerRadius: 9
            )

            body.fillColor = UIColor(
                red: 0.10,
                green: 0.33,
                blue: 0.42,
                alpha: 1
            )
            body.strokeColor =
                UIColor.cyan.withAlphaComponent(0.62)
            body.lineWidth = 1.4

            serviceTruck.addChild(body)

            let cabin = SKShapeNode(
                rectOf: CGSize(
                    width: 28,
                    height: 31
                ),
                cornerRadius: 7
            )

            cabin.position.x = 20
            cabin.fillColor = UIColor(
                red: 0.06,
                green: 0.15,
                blue: 0.19,
                alpha: 1
            )
            cabin.strokeColor =
                UIColor.white.withAlphaComponent(0.32)

            serviceTruck.addChild(cabin)
        }

        for x in [-27.0, 27.0] {
            let wheel = SKShapeNode(
                circleOfRadius: 8
            )
            wheel.position = CGPoint(
                x: x,
                y: -22
            )
            wheel.fillColor = UIColor(
                white: 0.04,
                alpha: 1
            )
            wheel.strokeColor = UIColor(
                white: 0.27,
                alpha: 1
            )
            serviceTruck.addChild(wheel)
        }

        let path = CGMutablePath()
        path.move(
            to: CGPoint(
                x: 35,
                y: 7
            )
        )
        path.addLine(
            to: CGPoint(
                x: 190,
                y: 52
            )
        )
        path.addLine(
            to: CGPoint(
                x: 190,
                y: -38
            )
        )
        path.closeSubpath()

        headlightCone.path = path
        headlightCone.fillColor = UIColor(
            red: 0.74,
            green: 0.88,
            blue: 1,
            alpha: 0.075
        )
        headlightCone.strokeColor = UIColor(
            red: 0.82,
            green: 0.93,
            blue: 1,
            alpha: 0.13
        )
        headlightCone.lineWidth = 0.8
        headlightCone.zPosition = -1

        serviceTruck.addChild(headlightCone)

        repairRing.strokeColor =
            UIColor.systemCyan.withAlphaComponent(0.80)
        repairRing.fillColor =
            UIColor.systemCyan.withAlphaComponent(0.025)
        repairRing.lineWidth = 2
        repairRing.glowWidth = 4
        repairRing.isHidden = true
    }

    private func rebuildForSize() {
        guard size.width > 1,
              size.height > 1 else {
            return
        }

        worldScale = max(
            0.22,
            min(
                0.42,
                min(
                    size.width / 1_050,
                    size.height / 1_300
                )
            )
        )

        worldRoot.setScale(
            worldScale
        )

        rebuildWeather()
        rebuildOverlays()
        updateVisuals()
    }

    private func buildCity() {
        buildGround()
        buildRoads()
        buildPuddles()
        buildDistricts()
        buildGridLines()
    }

    private func buildGround() {
        groundLayer.removeAllChildren()

        let ground = SKShapeNode(
            rectOf: CGSize(
                width: BlackoutDistrictState.worldWidth,
                height: BlackoutDistrictState.worldHeight
            )
        )

        ground.position = CGPoint(
            x: BlackoutDistrictState.worldWidth / 2,
            y: BlackoutDistrictState.worldHeight / 2
        )

        ground.fillColor = UIColor(
            red: 0.025,
            green: 0.035,
            blue: 0.044,
            alpha: 1
        )
        ground.strokeColor = .clear

        groundLayer.addChild(ground)
    }

    private func buildRoads() {
        roadLayer.removeAllChildren()

        for edge in state.edges {
            guard let a = state.nodes.first(
                where: { $0.id == edge.a }
            ),
            let b = state.nodes.first(
                where: { $0.id == edge.b }
            ) else {
                continue
            }

            let path = CGMutablePath()
            path.move(
                to: CGPoint(
                    x: a.x,
                    y: a.y
                )
            )
            path.addLine(
                to: CGPoint(
                    x: b.x,
                    y: b.y
                )
            )

            let road = SKShapeNode(
                path: path
            )
            road.strokeColor = UIColor(
                red: 0.075,
                green: 0.085,
                blue: 0.098,
                alpha: 1
            )
            road.lineWidth = 108
            road.lineCap = .round

            roadLayer.addChild(road)

            let lane = SKShapeNode(
                path: path
            )
            lane.strokeColor = UIColor(
                white: 0.38,
                alpha: 0.13
            )
            lane.lineWidth = 3

            roadLayer.addChild(lane)
        }
    }

    private func buildPuddles() {
        reflectionLayer.removeAllChildren()

        for puddle in state.puddles {
            let node = SKShapeNode(
                ellipseOf: CGSize(
                    width: puddle.radius * 2.0,
                    height: puddle.radius * 0.86
                )
            )

            node.position = CGPoint(
                x: puddle.x,
                y: puddle.y
            )

            node.fillColor = UIColor(
                red: 0.03,
                green: 0.11,
                blue: 0.16,
                alpha: 0.34
            )

            node.strokeColor = UIColor(
                red: 0.19,
                green: 0.44,
                blue: 0.52,
                alpha: 0.22
            )

            node.lineWidth = 1
            reflectionLayer.addChild(node)
        }
    }

    private func buildDistricts() {
        buildingLayer.removeAllChildren()
        lightBloom.removeAllChildren()
        nodeMarkers.removeAll()
        buildingWindows.removeAll()
        districtGlowNodes.removeAll()

        for node in state.nodes {
            let cluster = SKNode()
            cluster.position = CGPoint(
                x: node.x,
                y: node.y
            )

            let count = min(
                9,
                max(
                    5,
                    node.buildingCount / 2
                )
            )

            var windows: [SKShapeNode] = []

            for index in 0..<count {
                let angle =
                    Double(index) /
                    Double(max(1, count)) *
                    .pi * 2

                let radius =
                    120.0 +
                    Double(index % 3) * 34

                let x =
                    cos(angle) * radius

                let y =
                    sin(angle) * radius * 0.72

                let building = makeBuildingNode(
                    districtID: node.id,
                    buildingIndex: index
                )

                building.position = CGPoint(
                    x: x,
                    y: y
                )

                cluster.addChild(building)

                for window in building.children.compactMap(
                    { $0 as? SKShapeNode }
                )
                where window.name == "window" {
                    windows.append(window)
                }
            }

            buildingLayer.addChild(cluster)
            buildingWindows[node.id] = windows

            let marker = makeGridNodeMarker(
                node
            )
            marker.position = CGPoint(
                x: node.x,
                y: node.y
            )

            gridLayer.addChild(marker)
            nodeMarkers[node.id] = marker

            let glow =
                makeDistrictGlowNode(
                    nodeID: node.id
                )

            glow.position = CGPoint(
                x: node.x,
                y: node.y
            )

            lightBloom.addChild(glow)
            districtGlowNodes[node.id] = glow
        }
    }

    private func makeBuildingNode(
        districtID: Int,
        buildingIndex: Int
    ) -> SKNode {
        let root = SKNode()

        let textureName =
            buildingIndex % 3 == 0
            ? "blackout_kenney_commercial"
            : (
                districtID == 5
                ? "blackout_kenney_industrial"
                : "blackout_kenney_urban_building"
            )

        if let image = UIImage(
            named: textureName
        ) {
            let sprite = SKSpriteNode(
                texture: SKTexture(
                    image: image
                )
            )

            let width: CGFloat =
                86 +
                CGFloat(
                    deterministicVisual(
                        districtID,
                        buildingIndex,
                        salt: 41
                    )
                ) * 45

            sprite.size = CGSize(
                width: width,
                height: width * 0.86
            )

            root.addChild(sprite)

            for row in 0..<2 {
                for column in 0..<3 {
                    let window = SKShapeNode(
                        rectOf: CGSize(
                            width: 8,
                            height: 5
                        ),
                        cornerRadius: 1.5
                    )

                    window.name = "window"
                    window.position = CGPoint(
                        x: -18 + CGFloat(column) * 18,
                        y: -7 + CGFloat(row) * 15
                    )
                    window.fillColor = UIColor(
                        red: 1,
                        green: 0.72,
                        blue: 0.30,
                        alpha: 0.0
                    )
                    window.strokeColor = .clear
                    root.addChild(window)
                }
            }
        } else {
            let width =
                76 +
                CGFloat(
                    deterministicVisual(
                        districtID,
                        buildingIndex,
                        salt: 41
                    )
                ) * 54

            let height =
                66 +
                CGFloat(
                    deterministicVisual(
                        districtID,
                        buildingIndex,
                        salt: 57
                    )
                ) * 72

            let body = SKShapeNode(
                rectOf: CGSize(
                    width: width,
                    height: height
                ),
                cornerRadius: 8
            )

            body.fillColor = UIColor(
                red: 0.06,
                green: 0.075,
                blue: 0.09,
                alpha: 1
            )
            body.strokeColor = UIColor(
                white: 0.31,
                alpha: 0.17
            )
            body.lineWidth = 1

            root.addChild(body)

            let columns = 3
            let rows = max(
                2,
                Int(height / 24)
            )

            for row in 0..<rows {
                for column in 0..<columns {
                    let window = SKShapeNode(
                        rectOf: CGSize(
                            width: 8,
                            height: 5
                        ),
                        cornerRadius: 1.5
                    )

                    window.name = "window"

                    window.position = CGPoint(
                        x:
                            -width * 0.28 +
                            CGFloat(column) *
                            width * 0.28,
                        y:
                            -height * 0.32 +
                            CGFloat(row) *
                            15
                    )

                    window.fillColor =
                        UIColor(
                            red: 1,
                            green: 0.72,
                            blue: 0.30,
                            alpha: 0.0
                        )
                    window.strokeColor = .clear

                    root.addChild(window)
                }
            }
        }

        return root
    }

    private func makeGridNodeMarker(
        _ node: BlackoutGridNode
    ) -> SKNode {
        let root = SKNode()

        let ring = SKShapeNode(
            circleOfRadius:
                node.critical ? 33 : 27
        )

        ring.name = "ring"
        ring.fillColor = UIColor(
            red: 0.02,
            green: 0.08,
            blue: 0.10,
            alpha: 0.80
        )
        ring.strokeColor = UIColor(
            red: 0.23,
            green: 0.84,
            blue: 0.95,
            alpha: 0.50
        )
        ring.lineWidth = 2

        root.addChild(ring)

        let core = SKShapeNode(
            circleOfRadius: 7
        )

        core.name = "core"
        core.fillColor = .systemCyan
        core.strokeColor = .white
        core.lineWidth = 1
        core.glowWidth = 3

        root.addChild(core)

        return root
    }

    private func makeDistrictGlowNode(
        nodeID: Int
    ) -> SKSpriteNode {
        let sprite = SKSpriteNode(
            color: .white,
            size: CGSize(
                width: 280,
                height: 280
            )
        )

        sprite.alpha = 0
        sprite.blendMode = .add

        let shader =
            SKShader(
                fromFile:
                    "SHKRadialGradient"
            )

        shader.uniforms = [
            SKUniform(
                name: "u_first_color",
                color: UIColor(
                    red: 0.24,
                    green: 0.82,
                    blue: 1,
                    alpha: 0.36
                )
            ),
            SKUniform(
                name: "u_second_color",
                color: UIColor(
                    red: 0.05,
                    green: 0.24,
                    blue: 0.34,
                    alpha: 0.0
                )
            ),
            SKUniform(
                name: "u_center",
                vectorFloat2:
                    vector_float2(
                        0.5,
                        0.5
                    )
            )
        ]

        sprite.shader = shader
        return sprite
    }

    private func buildGridLines() {
        gridLayer.removeAllChildren()

        for node in state.nodes {
            if let marker =
                nodeMarkers[node.id] {
                gridLayer.addChild(
                    marker
                )
            }
        }

        gridEdgeNodes.removeAll()

        for edge in state.edges {
            guard let a = state.nodes.first(
                where: { $0.id == edge.a }
            ),
            let b = state.nodes.first(
                where: { $0.id == edge.b }
            ) else {
                continue
            }

            let path = CGMutablePath()
            path.move(
                to: CGPoint(
                    x: a.x,
                    y: a.y
                )
            )
            path.addLine(
                to: CGPoint(
                    x: b.x,
                    y: b.y
                )
            )

            let line = SKShapeNode(
                path: path
            )

            line.strokeColor = UIColor(
                red: 0.30,
                green: 0.08,
                blue: 0.08,
                alpha: 0.34
            )
            line.lineWidth = 5
            line.glowWidth = 1

            let key =
                edgeKey(
                    edge.a,
                    edge.b
                )

            gridLayer.addChild(line)
            gridEdgeNodes[key] = line
        }
    }

    private func rebuildWeather() {
        weatherLayer.removeAllChildren()
        rainEmitter = nil

        let rain = SKEmitterNode()
        rain.particleTexture =
            makeRainTexture()
        rain.particleBirthRate = 420
        rain.particleLifetime = 1.0
        rain.particleLifetimeRange = 0.26
        rain.position = CGPoint(
            x: size.width / 2,
            y: size.height + 20
        )
        rain.particlePositionRange =
            CGVector(
                dx: size.width * 1.6,
                dy: 24
            )
        rain.particleSpeed = 850
        rain.particleSpeedRange = 190
        rain.emissionAngle =
            -.pi / 2.10
        rain.emissionAngleRange = 0.05
        rain.particleAlpha = 0.31
        rain.particleScale = 0.86
        rain.particleColor = UIColor(
            red: 0.65,
            green: 0.80,
            blue: 0.94,
            alpha: 1
        )
        rain.particleColorBlendFactor = 1

        weatherLayer.addChild(rain)
        rainEmitter = rain
    }

    private func rebuildOverlays() {
        noiseOverlay.size = size
        noiseOverlay.position = .zero
        noiseOverlay.anchorPoint = CGPoint(
            x: 0.5,
            y: 0.5
        )
        noiseOverlay.color = UIColor(
            white: 0.08,
            alpha: 1
        )
        noiseOverlay.colorBlendFactor = 1
        noiseOverlay.alpha = 0.055
        noiseOverlay.blendMode = .add
        noiseOverlay.zPosition = 90
        noiseOverlay.shader =
            SKShader(
                fromFile:
                    "SHKDynamicGrayNoise"
            )

        let rect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )

        lightningOverlay.path =
            CGPath(
                rect: rect,
                transform: nil
            )
        lightningOverlay.fillColor = .white
        lightningOverlay.strokeColor = .clear
        lightningOverlay.alpha = 0
        lightningOverlay.blendMode = .add
        lightningOverlay.zPosition = 110
    }

    private func updateVisuals() {
        let snap = state.snapshot()

        updateCamera(
            snapshot: snap
        )
        updateTruck(
            snapshot: snap
        )
        updateGrid()
        updateBuildingLights()
        updateRepairRing(
            snapshot: snap
        )
        updateWeather(
            snapshot: snap
        )
        updateLightning(
            snapshot: snap
        )
    }

    private func updateCamera(
        snapshot: BlackoutSnapshot
    ) {
        let scenePoint = CGPoint(
            x:
                CGFloat(
                    snapshot.vehicleX
                ) * worldScale,
            y:
                CGFloat(
                    snapshot.vehicleY
                ) * worldScale
        )

        cameraNode.position = CGPoint(
            x: scenePoint.x,
            y: scenePoint.y
        )
    }

    private func updateTruck(
        snapshot: BlackoutSnapshot
    ) {
        serviceTruck.position = CGPoint(
            x:
                CGFloat(
                    snapshot.vehicleX
                ),
            y:
                CGFloat(
                    snapshot.vehicleY
                )
        )

        serviceTruck.zRotation =
            CGFloat(
                snapshot.heading
            )

        let intensity =
            CGFloat(
                0.45 +
                snapshot.gridStability * 0.45
            )

        headlightCone.alpha =
            intensity
    }

    private func updateGrid() {
        let nodeByID =
            Dictionary(
                uniqueKeysWithValues:
                    state.nodes.map {
                        ($0.id, $0)
                    }
            )

        for edge in state.edges {
            guard let a =
                    nodeByID[edge.a],
                  let b =
                    nodeByID[edge.b],
                  let line =
                    gridEdgeNodes[
                        edgeKey(
                            edge.a,
                            edge.b
                        )
                    ] else {
                continue
            }

            let powered =
                a.powered &&
                b.powered

            line.strokeColor =
                powered
                ? UIColor(
                    red: 0.18,
                    green: 0.78,
                    blue: 0.96,
                    alpha: 0.62
                )
                : UIColor(
                    red: 0.36,
                    green: 0.07,
                    blue: 0.07,
                    alpha: 0.31
                )

            line.glowWidth =
                powered ? 5 : 1
        }

        for node in state.nodes {
            guard let marker =
                    nodeMarkers[node.id] else {
                continue
            }

            let ring =
                marker.childNode(
                    withName: "ring"
                ) as? SKShapeNode

            let core =
                marker.childNode(
                    withName: "core"
                ) as? SKShapeNode

            if node.faulted {
                ring?.strokeColor =
                    .systemRed
                core?.fillColor =
                    .systemRed
                core?.glowWidth = 2
            } else if node.powered {
                ring?.strokeColor =
                    .systemCyan
                core?.fillColor =
                    node.critical
                    ? .systemYellow
                    : .systemCyan
                core?.glowWidth = 5
            } else {
                ring?.strokeColor =
                    UIColor(
                        white: 0.38,
                        alpha: 0.26
                    )
                core?.fillColor =
                    UIColor(
                        white: 0.20,
                        alpha: 1
                    )
                core?.glowWidth = 0
            }
        }
    }

    private func updateBuildingLights() {
        for node in state.nodes {
            let powered = node.powered
            let windows =
                buildingWindows[node.id] ??
                []

            for (
                index,
                window
            ) in windows.enumerated() {
                let on =
                    powered &&
                    (
                        index %
                        4 != 0 ||
                        node.critical
                    )

                window.fillColor =
                    on
                    ? UIColor(
                        red: 1,
                        green: 0.70,
                        blue: 0.25,
                        alpha: 0.72
                    )
                    : UIColor(
                        red: 0.08,
                        green: 0.09,
                        blue: 0.11,
                        alpha: 0.20
                    )
            }

            districtGlowNodes[
                node.id
            ]?.alpha =
                powered
                ? 0.46
                : 0.0
        }
    }

    private func updateRepairRing(
        snapshot: BlackoutSnapshot
    ) {
        guard let targetID =
                snapshot.repairTarget,
              let target =
                state.nodes.first(
                    where: {
                        $0.id == targetID
                    }
                ) else {
            repairRing.isHidden = true
            return
        }

        repairRing.isHidden = false
        repairRing.position = CGPoint(
            x: target.x,
            y: target.y
        )

        repairRing.setScale(
            CGFloat(
                0.72 +
                snapshot.repairProgress *
                0.42
            )
        )
    }

    private func updateWeather(
        snapshot: BlackoutSnapshot
    ) {
        rainEmitter?.particleBirthRate =
            CGFloat(
                310 +
                snapshot.storm * 260
            )

        noiseOverlay.alpha =
            CGFloat(
                0.035 +
                snapshot.storm * 0.055
            )
    }

    private func updateLightning(
        snapshot: BlackoutSnapshot
    ) {
        let period = 470
        let phase =
            Int(
                state.seed %
                UInt64(period)
            )

        guard snapshot.storm > 0.68,
              state.tick % period == phase,
              lightningOverlay.action(
                forKey: "blackout-lightning"
              ) == nil else {
            return
        }

        lightningOverlay.run(
            .sequence([
                .fadeAlpha(
                    to: 0.44,
                    duration: 0.025
                ),
                .fadeAlpha(
                    to: 0.05,
                    duration: 0.055
                ),
                .fadeAlpha(
                    to: 0.24,
                    duration: 0.035
                ),
                .fadeOut(
                    withDuration: 0.16
                )
            ]),
            withKey: "blackout-lightning"
        )
    }

    private func handle(
        event: BlackoutEvent
    ) {
        onEvent?(event)

        switch event.kind {
        case let .faulted(id):
            if let node =
                state.nodes.first(
                    where: {
                        $0.id == id
                    }
                ) {
                spawnFaultBurst(
                    at: CGPoint(
                        x: node.x,
                        y: node.y
                    )
                )
            }

        case let .repaired(id):
            if let node =
                state.nodes.first(
                    where: {
                        $0.id == id
                    }
                ) {
                spawnRepairBurst(
                    at: CGPoint(
                        x: node.x,
                        y: node.y
                    )
                )
            }

        case .gridCollapse:
            flash(
                color: .systemRed,
                peak: 0.24
            )

        case .stabilized:
            flash(
                color: .systemCyan,
                peak: 0.32
            )

        case .surge,
             .repairStarted,
             .districtPowered,
             .districtDarkened,
             .radio,
             .timeExpired:
            break
        }
    }

    private func spawnFaultBurst(
        at point: CGPoint
    ) {
        spawnBurst(
            at: point,
            color: .systemOrange,
            count: 32
        )
    }

    private func spawnRepairBurst(
        at point: CGPoint
    ) {
        spawnBurst(
            at: point,
            color: .systemCyan,
            count: 42
        )
    }

    private func spawnBurst(
        at point: CGPoint,
        color: UIColor,
        count: Int
    ) {
        let emitter = SKEmitterNode()
        emitter.position = point
        emitter.particleTexture =
            makeDotTexture(
                diameter: 6
            )
        emitter.particleBirthRate = 0
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = 0.72
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 65
        emitter.emissionAngleRange = .pi * 2
        emitter.particleAlpha = 0.90
        emitter.particleAlphaSpeed = -1.2
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add

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

    private func flash(
        color: UIColor,
        peak: CGFloat
    ) {
        lightningOverlay.fillColor = color
        lightningOverlay.removeAllActions()

        lightningOverlay.run(
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

    private func edgeKey(
        _ a: Int,
        _ b: Int
    ) -> String {
        a < b
        ? "\(a)-\(b)"
        : "\(b)-\(a)"
    }

    private func deterministicVisual(
        _ district: Int,
        _ index: Int,
        salt: UInt64
    ) -> Double {
        var z =
            state.seed ^
            UInt64(
                bitPattern:
                    Int64(
                        district * 257 +
                        index * 31
                    )
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

        return Double(
            z & 0xFFFF
        ) /
        Double(0xFFFF)
    }

    private func makeRainTexture() -> SKTexture {
        let image =
            UIGraphicsImageRenderer(
                size: CGSize(
                    width: 3,
                    height: 22
                )
            )
            .image { context in
                context.cgContext
                    .setFillColor(
                        UIColor.white
                            .withAlphaComponent(
                                0.90
                            )
                            .cgColor
                    )

                context.cgContext.fill(
                    CGRect(
                        x: 1,
                        y: 0,
                        width: 1,
                        height: 22
                    )
                )
            }

        return SKTexture(
            image: image
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
                UIColor.white
                    .setFill()

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
}
