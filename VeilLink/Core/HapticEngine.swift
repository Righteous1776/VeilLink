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
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
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
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }

    func impact() {
        guard canPlay else { return }
        let generator = impactGenerator(for: strength.impactStyle)
        generator.prepare()
        generator.impactOccurred(intensity: strength.intensity)
    }

    func send() {
        impact()
    }

    func receive() {
        guard canPlay else { return }
        softImpactGenerator.prepare()
        softImpactGenerator.impactOccurred(intensity: min(strength.intensity, 0.72))
    }

    func resolved() {
        guard canPlay else { return }
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch strength {
        case .subtle: style = .soft
        case .balanced: style = .light
        case .strong: style = .rigid
        }
        let generator = impactGenerator(for: style)
        generator.prepare()
        generator.impactOccurred(intensity: min(1.0, strength.intensity + 0.08))
    }

    func warning() {
        guard canPlay else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        guard canPlay else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)
    }

    private func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .soft: return softImpactGenerator
        case .light: return lightImpactGenerator
        case .medium: return mediumImpactGenerator
        case .rigid: return rigidImpactGenerator
        case .heavy: return rigidImpactGenerator
        @unknown default: return lightImpactGenerator
        }
    }

    private var canPlay: Bool {
        isEnabled && UIApplication.shared.applicationState == .active
    }
}
