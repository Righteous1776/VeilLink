import Combine
import Foundation

enum MaleCNSDeploymentMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case automatic
    case forceLite
    case experimentalCore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "自动 Lite"
        case .forceLite: return "Lite"
        case .experimentalCore: return "Core 实验"
        }
    }
}

enum AgentGameDecisionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case automaticStable
    case baselineOnly
    case trainedLite
    case experimentalCore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automaticStable: return "自动稳定"
        case .baselineOnly: return "仅基础策略"
        case .trainedLite: return "训练 Lite"
        case .experimentalCore: return "实验 Core"
        }
    }

    var subtitle: String {
        switch self {
        case .automaticStable:
            return "稳定档固定使用 Lite VFLY；Core 仅在本次启动中手动进入实验模式后启用。"
        case .baselineOnly:
            return "仅使用 game_policy_ranker_v4，不进行 MaleCNS 候选重排。"
        case .trainedLite:
            return "强制加载 12k Lite VFLY，并启用 R7 Top-3 residual ranker。"
        case .experimentalCore:
            return "强制加载 48k Core VFLY，并允许小样本实验 ranker。耗电、延迟和质量都未完成真机验证。"
        }
    }

    var graphDeploymentMode: MaleCNSDeploymentMode {
        switch self {
        case .automaticStable, .baselineOnly: return .automatic
        case .trainedLite: return .forceLite
        case .experimentalCore: return .experimentalCore
        }
    }

    var usesMaleCNSRerank: Bool { self != .baselineOnly }
    var allowsExperimentalRanker: Bool { self == .experimentalCore }
    var isExperimental: Bool { self == .experimentalCore }
}

@MainActor
final class AgentControlCenterSettings: ObservableObject {
    private enum Key {
        static let autoLoadLanguageModel = "agent.controls.autoLoadLanguageModel"
        static let conversationTextAccessEnabled = "agent.controls.conversationTextAccessEnabled"
        static let visualContextEnabled = "agent.controls.visualContextEnabled"
        static let localToolMutationsEnabled = "agent.controls.localToolMutationsEnabled"
        static let allowSuggestedGameMoveExecution = "agent.controls.allowSuggestedGameMoveExecution"
        static let gameDecisionMode = "agent.controls.gameDecisionMode"
    }

    @Published var autoLoadLanguageModel: Bool { didSet { defaults.set(autoLoadLanguageModel, forKey: Key.autoLoadLanguageModel) } }
    @Published var conversationTextAccessEnabled: Bool { didSet { defaults.set(conversationTextAccessEnabled, forKey: Key.conversationTextAccessEnabled) } }
    @Published var visualContextEnabled: Bool { didSet { defaults.set(visualContextEnabled, forKey: Key.visualContextEnabled) } }
    @Published var localToolMutationsEnabled: Bool { didSet { defaults.set(localToolMutationsEnabled, forKey: Key.localToolMutationsEnabled) } }
    @Published var allowSuggestedGameMoveExecution: Bool { didSet { defaults.set(allowSuggestedGameMoveExecution, forKey: Key.allowSuggestedGameMoveExecution) } }
    @Published var gameDecisionMode: AgentGameDecisionMode { didSet { defaults.set(gameDecisionMode.rawValue, forKey: Key.gameDecisionMode) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        autoLoadLanguageModel = Self.bool(defaults, key: Key.autoLoadLanguageModel, defaultValue: true)
        conversationTextAccessEnabled = Self.bool(defaults, key: Key.conversationTextAccessEnabled, defaultValue: true)
        visualContextEnabled = Self.bool(defaults, key: Key.visualContextEnabled, defaultValue: true)
        localToolMutationsEnabled = Self.bool(defaults, key: Key.localToolMutationsEnabled, defaultValue: true)
        allowSuggestedGameMoveExecution = Self.bool(defaults, key: Key.allowSuggestedGameMoveExecution, defaultValue: false)
        let storedMode = defaults.string(forKey: Key.gameDecisionMode)
            .flatMap(AgentGameDecisionMode.init(rawValue:)) ?? .automaticStable
        if storedMode == .experimentalCore {
            gameDecisionMode = .automaticStable
            defaults.set(AgentGameDecisionMode.automaticStable.rawValue, forKey: Key.gameDecisionMode)
        } else {
            gameDecisionMode = storedMode
        }
    }

    func resetToSafeDefaults() {
        autoLoadLanguageModel = true
        conversationTextAccessEnabled = true
        visualContextEnabled = true
        localToolMutationsEnabled = true
        allowSuggestedGameMoveExecution = false
        gameDecisionMode = .automaticStable
    }

    private static func bool(_ defaults: UserDefaults, key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}
