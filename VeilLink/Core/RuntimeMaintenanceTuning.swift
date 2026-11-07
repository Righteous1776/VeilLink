import Foundation

/// This is a logical scheduler topology; iOS chooses the actual worker threads.
enum VeilConcurrentFabricLane: String, CaseIterable, Sendable {
    case control, bulk, audioCapture, audioPlayback, maintenance
}

enum VeilConcurrentFabricPolicy {
    static let storageQueueLabel = "studio.zeo.veillink.sqlite"

    /// Preserve existing transport queue priorities; bound one active drain burst
    /// so realtime audio can run between long bulk packet bursts.
    static func bleDrainBurst(configuredLimit: Int, realtimePending: Bool) -> Int {
        let base = max(1, configuredLimit)
        return realtimePending ? min(base, 8) : base
    }

    static func maintenanceInterval(
        tuning: VeilRuntimeMaintenanceTuning,
        foreground: Bool,
        queued: Bool,
        connected: Bool
    ) -> UInt64 {
        if !foreground { return tuning.bleIdleMaintenanceNanoseconds }
        if queued { return tuning.bleQueuedMaintenanceNanoseconds }
        if connected { return tuning.bleConnectedMaintenanceNanoseconds }
        return tuning.bleIdleMaintenanceNanoseconds
    }
}

struct VeilRuntimeMaintenanceTuning: Equatable, Sendable {
    let outboundRetryIntervalNanoseconds: UInt64
    let bleIdleMaintenanceNanoseconds: UInt64
    let bleConnectedMaintenanceNanoseconds: UInt64
    let bleQueuedMaintenanceNanoseconds: UInt64
    let rssiPollInterval: TimeInterval
    let jitterStatsPublishInterval: TimeInterval

    static func resolved(performanceLabel: String) -> VeilRuntimeMaintenanceTuning {
        let label = performanceLabel.uppercased()
        if label.contains("SE1") || label.contains("LEGACY") {
            return VeilRuntimeMaintenanceTuning(
                outboundRetryIntervalNanoseconds: 3_000_000_000,
                bleIdleMaintenanceNanoseconds: 5_000_000_000,
                bleConnectedMaintenanceNanoseconds: 3_000_000_000,
                bleQueuedMaintenanceNanoseconds: 1_500_000_000,
                rssiPollInterval: 4.0,
                jitterStatsPublishInterval: 0.24
            )
        }
        if label.contains("13PRO") || label.contains("HIGH") {
            return VeilRuntimeMaintenanceTuning(
                outboundRetryIntervalNanoseconds: 1_500_000_000,
                bleIdleMaintenanceNanoseconds: 4_000_000_000,
                bleConnectedMaintenanceNanoseconds: 1_800_000_000,
                bleQueuedMaintenanceNanoseconds: 900_000_000,
                rssiPollInterval: 2.0,
                jitterStatsPublishInterval: 0.14
            )
        }
        return VeilRuntimeMaintenanceTuning(
            outboundRetryIntervalNanoseconds: 2_000_000_000,
            bleIdleMaintenanceNanoseconds: 4_500_000_000,
            bleConnectedMaintenanceNanoseconds: 2_400_000_000,
            bleQueuedMaintenanceNanoseconds: 1_100_000_000,
            rssiPollInterval: 2.8,
            jitterStatsPublishInterval: 0.18
        )
    }
}
