import Combine
import UIKit

@MainActor
final class HapticEngine: ObservableObject {
    enum Strength: String, CaseIterable, Identifiable {
        case subtle
        case balanced
        case strong

        var id: String { rawValue }

        var title: String {
            switch self {
            case .subtle: return "轻柔"
            case .balanced: return "标准"
            case .strong: return "明显"
            }
        }

        fileprivate var impactStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .subtle: return .soft
            case .balanced: return .light
            case .strong: return .medium
            }
        }

        fileprivate var intensity: CGFloat {
            switch self {
            case .subtle: return 0.48
            case .balanced: return 0.76
            case .strong: return 1.0
            }
        }
    }

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Self.enabledKey) }
    }

    @Published var strength: Strength {
        didSet { defaults.set(strength.rawValue, forKey: Self.strengthKey) }
    }

    private let defaults: UserDefaults
    private static let enabledKey = "feedback.haptics.enabled"
    private static let strengthKey = "feedback.haptics.strength"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.enabledKey) == nil {
            self.isEnabled = true
        } else {
            self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        }
        self.strength = Strength(rawValue: defaults.string(forKey: Self.strengthKey) ?? "") ?? .balanced
    }

    func selection() {
        guard canPlay else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    func impact() {
        guard canPlay else { return }
        let generator = UIImpactFeedbackGenerator(style: strength.impactStyle)
        generator.prepare()
        generator.impactOccurred(intensity: strength.intensity)
    }

    func send() {
        impact()
    }

    func receive() {
        guard canPlay else { return }
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: min(strength.intensity, 0.72))
    }

    func resolved() {
        guard canPlay else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch strength {
        case .subtle: style = .soft
        case .balanced: style = .light
        case .strong: style = .rigid
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: min(1.0, strength.intensity + 0.08))
    }

    func warning() {
        guard canPlay else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    func error() {
        guard canPlay else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    private var canPlay: Bool {
        isEnabled && UIApplication.shared.applicationState == .active
    }
}
