import Combine
import Foundation

@MainActor
final class VeilA9HealthMonitor: ObservableObject {
    @Published private(set) var decision: VeilA9Decision = .initial
    @Published private(set) var databaseIntegrity: VeilA9DatabaseIntegrity = .unchecked
    @Published private(set) var lastEvaluatedAt: Date?

    // `persistenceRuns` is kept as an internal compatibility name; since I4 it stores
    // elapsed continuous non-green seconds, never callback count.
    private var persistenceRuns = 0
    private var nonGreenSinceUptime: TimeInterval?
    private var lastInput = VeilA9Input()

    var transportCoverage: VeilA9TransportCoverage { lastInput.transportCoverage }

    func setDatabaseIntegrity(_ value: VeilA9DatabaseIntegrity) {
        databaseIntegrity = value
    }

    func evaluate(
        _ rawInput: VeilA9Input,
        now: Date = Date(),
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        var input = rawInput
        input.databaseIntegrity = databaseIntegrity
        lastInput = input

        // Classification color does not depend on persistence. Measure elapsed non-green time
        // with monotonic system uptime so callback bursts and wall-clock changes cannot fake it.
        let preliminary = VeilA9Classifier.makePacket(input: input, persistenceRuns: 0)
        if preliminary.light == .green {
            nonGreenSinceUptime = nil
            persistenceRuns = 0
        } else if let since = nonGreenSinceUptime, uptime >= since {
            persistenceRuns = min(9_999, Int(uptime - since))
        } else {
            nonGreenSinceUptime = uptime
            persistenceRuns = 0
        }

        let packet = VeilA9Classifier.makePacket(input: input, persistenceRuns: persistenceRuns)
        // Publish the timestamp first. Sinks observing the new decision must
        // never see the evaluated score with a stale "not-evaluated" marker.
        lastEvaluatedAt = now
        decision = VeilA9Lattice.decide(packet)
    }

    func reevaluate(
        now: Date = Date(),
        uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        evaluate(lastInput, now: now, uptime: uptime)
    }

    func report() -> String {
        guard lastEvaluatedAt != nil else {
            return [
                "VeilLink A9 Health Lattice",
                "Generated: not-evaluated",
                "Evaluation: 未评估",
                "Light: 未评估",
                "Health: 未评估（不应解释为 100/100）",
                "Issues: 未评估；不能宣称无问题",
                "Transport coverage: 未评估（未完成链路质量检查）",
                "Database check: \(databaseIntegrity.title)",
                "Mode: advisory only; no transport/storage/game/agent mutation authority."
            ].joined(separator: "\n")
        }
        let timestamp = lastEvaluatedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "not-evaluated"
        var lines = [
            "VeilLink A9 Health Lattice",
            "Generated: \(timestamp)",
            "Light: \(decision.light.title)",
            "Level: \(decision.level.shortTitle) \(decision.level.title)",
            "Health: \(decision.healthScore)/100",
            "Risk points: \(String(format: "%.2f", decision.riskPoints))",
            "Persistence: \(decision.persistenceSeconds) s",
            "Transport coverage: \(transportCoverage.title)",
            "Lattice cell: \(decision.latticeIndex)/143",
            "Reason: \(decision.reasonCode)",
            "Database check: \(databaseIntegrity.title)"
        ]
        if decision.issues.isEmpty {
            lines.append("Issues: none")
        } else {
            lines.append("Issues:")
            for issue in decision.issues {
                lines.append("- \(issue.severity.rawValue) [\(issue.source)] \(issue.code): \(issue.detail)")
            }
        }
        lines.append("Mode: advisory only; no transport/storage/game/agent mutation authority.")
        lines.append("Privacy: numeric/local status only; no message plaintext, media content, keys or prompts.")
        return lines.joined(separator: "\n")
    }


}
