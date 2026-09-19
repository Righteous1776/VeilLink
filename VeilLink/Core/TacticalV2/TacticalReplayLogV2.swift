import Foundation

extension TacticalV2 {
    struct ReplayLogV2: Codable, Hashable {
        let scenarioID: String
        let mapID: String
        let rulesVersion: UInt16
        let scenarioVersion: UInt16
        let seed: UInt64
        private(set) var frames: [RuntimeFrameV2] = []

        init(
            scenarioID: String,
            mapID: String,
            rulesVersion: UInt16,
            scenarioVersion: UInt16,
            seed: UInt64
        ) {
            self.scenarioID = scenarioID
            self.mapID = mapID
            self.rulesVersion = rulesVersion
            self.scenarioVersion = scenarioVersion
            self.seed = seed
        }

        mutating func append(_ frame: RuntimeFrameV2) throws {
            if let last = frames.last {
                guard last.postStateHash == frame.preStateHash else {
                    throw ReplayErrorV2.brokenHashChain
                }
            }
            frames.append(frame)
        }

        func stableHash64() -> UInt64 {
            var data = Data("VLTREPLAY2".utf8)
            func appendUInt64(_ value: UInt64) {
                var x = value.bigEndian
                withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
            }
            appendUInt64(seed)
            for frame in frames {
                appendUInt64(frame.stableHash64())
            }
            return StableHash64.fnv1a(data)
        }
    }

    enum ReplayErrorV2: Error, Equatable {
        case brokenHashChain
    }
}
