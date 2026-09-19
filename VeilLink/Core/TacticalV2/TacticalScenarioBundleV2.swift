import Foundation

extension TacticalV2 {
    enum ScenarioBundleV2 {
        static let guanduResourceName = "guandu_large_map_v2_48x27"

        static func loadGuanduMap(bundle: Bundle = .main) throws -> Map {
            guard let url = bundle.url(
                forResource: guanduResourceName,
                withExtension: "json"
            ) else {
                throw ScenarioBundleErrorV2.missingResource(guanduResourceName)
            }

            let data = try Data(contentsOf: url)
            let asset = try LargeMapLoaderV2.decodeAsset(data: data)
            let map = LargeMapLoaderV2.runtimeMap(from: asset)

            guard map.width == 48,
                  map.height == 27,
                  map.cells.count == 1296 else {
                throw ScenarioBundleErrorV2.invalidMapDimensions
            }
            return map
        }
    }

    enum ScenarioBundleErrorV2: Error, Equatable {
        case missingResource(String)
        case invalidMapDimensions
    }
}
