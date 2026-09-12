import Foundation

struct ConnectionEventGate {
    private var connectedIDs: Set<UUID> = []

    mutating func markConnected(_ id: UUID) -> Bool {
        connectedIDs.insert(id).inserted
    }

    mutating func markDisconnected(_ id: UUID) -> Bool {
        connectedIDs.remove(id) != nil
    }

    mutating func drainConnectedIDs() -> [UUID] {
        let ids = Array(connectedIDs)
        connectedIDs.removeAll(keepingCapacity: false)
        return ids
    }

    var count: Int { connectedIDs.count }
}
