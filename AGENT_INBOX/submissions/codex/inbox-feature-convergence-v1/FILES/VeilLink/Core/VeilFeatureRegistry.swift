import Foundation

enum VeilFeatureDomain: String, CaseIterable, Identifiable, Codable, Sendable {
    case communication
    case productivity
    case diagnostics
    case entertainment
    case emotion
    case games
    case utilities
    case experimental

    var id: String { rawValue }

    var title: String {
        switch self {
        case .communication: return "通信"
        case .productivity: return "效率"
        case .diagnostics: return "诊断"
        case .entertainment: return "娱乐"
        case .emotion: return "陪伴"
        case .games: return "游戏"
        case .utilities: return "工具"
        case .experimental: return "实验室"
        }
    }
}

enum VeilFeatureResourceClass: Int, Codable, Comparable, Sendable {
    case featherweight = 0
    case standard = 1
    case renderHeavy = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct VeilFeatureGate: OptionSet, Hashable, Codable, Sendable {
    let rawValue: UInt16

    static let p0TouchVerified = Self(rawValue: 1 << 0)
    static let dataContinuityVerified = Self(rawValue: 1 << 1)
    static let appleBuildVerified = Self(rawValue: 1 << 2)
    static let physicalDeviceVerified = Self(rawValue: 1 << 3)
    static let networkPermission = Self(rawValue: 1 << 4)
    static let microphonePermission = Self(rawValue: 1 << 5)
    static let motionPermission = Self(rawValue: 1 << 6)

    static let releaseBaseline: Self = [
        .p0TouchVerified,
        .dataContinuityVerified,
        .appleBuildVerified,
        .physicalDeviceVerified
    ]
}

struct VeilFeatureDescriptor: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let packID: String
    let title: String
    let subtitle: String
    let domain: VeilFeatureDomain
    let keywords: [String]
    let resourceClass: VeilFeatureResourceClass
    let requiredGates: VeilFeatureGate
    let conflictGroup: String?
    let isExperimental: Bool
}

struct VeilFeatureRuntimeProfile: Equatable, Sendable {
    enum ThermalPressure: Int, Comparable, Sendable {
        case nominal = 0
        case fair = 1
        case serious = 2
        case critical = 3
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var isLegacyDevice: Bool
    var lowPowerMode: Bool
    var reduceMotion: Bool
    var godModeHighQuality: Bool
    var thermalPressure: ThermalPressure
}

enum VeilFeatureRenderTier: String, Equatable, Sendable {
    case staticOnly
    case reduced
    case standard
    case high
}

enum VeilFeatureLaunchState: String, Equatable, Sendable {
    case available
    case degraded
    case blocked
    case thermallyDeferred
}

struct VeilFeatureLaunchDecision: Equatable, Sendable {
    let state: VeilFeatureLaunchState
    let renderTier: VeilFeatureRenderTier
    let reason: String?

    var canLaunch: Bool { state == .available || state == .degraded }
}

struct VeilFeatureQuery: Equatable, Sendable {
    var text: String = ""
    var domain: VeilFeatureDomain?
    var offset: Int = 0
    var limit: Int = 40
}

struct VeilFeatureQueryPage: Equatable, Sendable {
    let items: [VeilFeatureDescriptor]
    let totalCount: Int
    let offset: Int
    let hasMore: Bool
}

struct VeilFeatureRegistryAudit: Equatable, Sendable {
    let featureCount: Int
    let packCounts: [String: Int]
    let conflictGroups: [String: [String]]
}

enum VeilFeatureRegistryError: Error, Equatable, LocalizedError, Sendable {
    case emptyID
    case duplicateID(String)
    case invalidPackID(String)

    var errorDescription: String? {
        switch self {
        case .emptyID: return "功能 ID 不能为空"
        case let .duplicateID(id): return "功能 ID 重复：\(id)"
        case let .invalidPackID(id): return "功能包 ID 无效：\(id)"
        }
    }
}

struct VeilFeatureRegistry: Sendable {
    private struct SearchEntry: Sendable {
        let descriptor: VeilFeatureDescriptor
        let normalizedText: String
    }

    private let ordered: [VeilFeatureDescriptor]
    private let byID: [String: VeilFeatureDescriptor]
    private let byDomain: [VeilFeatureDomain: [VeilFeatureDescriptor]]
    private let searchEntries: [SearchEntry]

    init(features: [VeilFeatureDescriptor]) throws {
        var ids = Set<String>()
        for feature in features {
            let id = feature.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty else { throw VeilFeatureRegistryError.emptyID }
            guard ids.insert(id.lowercased()).inserted else {
                throw VeilFeatureRegistryError.duplicateID(feature.id)
            }
            guard !feature.packID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw VeilFeatureRegistryError.invalidPackID(feature.id)
            }
        }

        ordered = features
        byID = Dictionary(uniqueKeysWithValues: features.map { ($0.id.lowercased(), $0) })
        byDomain = Dictionary(grouping: features, by: \.domain)
        searchEntries = features.map { feature in
            let corpus = ([feature.id, feature.packID, feature.title, feature.subtitle, feature.domain.title] + feature.keywords)
                .joined(separator: " ")
            return SearchEntry(descriptor: feature, normalizedText: Self.normalized(corpus))
        }
    }

    var count: Int { ordered.count }

    func feature(id: String) -> VeilFeatureDescriptor? {
        byID[id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    func query(_ query: VeilFeatureQuery) -> VeilFeatureQueryPage {
        let needle = Self.normalized(query.text.trimmingCharacters(in: .whitespacesAndNewlines))
        let source: [VeilFeatureDescriptor]
        if needle.isEmpty {
            source = query.domain.flatMap { byDomain[$0] } ?? ordered
        } else {
            source = searchEntries.lazy.filter { entry in
                (query.domain == nil || entry.descriptor.domain == query.domain) && entry.normalizedText.contains(needle)
            }.map(\.descriptor)
        }

        let offset = max(0, min(query.offset, source.count))
        let limit = max(1, min(query.limit, 100))
        let end = min(source.count, offset + limit)
        return VeilFeatureQueryPage(
            items: Array(source[offset..<end]),
            totalCount: source.count,
            offset: offset,
            hasMore: end < source.count
        )
    }

    func launchDecision(
        for featureID: String,
        profile: VeilFeatureRuntimeProfile,
        passedGates: VeilFeatureGate
    ) -> VeilFeatureLaunchDecision {
        guard let feature = feature(id: featureID) else {
            return VeilFeatureLaunchDecision(state: .blocked, renderTier: .staticOnly, reason: "功能未注册")
        }

        let missing = feature.requiredGates.subtracting(passedGates)
        guard missing.isEmpty else {
            return VeilFeatureLaunchDecision(
                state: .blocked,
                renderTier: .staticOnly,
                reason: "仍需验证：\(Self.gateNames(missing).joined(separator: "、"))"
            )
        }

        if profile.thermalPressure == .critical, feature.resourceClass == .renderHeavy {
            return VeilFeatureLaunchDecision(state: .thermallyDeferred, renderTier: .staticOnly, reason: "设备温度过高，重渲染功能暂缓")
        }

        if profile.godModeHighQuality {
            return VeilFeatureLaunchDecision(state: .available, renderTier: .high, reason: "上帝模式强制高质量")
        }

        if profile.reduceMotion {
            return VeilFeatureLaunchDecision(state: .degraded, renderTier: .staticOnly, reason: "遵循减少动态效果")
        }

        if profile.isLegacyDevice || profile.lowPowerMode || profile.thermalPressure >= .serious {
            let tier: VeilFeatureRenderTier = feature.resourceClass == .featherweight ? .standard : .reduced
            return VeilFeatureLaunchDecision(state: .degraded, renderTier: tier, reason: "使用兼容性能档")
        }

        return VeilFeatureLaunchDecision(state: .available, renderTier: feature.resourceClass == .renderHeavy ? .high : .standard, reason: nil)
    }

    func audit() -> VeilFeatureRegistryAudit {
        let packCounts = Dictionary(grouping: ordered, by: \.packID).mapValues(\.count)
        let conflicts = Dictionary(grouping: ordered.compactMap { feature -> (String, String)? in
            feature.conflictGroup.map { ($0, feature.packID) }
        }, by: \.0).mapValues { values in
            Array(Set(values.map(\.1))).sorted()
        }.filter { $0.value.count > 1 }
        return VeilFeatureRegistryAudit(featureCount: ordered.count, packCounts: packCounts, conflictGroups: conflicts)
    }

    private static func normalized(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "zh_Hans_CN")
        )
    }

    private static func gateNames(_ gates: VeilFeatureGate) -> [String] {
        var names: [String] = []
        if gates.contains(.p0TouchVerified) { names.append("触控 P0") }
        if gates.contains(.dataContinuityVerified) { names.append("数据连续性") }
        if gates.contains(.appleBuildVerified) { names.append("Apple 构建") }
        if gates.contains(.physicalDeviceVerified) { names.append("真机") }
        if gates.contains(.networkPermission) { names.append("网络权限") }
        if gates.contains(.microphonePermission) { names.append("麦克风权限") }
        if gates.contains(.motionPermission) { names.append("运动传感器权限") }
        return names
    }
}
