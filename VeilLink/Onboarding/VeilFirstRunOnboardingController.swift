import Combine
import Foundation

@MainActor
final class VeilFirstRunOnboardingController: ObservableObject {
    static let schemaVersion = "release-activation-v1"

    @Published private(set) var isCompleted: Bool
    @Published private(set) var resumePage: Int

    private let defaults: UserDefaults
    private let completionKey: String
    private let pageKey: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        completionKey = "release.onboarding.completed.\(Self.schemaVersion)"
        pageKey = "release.onboarding.page.\(Self.schemaVersion)"
        isCompleted = defaults.bool(forKey: completionKey)
        resumePage = min(max(defaults.integer(forKey: pageKey), 0), 4)
    }

    func remember(page: Int) {
        guard !isCompleted else { return }
        let clamped = min(max(page, 0), 4)
        resumePage = clamped
        defaults.set(clamped, forKey: pageKey)
    }

    func complete() {
        isCompleted = true
        resumePage = 4
        defaults.set(true, forKey: completionKey)
        defaults.set(4, forKey: pageKey)
    }

    #if DEBUG
    func resetForTesting() {
        defaults.removeObject(forKey: completionKey)
        defaults.removeObject(forKey: pageKey)
        isCompleted = false
        resumePage = 0
    }
    #endif
}
