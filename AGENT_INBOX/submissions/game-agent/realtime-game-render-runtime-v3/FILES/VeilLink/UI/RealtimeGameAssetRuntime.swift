import SpriteKit
import SceneKit
import UIKit

enum RealtimeGameVisualScene: String, Sendable {
    case rainline
    case signalDive
    case blackout
}

enum RealtimeGameLOD: String, Sendable {
    case motionReduced
    case standard
    case cinematic
}

struct RealtimeGameRenderProfile: Equatable, Sendable {
    let lod: RealtimeGameLOD
    let particleMultiplier: CGFloat
    let bloomMultiplier: CGFloat
    let noiseMultiplier: CGFloat
    let detailMultiplier: CGFloat
    let cameraScale: CGFloat

    static func resolve(
        sceneSize: CGSize,
        reduceMotion: Bool
    ) -> Self {
        if reduceMotion {
            return .init(
                lod: .motionReduced,
                particleMultiplier: 0.52,
                bloomMultiplier: 0.66,
                noiseMultiplier: 0.36,
                detailMultiplier: 0.78,
                cameraScale: 1.0
            )
        }

        let longEdge = max(
            sceneSize.width,
            sceneSize.height
        )

        if longEdge >= 900 {
            return .init(
                lod: .cinematic,
                particleMultiplier: 1.22,
                bloomMultiplier: 1.10,
                noiseMultiplier: 1.05,
                detailMultiplier: 1.18,
                cameraScale: 1.08
            )
        }

        return .init(
            lod: .standard,
            particleMultiplier: 1.0,
            bloomMultiplier: 1.0,
            noiseMultiplier: 1.0,
            detailMultiplier: 1.0,
            cameraScale: 1.0
        )
    }
}

enum RealtimeGameAssetID: String, CaseIterable, Sendable {
    case rainlineTrainCar
    case blackoutServiceTruck
    case blackoutCommercialBuilding
    case blackoutRoadStraight

    var imageAlias: String {
        switch self {
        case .rainlineTrainCar:
            return "rainline_kenney_train_car"
        case .blackoutServiceTruck:
            return "blackout_kenney_service_truck"
        case .blackoutCommercialBuilding:
            return "blackout_kenney_commercial"
        case .blackoutRoadStraight:
            return "blackout_kenney_road_straight"
        }
    }

    var modelResource: String {
        switch self {
        case .rainlineTrainCar:
            return "rainline_train_diesel_a.obj"
        case .blackoutServiceTruck:
            return "blackout_service_truck.obj"
        case .blackoutCommercialBuilding:
            return "blackout_commercial_low_a.obj"
        case .blackoutRoadStraight:
            return "blackout_road_straight.obj"
        }
    }

    var defaultBakeSize: CGSize {
        switch self {
        case .rainlineTrainCar:
            return CGSize(
                width: 360,
                height: 180
            )
        case .blackoutServiceTruck:
            return CGSize(
                width: 220,
                height: 150
            )
        case .blackoutCommercialBuilding:
            return CGSize(
                width: 220,
                height: 220
            )
        case .blackoutRoadStraight:
            return CGSize(
                width: 240,
                height: 180
            )
        }
    }

    var pitch: Float {
        switch self {
        case .rainlineTrainCar:
            return -0.18
        case .blackoutServiceTruck:
            return -0.72
        case .blackoutCommercialBuilding:
            return -0.58
        case .blackoutRoadStraight:
            return -0.92
        }
    }

    var yaw: Float {
        switch self {
        case .rainlineTrainCar:
            return -0.46
        case .blackoutServiceTruck:
            return -0.74
        case .blackoutCommercialBuilding:
            return -0.66
        case .blackoutRoadStraight:
            return -0.78
        }
    }
}

final class RealtimeGameAssetRuntime {
    private let imageCache =
        NSCache<NSString, UIImage>()

    private var urlCache:
        [String: URL] = [:]

    func image(
        named alias: String
    ) -> UIImage? {
        if let cached =
            imageCache.object(
                forKey: alias as NSString
            ) {
            return cached
        }

        guard let image =
                UIImage(
                    named: alias
                ) else {
            return nil
        }

        imageCache.setObject(
            image,
            forKey: alias as NSString
        )

        return image
    }

    func texture(
        for asset: RealtimeGameAssetID,
        targetSize: CGSize? = nil
    ) -> SKTexture? {
        if let image =
            image(
                named:
                    asset.imageAlias
            ) {
            let texture =
                SKTexture(
                    image: image
                )
            texture.filteringMode = .linear
            return texture
        }

        let size =
            targetSize ??
            asset.defaultBakeSize

        let cacheKey =
            [
                asset.rawValue,
                String(
                    Int(size.width)
                ),
                String(
                    Int(size.height)
                )
            ]
            .joined(
                separator: ":"
            )

        if let cached =
            imageCache.object(
                forKey:
                    cacheKey as NSString
            ) {
            let texture =
                SKTexture(
                    image: cached
                )
            texture.filteringMode = .linear
            return texture
        }

        guard let rendered =
                renderModel(
                    resource:
                        asset.modelResource,
                    size: size,
                    pitch:
                        asset.pitch,
                    yaw:
                        asset.yaw
                ) else {
            return nil
        }

        imageCache.setObject(
            rendered,
            forKey:
                cacheKey as NSString
        )

        let texture =
            SKTexture(
                image: rendered
            )
        texture.filteringMode = .linear
        return texture
    }

    func shader(
        named name: String
    ) -> SKShader? {
        guard let url =
                resourceURL(
                    named:
                        "\(name).fsh"
                ),
              let source =
                try? String(
                    contentsOf: url
                ) else {
            return nil
        }

        return SKShader(
            source: source
        )
    }

    func applyNightGrade(
        to sprite: SKSpriteNode,
        scene: RealtimeGameVisualScene,
        intensity: CGFloat = 1.0
    ) {
        let grade:
            (
                color: UIColor,
                blend: CGFloat
            )

        switch scene {
        case .rainline:
            grade = (
                UIColor(
                    red: 0.16,
                    green: 0.30,
                    blue: 0.47,
                    alpha: 1
                ),
                0.22
            )

        case .signalDive:
            grade = (
                UIColor(
                    red: 0.07,
                    green: 0.33,
                    blue: 0.39,
                    alpha: 1
                ),
                0.18
            )

        case .blackout:
            grade = (
                UIColor(
                    red: 0.10,
                    green: 0.24,
                    blue: 0.31,
                    alpha: 1
                ),
                0.20
            )
        }

        sprite.color =
            grade.color
        sprite.colorBlendFactor =
            min(
                0.34,
                max(
                    0,
                    grade.blend *
                    intensity
                )
            )
    }

    func clearCaches() {
        imageCache.removeAllObjects()
        urlCache.removeAll()
    }

    private func renderModel(
        resource: String,
        size: CGSize,
        pitch: Float,
        yaw: Float
    ) -> UIImage? {
        guard size.width > 1,
              size.height > 1,
              let url =
                resourceURL(
                    named: resource
                ),
              let source =
                SCNSceneSource(
                    url: url,
                    options: nil
                ),
              let loaded =
                try? source.scene(
                    options: nil
                ) else {
            return nil
        }

        let scene = SCNScene()
        let modelRoot = SCNNode()

        for child in
            loaded.rootNode
                .childNodes {
            modelRoot.addChildNode(
                child.clone()
            )
        }

        scene.rootNode.addChildNode(
            modelRoot
        )

        var minimum =
            SCNVector3Zero
        var maximum =
            SCNVector3Zero

        guard modelRoot
            .getBoundingBoxMin(
                &minimum,
                max: &maximum
            ) else {
            return nil
        }

        let width =
            max(
                0.001,
                maximum.x -
                minimum.x
            )
        let height =
            max(
                0.001,
                maximum.y -
                minimum.y
            )
        let depth =
            max(
                0.001,
                maximum.z -
                minimum.z
            )

        let center =
            SCNVector3(
                (minimum.x + maximum.x) *
                    0.5,
                (minimum.y + maximum.y) *
                    0.5,
                (minimum.z + maximum.z) *
                    0.5
            )

        modelRoot.pivot =
            SCNMatrix4MakeTranslation(
                center.x,
                center.y,
                center.z
            )
        modelRoot.eulerAngles =
            SCNVector3(
                pitch,
                yaw,
                0
            )

        let longest =
            max(
                width,
                max(
                    height,
                    depth
                )
            )

        let camera = SCNCamera()
        camera.usesOrthographicProjection =
            true
        camera.orthographicScale =
            Double(
                longest *
                1.44
            )
        camera.zNear = 0.01
        camera.zFar =
            Double(
                longest *
                12 +
                20
            )

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position =
            SCNVector3(
                0,
                0,
                longest * 3.4 + 2
            )
        scene.rootNode.addChildNode(
            cameraNode
        )

        let ambient =
            SCNLight()
        ambient.type = .ambient
        ambient.intensity = 560
        ambient.color =
            UIColor(
                red: 0.32,
                green: 0.39,
                blue: 0.48,
                alpha: 1
            )

        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(
            ambientNode
        )

        let key = SCNLight()
        key.type = .directional
        key.intensity = 1_100
        key.color =
            UIColor(
                red: 0.74,
                green: 0.88,
                blue: 1,
                alpha: 1
            )

        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles =
            SCNVector3(
                -0.82,
                -0.56,
                0
            )
        scene.rootNode.addChildNode(
            keyNode
        )

        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 520
        rim.color =
            UIColor(
                red: 0.35,
                green: 0.70,
                blue: 0.82,
                alpha: 1
            )

        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles =
            SCNVector3(
                0.48,
                2.25,
                0
            )
        scene.rootNode.addChildNode(
            rimNode
        )

        scene.background.contents =
            UIColor.clear

        let renderer =
            SCNRenderer(
                device: nil,
                options: nil
            )
        renderer.scene = scene
        renderer.pointOfView =
            cameraNode
        renderer.autoenablesDefaultLighting =
            false

        return renderer.snapshot(
            atTime: 0,
            with: size,
            antialiasingMode:
                .multisampling4X
        )
    }

    private func resourceURL(
        named fileName: String
    ) -> URL? {
        if let cached =
            urlCache[
                fileName
            ] {
            return cached
        }

        let ns =
            fileName as NSString
        let name =
            ns.deletingPathExtension
        let ext =
            ns.pathExtension

        if let direct =
            Bundle.main.url(
                forResource: name,
                withExtension:
                    ext.isEmpty
                    ? nil
                    : ext
            ) {
            urlCache[fileName] =
                direct
            return direct
        }

        guard let root =
                Bundle.main.resourceURL,
              let enumerator =
                FileManager.default
                    .enumerator(
                        at: root,
                        includingPropertiesForKeys:
                            nil,
                        options: [
                            .skipsHiddenFiles,
                            .skipsPackageDescendants
                        ]
                    ) else {
            return nil
        }

        for case let url as URL
            in enumerator {
            if url.lastPathComponent ==
                fileName {
                urlCache[fileName] =
                    url
                return url
            }
        }

        return nil
    }
}
