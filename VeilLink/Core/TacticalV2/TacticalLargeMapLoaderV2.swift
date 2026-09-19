import Foundation

extension TacticalV2 {
    struct LargeMapAssetV2: Decodable {
        struct LogicSubstrate: Decodable {
            let kind: String
            let width: Int
            let height: Int
            let cells: Int
            let visible_grid: Bool
        }

        struct AssetCell: Decodable {
            let index: Int
            let row: Int
            let col: Int
            let center: [Double]
            let terrain: String
            let region: String?
            let road: Bool
            let water_pressure: Bool
            let move_cost: Double
            let vision_obscurity: Double
            let supply_factor: Double
        }

        let map_id: String
        let display_name: String
        let logic_substrate: LogicSubstrate
        let cells: [AssetCell]
    }

    enum LargeMapLoaderV2 {
        static func decodeAsset(data: Data) throws -> LargeMapAssetV2 {
            try JSONDecoder().decode(LargeMapAssetV2.self, from: data)
        }

        static func runtimeMap(from asset: LargeMapAssetV2) -> Map {
            let width = asset.logic_substrate.width
            let height = asset.logic_substrate.height
            let cells = asset.cells.sorted { $0.index < $1.index }.map { cell in
                Cell(
                    index: cell.index,
                    row: cell.row,
                    col: cell.col,
                    terrainCode: cell.terrain,
                    movementCostMilli: Int32(max(1, (cell.move_cost * 1000.0).rounded())),
                    visionOpacityPermille: Int16(max(0, min(1000, Int((cell.vision_obscurity * 1000.0).rounded())))),
                    supplyFactorPermille: Int16(max(100, min(2000, Int((cell.supply_factor * 1000.0).rounded())))),
                    elevationBand: 0,
                    road: cell.road
                )
            }

            return Map(
                mapID: asset.map_id,
                width: width,
                height: height,
                cells: cells
            )
        }
    }
}
