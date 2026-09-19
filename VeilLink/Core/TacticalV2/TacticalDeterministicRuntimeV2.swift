import Foundation

extension TacticalV2 {
    struct TruthStateV2: Codable, Hashable {
        let scenarioID: String
        let mapID: String
        let rulesVersion: UInt16
        let scenarioVersion: UInt16
        let seed: UInt64
        var simulationTurn: Int32
        var rngIndex: UInt64
        var units: [Unit]
        var revision: Revision

        init(
            scenarioID: String,
            mapID: String,
            rulesVersion: UInt16,
            scenarioVersion: UInt16,
            seed: UInt64,
            simulationTurn: Int32 = 0,
            rngIndex: UInt64 = 0,
            units: [Unit],
            revision: Revision = .zero
        ) {
            self.scenarioID = scenarioID
            self.mapID = mapID
            self.rulesVersion = rulesVersion
            self.scenarioVersion = scenarioVersion
            self.seed = seed
            self.simulationTurn = simulationTurn
            self.rngIndex = rngIndex
            self.units = units
            self.revision = revision
        }

        func unitIndex(id: String) -> Int? {
            units.firstIndex { $0.id == id }
        }

        func unit(id: String) -> Unit? {
            units.first { $0.id == id }
        }

        func canonicalBytes() -> Data {
            var data = Data()

            func appendUInt8(_ v: UInt8) { data.append(v) }
            func appendUInt16(_ v: UInt16) {
                var x = v.bigEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            }
            func appendUInt32(_ v: UInt32) {
                var x = v.bigEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            }
            func appendUInt64(_ v: UInt64) {
                var x = v.bigEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            }
            func appendString(_ s: String) {
                let bytes = Data(s.utf8)
                precondition(bytes.count <= Int(UInt16.max))
                appendUInt16(UInt16(bytes.count))
                data.append(bytes)
            }

            data.append(Data("VLTSTATE2".utf8))
            appendString(scenarioID)
            appendString(mapID)
            appendUInt16(rulesVersion)
            appendUInt16(scenarioVersion)
            appendUInt64(seed)
            appendUInt32(UInt32(bitPattern: simulationTurn))
            appendUInt64(rngIndex)

            appendUInt64(revision.map)
            appendUInt64(revision.terrain)
            appendUInt64(revision.unit)
            appendUInt64(revision.supply)

            let sortedUnits = units.sorted { $0.id < $1.id }
            appendUInt16(UInt16(sortedUnits.count))
            for unit in sortedUnits {
                appendString(unit.id)
                appendUInt8(unit.faction.rawValue)
                appendUInt8(unit.kind.rawValue)
                appendUInt32(UInt32(unit.cell))
                appendUInt32(UInt32(bitPattern: Int32(unit.steps)))
            }
            return data
        }

        func stableHash64() -> UInt64 {
            StableHash64.fnv1a(canonicalBytes())
        }
    }

    enum DeterministicRNGV2 {
        static func value(seed: UInt64, index: UInt64, salt: UInt64 = 0) -> UInt64 {
            var x = seed &+ 0x9E3779B97F4A7C15 &* (index &+ 1)
            x ^= salt &+ 0xBF58476D1CE4E5B9
            x ^= x >> 30
            x &*= 0xBF58476D1CE4E5B9
            x ^= x >> 27
            x &*= 0x94D049BB133111EB
            x ^= x >> 31
            return x
        }

        static func bounded(seed: UInt64, index: UInt64, upperBound: UInt64, salt: UInt64 = 0) -> UInt64 {
            precondition(upperBound > 0)
            return value(seed: seed, index: index, salt: salt) % upperBound
        }
    }

    enum RuntimeEventKindV2: UInt8, Codable, Hashable {
        case unitAdvanced = 0
        case unitHeld = 1
        case contact = 2
        case blocked = 3
        case turnResolved = 4
    }

    struct RuntimeEventV2: Codable, Hashable, Identifiable {
        let sequence: UInt32
        let kind: RuntimeEventKindV2
        let actor: Faction?
        let unitID: String?
        let fromCell: Int?
        let toCell: Int?
        let publicCell: Int?
        let detailCode: UInt16

        var id: UInt32 { sequence }

        func canonicalBytes() -> Data {
            var data = Data()

            func appendUInt8(_ v: UInt8) { data.append(v) }
            func appendUInt16(_ v: UInt16) {
                var x = v.bigEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            }
            func appendUInt32(_ v: UInt32) {
                var x = v.bigEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            }
            func appendString(_ s: String?) {
                guard let s else {
                    appendUInt16(0)
                    return
                }
                let bytes = Data(s.utf8)
                appendUInt16(UInt16(bytes.count))
                data.append(bytes)
            }
            func appendCell(_ value: Int?) {
                if let value {
                    appendUInt8(1)
                    appendUInt32(UInt32(value))
                } else {
                    appendUInt8(0)
                }
            }

            data.append(Data("VLTEVT2".utf8))
            appendUInt32(sequence)
            appendUInt8(kind.rawValue)
            appendUInt8(actor?.rawValue ?? 0xFF)
            appendString(unitID)
            appendCell(fromCell)
            appendCell(toCell)
            appendCell(publicCell)
            appendUInt16(detailCode)
            return data
        }

        func stableHash64() -> UInt64 {
            StableHash64.fnv1a(canonicalBytes())
        }
    }

    struct RuntimeFrameV2: Codable, Hashable {
        let preStateHash: UInt64
        let orderBatchHash: UInt64
        let events: [RuntimeEventV2]
        let postStateHash: UInt64
        let resolvedTurn: Int32

        func canonicalBytes() -> Data {
            var data = Data("VLTFRAME2".utf8)
            func appendUInt64(_ v: UInt64) {
                var x = v.bigEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            }
            func appendUInt32(_ v: UInt32) {
                var x = v.bigEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            }

            appendUInt64(preStateHash)
            appendUInt64(orderBatchHash)
            appendUInt32(UInt32(bitPattern: resolvedTurn))
            appendUInt32(UInt32(events.count))
            for e in events {
                let bytes = e.canonicalBytes()
                appendUInt32(UInt32(bytes.count))
                data.append(bytes)
            }
            appendUInt64(postStateHash)
            return data
        }

        func stableHash64() -> UInt64 {
            StableHash64.fnv1a(canonicalBytes())
        }
    }
}
