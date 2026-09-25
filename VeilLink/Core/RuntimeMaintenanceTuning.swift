import Foundation

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
