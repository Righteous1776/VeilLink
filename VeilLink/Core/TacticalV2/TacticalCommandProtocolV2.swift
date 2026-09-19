import Foundation

extension TacticalV2 {
    enum OrderKindV2: UInt8, Codable, CaseIterable, Hashable {
        case march = 0
        case forcedMarch = 1
        case recon = 2
        case hold = 3
        case attack = 4
        case probe = 5
        case pass = 6

        var isMovement: Bool {
            switch self {
            case .march, .forcedMarch, .recon, .attack, .probe:
                return true
            case .hold, .pass:
                return false
            }
        }
    }

    enum CommandValidationErrorV2: Error, Equatable {
        case invalidSchemaVersion
        case missingUnitID
        case unexpectedUnitID
        case invalidRouteLength
        case invalidCell
        case routeNotContiguous
        case routeContainsDuplicateStep
        case issuedTurnNegative
    }

    struct OrderV2: Codable, Hashable, Identifiable {
        static let schemaVersion: UInt16 = 2

        let id: String
        let kind: OrderKindV2
        let actor: Faction
        let issuedTurn: Int32
        let unitID: String?
        let routeCells: [UInt16]

        init(
            id: String,
            kind: OrderKindV2,
            actor: Faction,
            issuedTurn: Int32,
            unitID: String?,
            routeCells: [UInt16]
        ) {
            self.id = id
            self.kind = kind
            self.actor = actor
            self.issuedTurn = issuedTurn
            self.unitID = unitID
            self.routeCells = routeCells
        }

        func validate(map: Map) throws {
            guard issuedTurn >= 0 else { throw CommandValidationErrorV2.issuedTurnNegative }

            if kind == .pass {
                guard unitID == nil else { throw CommandValidationErrorV2.unexpectedUnitID }
                guard routeCells.isEmpty else { throw CommandValidationErrorV2.invalidRouteLength }
                return
            }

            guard let unitID, !unitID.isEmpty else {
                throw CommandValidationErrorV2.missingUnitID
            }

            if kind == .hold {
                guard routeCells.count == 1 else {
                    throw CommandValidationErrorV2.invalidRouteLength
                }
            } else {
                guard (2...64).contains(routeCells.count) else {
                    throw CommandValidationErrorV2.invalidRouteLength
                }
            }

            for value in routeCells {
                guard Int(value) < map.cells.count else {
                    throw CommandValidationErrorV2.invalidCell
                }
            }

            if routeCells.count >= 2 {
                for pair in zip(routeCells, routeCells.dropFirst()) {
                    let a = Int(pair.0)
                    let b = Int(pair.1)
                    guard a != b else {
                        throw CommandValidationErrorV2.routeContainsDuplicateStep
                    }
                    guard map.neighbors(of: a).contains(b) else {
                        throw CommandValidationErrorV2.routeNotContiguous
                    }
                }
            }
        }

        func canonicalBytes() -> Data {
            var data = Data()

            func appendUInt8(_ value: UInt8) {
                data.append(value)
            }

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
                precondition(bytes.count <= Int(UInt16.max))
                appendUInt16(UInt16(bytes.count))
                data.append(bytes)
            }

            data.append(Data("VLTORD2".utf8))
            appendUInt16(Self.schemaVersion)
            appendUInt8(kind.rawValue)
            appendUInt8(actor.rawValue)
            appendUInt32(UInt32(bitPattern: issuedTurn))
            appendString(id)

            if let unitID {
                appendUInt8(1)
                appendString(unitID)
            } else {
                appendUInt8(0)
            }

            appendUInt16(UInt16(routeCells.count))
            for cell in routeCells {
                appendUInt16(cell)
            }

            return data
        }

        func stableHash64() -> UInt64 {
            StableHash64.fnv1a(canonicalBytes())
        }
    }

    struct OrderBatchV2: Codable, Hashable {
        let orders: [OrderV2]

        func canonicalOrders() -> [OrderV2] {
            orders.sorted {
                if $0.actor.rawValue != $1.actor.rawValue {
                    return $0.actor.rawValue < $1.actor.rawValue
                }
                if $0.unitID != $1.unitID {
                    return ($0.unitID ?? "") < ($1.unitID ?? "")
                }
                if $0.kind.rawValue != $1.kind.rawValue {
                    return $0.kind.rawValue < $1.kind.rawValue
                }
                return $0.id < $1.id
            }
        }

        func canonicalBytes() -> Data {
            var data = Data("VLTBAT2".utf8)
            let sorted = canonicalOrders()
            var count = UInt16(sorted.count).bigEndian
            withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }

            for order in sorted {
                let bytes = order.canonicalBytes()
                var length = UInt32(bytes.count).bigEndian
                withUnsafeBytes(of: &length) { data.append(contentsOf: $0) }
                data.append(bytes)
            }
            return data
        }

        func stableHash64() -> UInt64 {
            StableHash64.fnv1a(canonicalBytes())
        }
    }

    enum LegacyTransportBridgeErrorV2: Error, Equatable {
        case requiresV2Transport
        case invalidRoute
        case unsupportedKind
    }

    struct LegacySingleStepMoveV2: Equatable {
        let from: Int
        let to: Int
    }

    enum LegacyTransportBridgeV2 {
        static func singleStep(
            order: OrderV2,
            currentCell: Int
        ) throws -> LegacySingleStepMoveV2? {
            if order.kind == .pass { return nil }
            guard order.kind == .march || order.kind == .attack || order.kind == .probe else {
                throw LegacyTransportBridgeErrorV2.unsupportedKind
            }
            guard order.routeCells.count >= 2 else {
                throw LegacyTransportBridgeErrorV2.invalidRoute
            }
            guard Int(order.routeCells[0]) == currentCell else {
                throw LegacyTransportBridgeErrorV2.invalidRoute
            }
            guard order.routeCells.count == 2 else {
                throw LegacyTransportBridgeErrorV2.requiresV2Transport
            }
            return LegacySingleStepMoveV2(
                from: currentCell,
                to: Int(order.routeCells[1])
            )
        }
    }
}
