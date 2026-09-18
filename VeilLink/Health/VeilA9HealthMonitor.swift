import Combine
import Foundation

@MainActor
final class VeilA9HealthMonitor: ObservableObject {
    @Published private(set) var decision: VeilA9Decision = .initial
    @Published private(set) var databaseIntegrity: VeilA9DatabaseIntegrity = .unchecked
    @Published private(set) var lastEvaluatedAt: Date?

    private var persistenceRuns = 0
    private var lastInput = VeilA9Input()

    func setDatabaseIntegrity(_ value: VeilA9DatabaseIntegrity) {
        databaseIntegrity = value
    }

    func evaluate(_ rawInput: VeilA9Input) {
        var input = rawInput
        input.databaseIntegrity = databaseIntegrity
        lastInput = input

        let preliminary = VeilA9Classifier.makePacket(input: input, persistenceRuns: persistenceRuns)
        if preliminary.light == .green {
            persistenceRuns = 0
        } else {
            persistenceRuns = min(9_999, persistenceRuns + 1)
        }
        let packet = VeilA9Classifier.makePacket(input: input, persistenceRuns: persistenceRuns)
        decision = VeilA9Lattice.decide(packet)
        lastEvaluatedAt = Date()
    }

    func reevaluate() {
        evaluate(lastInput)
    }

    func report() -> String {
        let timestamp = lastEvaluatedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "not-evaluated"
        var lines = [
            "VeilLink A9 Health Lattice",
            "Generated: \(timestamp)",
            "Light: \(decision.light.title)",
            "Level: \(decision.level.shortTitle) \(decision.level.title)",
            "Health: \(decision.healthScore)/100",
            "Risk points: \(String(format: "%.2f", decision.riskPoints))",
            "Persistence runs: \(decision.persistenceRuns)",
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
