import Foundation

extension TacticalV2 {
    enum PublicMessageKindV2: UInt8, Codable, Hashable {
        case commitment = 0
        case reveal = 1
        case redactedObservation = 2
        case runtimeFrameDigest = 3
    }

    struct PublicCommitmentMessageV2: Codable, Hashable {
        let sessionID: String
        let turn: Int32
        let commitment: CommitmentV2
    }

    struct PublicRevealMessageV2: Codable, Hashable {
        let sessionID: String
        let turn: Int32
        let reveal: RevealV2

        // IMPORTANT:
        // A reveal contains the committed order batch. This prevents "wait to see opponent,
        // then change my order" in the normal client, but it is NOT endpoint secrecy.
        // A modified peer can inspect the revealed route after commitment lock.
    }

    struct RuntimeFrameDigestV2: Codable, Hashable {
        let turn: Int32
        let preStateHash: UInt64
        let orderBatchHash: UInt64
        let postStateHash: UInt64
        let frameHash: UInt64
    }

    enum PrivacyBoundaryV2 {
        static let guaranteesEndpointSecrecy = false
        static let guaranteesTransportConfidentialityWhenWrappedByVeilLinkE2EE = true
        static let preventsPostCommitOrderEditingInNormalClient = true

        static func digest(_ frame: RuntimeFrameV2) -> RuntimeFrameDigestV2 {
            RuntimeFrameDigestV2(
                turn: frame.resolvedTurn,
                preStateHash: frame.preStateHash,
                orderBatchHash: frame.orderBatchHash,
                postStateHash: frame.postStateHash,
                frameHash: frame.stableHash64()
            )
        }
    }
}
