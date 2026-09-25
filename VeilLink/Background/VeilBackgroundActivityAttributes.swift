import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct VeilBackgroundActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var mode: String
        var connectedBLEPeers: Int
        var connectedLANPeers: Int
        var meshNeighbors: Int
        var updatedAt: Date
    }

    let instanceID: String
}
#endif
