import Foundation

extension TacticalV2 {
    enum IntelLevel: UInt8, Codable, Hashable, Comparable, CaseIterable {
        case unknown = 0
        case suspected = 1
        case partial = 2
        case confirmed = 3

        static func < (lhs: IntelLevel, rhs: IntelLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct IntelContact: Codable, Hashable, Identifiable {
        let contactID: String
        var level: IntelLevel
        var estimatedCell: Int?
        var uncertaintyRadius: UInt8
        var kindEstimate: UnitKind?
        var stepsEstimate: Int?
        var lastObservedTurn: Int32
        var confidencePermille: Int16

        var id: String { contactID }
    }

    struct PlayerIntelState: Codable, Hashable {
        let viewer: Faction
        var exploredCells: Set<Int>
        var visibleCells: Set<Int>
        var friendlyUnits: [RedactedFriendlyUnit]
        var contacts: [IntelContact]

        struct RedactedFriendlyUnit: Codable, Hashable, Identifiable {
            let id: String
            let kind: UnitKind
            let cell: Int
            let steps: Int
        }

        func contact(at cell: Int) -> IntelContact? {
            contacts.first { $0.estimatedCell == cell && $0.level != .unknown }
        }

        func stableHash64() -> UInt64 {
            var data = Data()
            data.append(viewer.rawValue)

            func appendInt32(_ value: Int32) {
                var v = UInt32(bitPattern: value).bigEndian
                withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            }

            func appendUInt16(_ value: UInt16) {
                var v = value.bigEndian
                withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
            }

            func appendString(_ value: String) {
                let bytes = Data(value.utf8)
                appendUInt16(UInt16(bytes.count))
                data.append(bytes)
            }

            for cell in exploredCells.sorted() {
                appendInt32(Int32(cell))
            }
            data.append(0xFE)
            for cell in visibleCells.sorted() {
                appendInt32(Int32(cell))
            }
            data.append(0xFD)

            for unit in friendlyUnits.sorted(by: { $0.id < $1.id }) {
                appendString(unit.id)
                data.append(unit.kind.rawValue)
                appendInt32(Int32(unit.cell))
                appendInt32(Int32(unit.steps))
            }
            data.append(0xFC)

            for contact in contacts.sorted(by: { $0.contactID < $1.contactID }) {
                appendString(contact.contactID)
                data.append(contact.level.rawValue)
                appendInt32(Int32(contact.estimatedCell ?? -1))
                data.append(contact.uncertaintyRadius)
                data.append(contact.kindEstimate?.rawValue ?? 0xFF)
                appendInt32(Int32(contact.stepsEstimate ?? -1))
                appendInt32(contact.lastObservedTurn)
                appendInt32(Int32(contact.confidencePermille))
            }

            return StableHash64.fnv1a(data)
        }
    }

    struct IntelMemoryV2 {
        private struct MemoryContact: Hashable {
            let sourceKey: UInt64
            var contact: IntelContact
        }

        private var contactsBySource: [UInt64: MemoryContact] = [:]
        private(set) var exploredCells: Set<Int> = []

        init() {}

        mutating func project(
            truthUnits: [Unit],
            map: Map,
            viewer: Faction,
            simulationTurn: Int32,
            visibilityCache: inout VisibilityCacheV2,
            revision: Revision
        ) -> PlayerIntelState {
            let friendlies = truthUnits
                .filter { $0.faction == viewer && $0.steps > 0 }
                .sorted { $0.id < $1.id }

            var visible: Set<Int> = []
            for unit in friendlies {
                let profile = VisibilityProfile.standard(for: unit.kind)
                let unitVisible = visibilityCache.visibleCells(
                    observerID: unit.id,
                    observerCell: unit.cell,
                    map: map,
                    profile: profile,
                    revision: revision
                )
                visible.formUnion(unitVisible)
            }

            exploredCells.formUnion(visible)

            let enemies = truthUnits
                .filter { $0.faction != viewer && $0.steps > 0 }
                .sorted { $0.id < $1.id }

            var livingSourceKeys = Set<UInt64>()
            for enemy in enemies {
                let sourceKey = StableHash64.fnv1a("intel-source|\(enemy.id)")
                livingSourceKeys.insert(sourceKey)

                let observation = IntelDetectionV2.observe(
                    enemy: enemy,
                    friendlies: friendlies,
                    visibleCells: visible,
                    map: map
                )

                if observation.level > .unknown {
                    let contactID = IntelDetectionV2.contactID(
                        viewer: viewer,
                        sourceKey: sourceKey
                    )

                    let contact = IntelContact(
                        contactID: contactID,
                        level: observation.level,
                        estimatedCell: enemy.cell,
                        uncertaintyRadius: 0,
                        kindEstimate: observation.level >= .partial ? enemy.kind : nil,
                        stepsEstimate: observation.level == .confirmed ? enemy.steps : nil,
                        lastObservedTurn: simulationTurn,
                        confidencePermille: observation.confidencePermille
                    )
                    contactsBySource[sourceKey] = MemoryContact(
                        sourceKey: sourceKey,
                        contact: contact
                    )
                } else if var old = contactsBySource[sourceKey] {
                    old.contact = IntelDecayV2.decay(
                        old.contact,
                        toTurn: simulationTurn
                    )
                    if old.contact.level == .unknown {
                        contactsBySource.removeValue(forKey: sourceKey)
                    } else {
                        contactsBySource[sourceKey] = old
                    }
                }
            }

            // If a previously-known enemy no longer exists in truth, do not reveal destruction
            // unless a future public event confirms it. Its remembered contact simply decays.
            for sourceKey in contactsBySource.keys.sorted() where !livingSourceKeys.contains(sourceKey) {
                if var old = contactsBySource[sourceKey] {
                    old.contact = IntelDecayV2.decay(
                        old.contact,
                        toTurn: simulationTurn
                    )
                    if old.contact.level == .unknown {
                        contactsBySource.removeValue(forKey: sourceKey)
                    } else {
                        contactsBySource[sourceKey] = old
                    }
                }
            }

            let redactedFriendly = friendlies.map {
                PlayerIntelState.RedactedFriendlyUnit(
                    id: $0.id,
                    kind: $0.kind,
                    cell: $0.cell,
                    steps: $0.steps
                )
            }

            let publicContacts = contactsBySource.values
                .map(\.contact)
                .filter { $0.level != .unknown }
                .sorted { $0.contactID < $1.contactID }

            return PlayerIntelState(
                viewer: viewer,
                exploredCells: exploredCells,
                visibleCells: visible,
                friendlyUnits: redactedFriendly,
                contacts: publicContacts
            )
        }
    }
}
