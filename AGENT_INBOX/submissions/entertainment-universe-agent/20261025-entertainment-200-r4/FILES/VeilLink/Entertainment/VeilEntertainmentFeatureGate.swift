import Foundation

/// Design-time admission rules; does NOT install or activate App features.
/// In particular a catalogue entry must never become a tappable App feature
/// simply because it has a detailed description or a candidate Swift file.
public enum VeilEntertainmentFeatureGate {
    public static let catalogCount = 200
    public static let candidateNumbers: Set<Int> = [1, 4, 6, 11, 91, 101, 121, 191]

    public enum State: String, Codable, Sendable {
        case designed
        case candidateCore
    }

    public struct Evidence: Codable, Equatable, Sendable {
        public let productCompiled: Bool
        public let incidentP0Cleared: Bool
        public let ios15DevicePassed: Bool
        public let userOptedIn: Bool
        public init(productCompiled: Bool = false,
                    incidentP0Cleared: Bool = false,
                    ios15DevicePassed: Bool = false,
                    userOptedIn: Bool = false) {
            self.productCompiled = productCompiled
            self.incidentP0Cleared = incidentP0Cleared
            self.ios15DevicePassed = ios15DevicePassed
            self.userOptedIn = userOptedIn
        }
        public var satisfied: Bool {
            productCompiled && incidentP0Cleared && ios15DevicePassed && userOptedIn
        }
    }

    public static func id(for number: Int) -> String? {
        guard (1...catalogCount).contains(number) else { return nil }
        return number < 91 ? String(format: "E%02d", number) : String(format: "E%03d", number)
    }

    public static func number(for id: String) -> Int? {
        guard id.first == "E", let value = Int(id.dropFirst()),
              let canonical = self.id(for: value), canonical == id else { return nil }
        return value
    }

    public static func state(for id: String) -> State? {
        guard let value = number(for: id) else { return nil }
        return candidateNumbers.contains(value) ? .candidateCore : .designed
    }

    /// Gate only: the caller is still responsible for enforcing those proofs.
    /// The gate cannot generate or certify device evidence by itself.
    public static func canPresent(_ id: String, evidence: Evidence = Evidence()) -> Bool {
        state(for: id) == .candidateCore && evidence.satisfied
    }
}
