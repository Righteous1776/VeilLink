import Foundation
import MetricKit

final class MetricKitTelemetryReceiver: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricKitTelemetryReceiver()
    private var started = false

    private override init() {
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        let artifacts = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            for data in artifacts {
                let name = DiagnosticLogStore.shared.storeAuxiliaryArtifact(
                    prefix: "metrickit-metrics",
                    fileExtension: "json",
                    data: data
                )
                DiagnosticLogStore.shared.log(
                    .info,
                    .performance,
                    event: "metrickit.metrics_received",
                    screen: DeepTelemetry.shared.currentScreen,
                    metadata: [
                        "bytes": String(data.count),
                        "artifact": name ?? "write-failed"
                    ]
                )
            }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let artifacts = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            for data in artifacts {
                let name = DiagnosticLogStore.shared.storeAuxiliaryArtifact(
                    prefix: "metrickit-diagnostics",
                    fileExtension: "json",
                    data: data
                )
                DiagnosticLogStore.shared.log(
                    .warning,
                    .performance,
                    event: "metrickit.diagnostics_received",
                    screen: DeepTelemetry.shared.currentScreen,
                    metadata: [
                        "bytes": String(data.count),
                        "artifact": name ?? "write-failed"
                    ]
                )
            }
        }
    }
}
