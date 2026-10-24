import Foundation

enum VeilInstallChannel: String, Equatable, Sendable {
    case simulator
    case trollStore
    case trollStoreLite
    case appStore
    case testFlight
    case provisioned
    case unknown

    var title: String {
        switch self {
        case .simulator: return "模拟器"
        case .trollStore: return "TrollStore"
        case .trollStoreLite: return "TrollStore Lite"
        case .appStore: return "App Store"
        case .testFlight: return "TestFlight"
        case .provisioned: return "普通签名安装"
        case .unknown: return "未知签名来源"
        }
    }
}

enum VeilRuntimeProfile: String, Equatable, Sendable {
    case standard
    case persistentSandboxed
    case enhancedCandidate

    var title: String {
        switch self {
        case .standard: return "标准兼容模式"
        case .persistentSandboxed: return "持久沙盒模式"
        case .enhancedCandidate: return "TrollStore 增强候选"
        }
    }
}

enum VeilCapabilityState: Int, Comparable, Equatable, Sendable {
    case unavailable = 0
    case declared = 1
    case candidate = 2
    case available = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .unavailable: return "不可用"
        case .declared: return "已声明"
        case .candidate: return "待验证"
        case .available: return "可用"
        }
    }
}

struct VeilRuntimeCapability: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case persistentInstall
        case backgroundBluetooth
        case backgroundAudio
        case backgroundRefresh
        case localNetwork
        case liveActivity
        case elevatedEntitlements
    }

    var id: String { kind.rawValue }
    let kind: Kind
    let title: String
    let state: VeilCapabilityState
    let detail: String
}

struct VeilRuntimeEnvironmentInputs: Equatable, Sendable {
    let isSimulator: Bool
    let hasTrollStoreMarker: Bool
    let hasTrollStoreLiteMarker: Bool
    let receiptPresent: Bool
    let receiptName: String?
    let hasEmbeddedProvision: Bool
    let backgroundModes: Set<String>
    let hasBonjourServices: Bool
    let supportsLiveActivities: Bool
}

struct VeilRuntimeEnvironmentSnapshot: Equatable, Sendable {
    let channel: VeilInstallChannel
    let profile: VeilRuntimeProfile
    let confidence: String
    let capabilities: [VeilRuntimeCapability]
    let elevatedEntitlementsVerified: Bool

    var isTrollStore: Bool { channel == .trollStore || channel == .trollStoreLite }

    var diagnosticsReport: String {
        let rows = capabilities.map { "\($0.kind.rawValue)=\($0.state.title)" }.joined(separator: "\n")
        return """
        VeilLink Runtime Capability
        channel=\(channel.rawValue)
        profile=\(profile.rawValue)
        confidence=\(confidence)
        elevated_entitlements_verified=\(elevatedEntitlementsVerified)
        \(rows)
        """
    }
}

enum VeilRuntimeEnvironment {
    private static let trollStoreMarker = "_TrollStore"
    private static let trollStoreLiteMarker = "_TrollStoreLite"

    static var current: VeilRuntimeEnvironmentSnapshot {
        capture(bundle: .main, fileManager: .default)
    }

    static func capture(bundle: Bundle, fileManager: FileManager) -> VeilRuntimeEnvironmentSnapshot {
        let container = bundle.bundleURL.deletingLastPathComponent()
        let receiptURL = bundle.appStoreReceiptURL
        let modes = Set(bundle.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? [])
        let inputs = VeilRuntimeEnvironmentInputs(
            isSimulator: isSimulatorBuild,
            hasTrollStoreMarker: fileManager.fileExists(atPath: container.appendingPathComponent(trollStoreMarker).path),
            hasTrollStoreLiteMarker: fileManager.fileExists(atPath: container.appendingPathComponent(trollStoreLiteMarker).path),
            receiptPresent: receiptURL.map { fileManager.fileExists(atPath: $0.path) } ?? false,
            receiptName: receiptURL?.lastPathComponent,
            hasEmbeddedProvision: bundle.path(forResource: "embedded", ofType: "mobileprovision") != nil,
            backgroundModes: modes,
            hasBonjourServices: !(bundle.object(forInfoDictionaryKey: "NSBonjourServices") as? [String] ?? []).isEmpty,
            supportsLiveActivities: bundle.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool ?? false
        )
        return resolve(inputs)
    }

    static func resolve(_ inputs: VeilRuntimeEnvironmentInputs) -> VeilRuntimeEnvironmentSnapshot {
        let channel: VeilInstallChannel
        let confidence: String
        if inputs.isSimulator {
            channel = .simulator
            confidence = "编译环境明确为 Simulator"
        } else if inputs.hasTrollStoreLiteMarker {
            channel = .trollStoreLite
            confidence = "发现 TrollStore 官方 Lite 安装标记"
        } else if inputs.hasTrollStoreMarker {
            channel = .trollStore
            confidence = "发现 TrollStore 官方安装标记"
        } else if inputs.receiptPresent, inputs.receiptName == "sandboxReceipt" {
            channel = .testFlight
            confidence = "发现 TestFlight sandbox receipt"
        } else if inputs.receiptPresent {
            channel = .appStore
            confidence = "发现 App Store receipt"
        } else if inputs.hasEmbeddedProvision {
            channel = .provisioned
            confidence = "发现 embedded.mobileprovision"
        } else {
            channel = .unknown
            confidence = "没有足够证据确认安装来源"
        }

        let isTrollStore = channel == .trollStore || channel == .trollStoreLite
        let persistent = isTrollStore || channel == .appStore || channel == .testFlight
        let profile: VeilRuntimeProfile = isTrollStore
            ? .enhancedCandidate
            : (persistent ? .persistentSandboxed : .standard)
        let capabilities = [
            VeilRuntimeCapability(
                kind: .persistentInstall,
                title: "持久安装",
                state: persistent ? .available : .unavailable,
                detail: persistent ? "当前来源不依赖普通侧载的短期签名周期。" : "普通签名可能需要续签。"
            ),
            declaredCapability(.backgroundBluetooth, "蓝牙后台", inputs.backgroundModes.contains("bluetooth-central") && inputs.backgroundModes.contains("bluetooth-peripheral")),
            declaredCapability(.backgroundAudio, "音频后台", inputs.backgroundModes.contains("audio")),
            declaredCapability(.backgroundRefresh, "后台刷新", inputs.backgroundModes.contains("fetch")),
            declaredCapability(.localNetwork, "局域网直连", inputs.hasBonjourServices),
            declaredCapability(.liveActivity, "实时活动", inputs.supportsLiveActivities),
            VeilRuntimeCapability(
                kind: .elevatedEntitlements,
                title: "增强 entitlement",
                state: isTrollStore ? .candidate : .unavailable,
                detail: isTrollStore
                    ? "安装来源已确认，但每项高权限仍需独立探测和用户启用。"
                    : "标准包不会请求或假定 TrollStore 高权限。"
            )
        ]
        return VeilRuntimeEnvironmentSnapshot(
            channel: channel,
            profile: profile,
            confidence: confidence,
            capabilities: capabilities,
            elevatedEntitlementsVerified: false
        )
    }

    private static func declaredCapability(
        _ kind: VeilRuntimeCapability.Kind,
        _ title: String,
        _ declared: Bool
    ) -> VeilRuntimeCapability {
        VeilRuntimeCapability(
            kind: kind,
            title: title,
            state: declared ? .declared : .unavailable,
            detail: declared ? "包内已声明，最终可用性仍由 iOS 决定。" : "当前包没有声明。"
        )
    }

    private static var isSimulatorBuild: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
