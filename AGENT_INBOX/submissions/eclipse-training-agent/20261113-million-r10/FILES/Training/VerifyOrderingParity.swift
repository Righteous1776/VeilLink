import Foundation

/// Reads private fixtures on stdin; never writes real board data to the Inbox.
@main
struct VerifyOrderingParity {
    static func main() throws {
        while let line = readLine() {
            let item = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [String: Any]
            let cells = (item["cells"] as! [Int]).map { UInt8($0) }
            let index = item["index"] as! Int, side = UInt8(item["side"] as! Int)
            let features = EclipseTrainedOrdering.features(cells: cells, index: index, side: side)
            let result: [String: Any] = [
                "features": features,
                "prediction": EclipseTrainedOrdering.rawPrediction(features),
                "score": EclipseTrainedOrdering.score(cells: cells, index: index, side: side)
            ]
            let output = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            print(String(decoding: output, as: UTF8.self))
        }
    }
}
