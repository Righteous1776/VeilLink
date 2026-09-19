import Foundation

extension TacticalV2 {
    enum WireKindV2: UInt8, Codable, Hashable, CaseIterable {
        case hello = 0
        case commitment = 1
        case reveal = 2
        case frameDigest = 3
    }

    struct CapabilitiesV2: Codable, Hashable {
        let rulesVersion: UInt16
        let scenarioVersion: UInt16
        let mapID: String
        let mapHash: UInt64
        let supportsWEGO: Bool
        let supportsRedactedIntel: Bool
        let supportsLargeMap: Bool

        static func guandu(map: Map) -> CapabilitiesV2 {
            CapabilitiesV2(
                rulesVersion: 2,
                scenarioVersion: 1,
                mapID: map.mapID,
                mapHash: map.stableMapHash64(),
                supportsWEGO: true,
                supportsRedactedIntel: true,
                supportsLargeMap: map.width == 48 && map.height == 27
            )
        }

        func isCompatible(with other: CapabilitiesV2) -> Bool {
            rulesVersion == other.rulesVersion
                && scenarioVersion == other.scenarioVersion
                && mapID == other.mapID
                && mapHash == other.mapHash
                && supportsWEGO
                && other.supportsWEGO
                && supportsRedactedIntel
                && other.supportsRedactedIntel
                && supportsLargeMap
                && other.supportsLargeMap
        }
    }

    struct WireEnvelopeV2: Codable, Hashable, Identifiable {
        static let currentVersion: UInt16 = 2

        let version: UInt16
        let sessionID: String
        let actionID: String
        let actor: Faction
        let turn: Int32
        let kind: WireKindV2
        let hello: CapabilitiesV2?
        let commitment: CommitmentV2?
        let reveal: RevealV2?
        let frameDigest: RuntimeFrameDigestV2?
        let createdAt: Date

        var id: String { actionID }

        init(
            sessionID: String,
            actionID: String = UUID().uuidString,
            actor: Faction,
            turn: Int32,
            kind: WireKindV2,
            hello: CapabilitiesV2? = nil,
            commitment: CommitmentV2? = nil,
            reveal: RevealV2? = nil,
            frameDigest: RuntimeFrameDigestV2? = nil,
            createdAt: Date = Date()
        ) {
            self.version = Self.currentVersion
            self.sessionID = sessionID
            self.actionID = actionID
            self.actor = actor
            self.turn = turn
            self.kind = kind
            self.hello = hello
            self.commitment = commitment
            self.reveal = reveal
            self.frameDigest = frameDigest
            self.createdAt = createdAt
        }

        static func makeHello(
            sessionID: String,
            actor: Faction,
            capabilities: CapabilitiesV2,
            createdAt: Date = Date()
        ) -> WireEnvelopeV2 {
            WireEnvelopeV2(
                sessionID: sessionID,
                actor: actor,
                turn: 0,
                kind: .hello,
                hello: capabilities,
                createdAt: createdAt
            )
        }

        static func makeCommitment(
            sessionID: String,
            value: CommitmentV2,
            createdAt: Date = Date()
        ) -> WireEnvelopeV2 {
            WireEnvelopeV2(
                sessionID: sessionID,
                actor: value.actor,
                turn: value.turn,
                kind: .commitment,
                commitment: value,
                createdAt: createdAt
            )
        }

        static func makeReveal(
            sessionID: String,
            value: RevealV2,
            createdAt: Date = Date()
        ) -> WireEnvelopeV2 {
            WireEnvelopeV2(
                sessionID: sessionID,
                actor: value.actor,
                turn: value.turn,
                kind: .reveal,
                reveal: value,
                createdAt: createdAt
            )
        }

        static func makeDigest(
            sessionID: String,
            actor: Faction,
            value: RuntimeFrameDigestV2,
            createdAt: Date = Date()
        ) -> WireEnvelopeV2 {
            WireEnvelopeV2(
                sessionID: sessionID,
                actor: actor,
                turn: value.turn,
                kind: .frameDigest,
                frameDigest: value,
                createdAt: createdAt
            )
        }

        func validate() -> Bool {
            guard version == Self.currentVersion,
                  UUID(uuidString: sessionID) != nil,
                  UUID(uuidString: actionID) != nil,
                  turn >= 0 else {
                return false
            }

            switch kind {
            case .hello:
                return hello != nil
                    && commitment == nil
                    && reveal == nil
                    && frameDigest == nil
                    && turn == 0

            case .commitment:
                return hello == nil
                    && commitment?.actor == actor
                    && commitment?.turn == turn
                    && reveal == nil
                    && frameDigest == nil

            case .reveal:
                return hello == nil
                    && commitment == nil
                    && reveal?.actor == actor
                    && reveal?.turn == turn
                    && frameDigest == nil

            case .frameDigest:
                return hello == nil
                    && commitment == nil
                    && reveal == nil
                    && frameDigest?.turn == turn
            }
        }
    }

    enum WireCodecV2 {
        static let prefix = "\u{2063}VLTW2:"

        static func encode(_ envelope: WireEnvelopeV2) throws -> String {
            guard envelope.validate() else {
                throw WireCodecErrorV2.invalidEnvelope
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let data = try encoder.encode(envelope)
            return prefix + data.base64EncodedString()
        }

        static func decode(_ body: String) -> WireEnvelopeV2? {
            guard body.hasPrefix(prefix) else { return nil }
            let encoded = String(body.dropFirst(prefix.count))
            guard let data = Data(base64Encoded: encoded) else { return nil }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            guard let envelope = try? decoder.decode(WireEnvelopeV2.self, from: data),
                  envelope.validate() else {
                return nil
            }
            return envelope
        }

        static func previewText(for envelope: WireEnvelopeV2) -> String {
            switch envelope.kind {
            case .hello:
                return "[三国兵棋] 战役 V2 协商"
            case .commitment:
                return "[三国兵棋] 第 \(envelope.turn + 1) 回合命令已锁定"
            case .reveal:
                return "[三国兵棋] 第 \(envelope.turn + 1) 回合命令已提交解析"
            case .frameDigest:
                return "[三国兵棋] 第 \(envelope.turn + 1) 回合状态已校验"
            }
        }
    }

    enum WireCodecErrorV2: Error, Equatable {
        case invalidEnvelope
    }
}

extension TacticalV2.Map {
    func stableMapHash64() -> UInt64 {
        var data = Data()

        func appendUInt16(_ value: UInt16) {
            var v = value.bigEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        func appendUInt32(_ value: UInt32) {
            var v = value.bigEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        func appendString(_ value: String) {
            let bytes = Data(value.utf8)
            appendUInt16(UInt16(bytes.count))
            data.append(bytes)
        }

        appendString(mapID)
        appendUInt16(UInt16(width))
        appendUInt16(UInt16(height))

        for cell in cells.sorted(by: { $0.index < $1.index }) {
            appendUInt32(UInt32(cell.index))
            appendString(cell.terrainCode)
            appendUInt32(UInt32(bitPattern: cell.movementCostMilli))
            appendUInt16(UInt16(bitPattern: cell.visionOpacityPermille))
            appendUInt16(UInt16(bitPattern: cell.supplyFactorPermille))
            appendUInt16(UInt16(bitPattern: cell.elevationBand))
            data.append(cell.road ? 1 : 0)
        }

        return TacticalV2.StableHash64.fnv1a(data)
    }
}
