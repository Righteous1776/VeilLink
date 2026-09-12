#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

enum TransferVisualComplexity: String, Equatable {
    case minimal
    case balanced
    case full
}

struct DevicePerformanceProfile: Equatable {
    let label: String
    let messageWindowInitial: Int
    let messageWindowIncrement: Int
    let messageWindowMaximum: Int
    let decryptedBodyCacheEntries: Int
    let imagePreviewMaxPixelSize: Int
    let imagePreviewCacheCount: Int
    let imagePreviewCacheBytes: Int
    let outboundAttachmentCacheBytes: Int
    let bleQueuePacketLimit: Int
    let bleQueueByteLimit: Int
    let bleReassemblyMessageLimit: Int
    let bleReassemblyPerSourceLimit: Int
    let bleReassemblyByteLimit: Int
    let messageRefreshDebounceNanoseconds: UInt64
    let transferVisualComplexity: TransferVisualComplexity
    let shouldPrecomputeTransferShards: Bool
    let aggressiveBackgroundCacheTrim: Bool

    static let genericLegacy = DevicePerformanceProfile(
        label: "LEGACY-COMPACT",
        messageWindowInitial: 72,
        messageWindowIncrement: 72,
        messageWindowMaximum: 1_200,
        decryptedBodyCacheEntries: 256,
        imagePreviewMaxPixelSize: 768,
        imagePreviewCacheCount: 4,
        imagePreviewCacheBytes: 16 * 1_024 * 1_024,
        outboundAttachmentCacheBytes: 4 * 1_024 * 1_024,
        bleQueuePacketLimit: 12_288,
        bleQueueByteLimit: 1_250_000,
        bleReassemblyMessageLimit: 24,
        bleReassemblyPerSourceLimit: 6,
        bleReassemblyByteLimit: 512_000,
        messageRefreshDebounceNanoseconds: 140_000_000,
        transferVisualComplexity: .balanced,
        shouldPrecomputeTransferShards: true,
        aggressiveBackgroundCacheTrim: true
    )

    static let genericModern = DevicePerformanceProfile(
        label: "MODERN",
        messageWindowInitial: 120,
        messageWindowIncrement: 120,
        messageWindowMaximum: 2_000,
        decryptedBodyCacheEntries: 512,
        imagePreviewMaxPixelSize: 1_024,
        imagePreviewCacheCount: 8,
        imagePreviewCacheBytes: 32 * 1_024 * 1_024,
        outboundAttachmentCacheBytes: 6 * 1_024 * 1_024,
        bleQueuePacketLimit: 16_384,
        bleQueueByteLimit: 2_500_000,
        bleReassemblyMessageLimit: 32,
        bleReassemblyPerSourceLimit: 8,
        bleReassemblyByteLimit: 768_000,
        messageRefreshDebounceNanoseconds: 100_000_000,
        transferVisualComplexity: .full,
        shouldPrecomputeTransferShards: true,
        aggressiveBackgroundCacheTrim: false
    )
}

enum DevicePerformancePolicy {
    static func profile(machineIdentifier: String, osMajorVersion: Int) -> DevicePerformanceProfile {
        switch machineIdentifier {
        case "iPhone8,4": // iPhone SE (1st generation), A9 / 2 GB
            return DevicePerformanceProfile(
                label: "SE1-LOW",
                messageWindowInitial: 48,
                messageWindowIncrement: 48,
                messageWindowMaximum: 720,
                decryptedBodyCacheEntries: 128,
                imagePreviewMaxPixelSize: 640,
                imagePreviewCacheCount: 3,
                imagePreviewCacheBytes: 10 * 1_024 * 1_024,
                outboundAttachmentCacheBytes: 3 * 1_024 * 1_024,
                bleQueuePacketLimit: 8_192,
                bleQueueByteLimit: 640_000,
                bleReassemblyMessageLimit: 16,
                bleReassemblyPerSourceLimit: 4,
                bleReassemblyByteLimit: 384_000,
                messageRefreshDebounceNanoseconds: 180_000_000,
                transferVisualComplexity: .minimal,
                shouldPrecomputeTransferShards: false,
                aggressiveBackgroundCacheTrim: true
            )
        case "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4": // iPhone 7 / 7 Plus
            return .genericLegacy
        case "iPhone12,8": // iPhone SE (2nd generation), A13 / 3 GB
            return DevicePerformanceProfile(
                label: "SE2-BALANCED",
                messageWindowInitial: 120,
                messageWindowIncrement: 120,
                messageWindowMaximum: 2_000,
                decryptedBodyCacheEntries: 384,
                imagePreviewMaxPixelSize: 1_024,
                imagePreviewCacheCount: 6,
                imagePreviewCacheBytes: 24 * 1_024 * 1_024,
                outboundAttachmentCacheBytes: 6 * 1_024 * 1_024,
                bleQueuePacketLimit: 16_384,
                bleQueueByteLimit: 2_000_000,
                bleReassemblyMessageLimit: 32,
                bleReassemblyPerSourceLimit: 8,
                bleReassemblyByteLimit: 768_000,
                messageRefreshDebounceNanoseconds: 90_000_000,
                transferVisualComplexity: .full,
                shouldPrecomputeTransferShards: true,
                aggressiveBackgroundCacheTrim: false
            )
        case "iPhone14,2": // iPhone 13 Pro, A15 / 6 GB
            return DevicePerformanceProfile(
                label: "13PRO-HIGH",
                messageWindowInitial: 180,
                messageWindowIncrement: 180,
                messageWindowMaximum: 3_000,
                decryptedBodyCacheEntries: 768,
                imagePreviewMaxPixelSize: 1_280,
                imagePreviewCacheCount: 10,
                imagePreviewCacheBytes: 48 * 1_024 * 1_024,
                outboundAttachmentCacheBytes: 9 * 1_024 * 1_024,
                bleQueuePacketLimit: 16_384,
                bleQueueByteLimit: 2_500_000,
                bleReassemblyMessageLimit: 40,
                bleReassemblyPerSourceLimit: 10,
                bleReassemblyByteLimit: 1_024_000,
                messageRefreshDebounceNanoseconds: 60_000_000,
                transferVisualComplexity: .full,
                shouldPrecomputeTransferShards: true,
                aggressiveBackgroundCacheTrim: false
            )
        case "iPad13,1", "iPad13,2": // iPad Air (4th generation); UI bugs tracked separately.
            return DevicePerformanceProfile(
                label: "AIR4-DEFERRED-UI",
                messageWindowInitial: 180,
                messageWindowIncrement: 180,
                messageWindowMaximum: 3_000,
                decryptedBodyCacheEntries: 640,
                imagePreviewMaxPixelSize: 1_280,
                imagePreviewCacheCount: 10,
                imagePreviewCacheBytes: 40 * 1_024 * 1_024,
                outboundAttachmentCacheBytes: 8 * 1_024 * 1_024,
                bleQueuePacketLimit: 16_384,
                bleQueueByteLimit: 2_500_000,
                bleReassemblyMessageLimit: 40,
                bleReassemblyPerSourceLimit: 10,
                bleReassemblyByteLimit: 1_024_000,
                messageRefreshDebounceNanoseconds: 75_000_000,
                transferVisualComplexity: .full,
                shouldPrecomputeTransferShards: true,
                aggressiveBackgroundCacheTrim: false
            )
        default:
            return osMajorVersion <= 15 ? .genericLegacy : .genericModern
        }
    }
}

enum VeilDevicePerformance {
    static let machineIdentifier: String = {
        var info = utsname()
        guard uname(&info) == 0 else { return "unknown" }
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }()

    static let base = DevicePerformancePolicy.profile(
        machineIdentifier: machineIdentifier,
        osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    )

    static var current: DevicePerformanceProfile {
        PerformanceOverridePolicy.effectiveProfile(
            base: base,
            snapshot: PerformanceOverrideStore.shared.snapshot()
        )
    }

    static var diagnosticLabel: String {
        "\(current.label) · \(machineIdentifier)"
    }
}
