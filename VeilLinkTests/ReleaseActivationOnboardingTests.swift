import XCTest
@testable import VeilLink

final class ReleaseActivationOnboardingTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "VeilLink.ReleaseActivationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testFirstActivationStartsAtPageZero() {
        let controller = VeilFirstRunOnboardingController(defaults: defaults)
        XCTAssertFalse(controller.isCompleted)
        XCTAssertEqual(controller.resumePage, 0)
    }

    @MainActor
    func testResumePagePersistsUntilCompletion() {
        let controller = VeilFirstRunOnboardingController(defaults: defaults)
        controller.remember(page: 3)

        let relaunched = VeilFirstRunOnboardingController(defaults: defaults)
        XCTAssertFalse(relaunched.isCompleted)
        XCTAssertEqual(relaunched.resumePage, 3)
    }

    @MainActor
    func testCompletionPersistsAndDoesNotReplay() {
        let controller = VeilFirstRunOnboardingController(defaults: defaults)
        controller.complete()

        let relaunched = VeilFirstRunOnboardingController(defaults: defaults)
        XCTAssertTrue(relaunched.isCompleted)
        XCTAssertEqual(relaunched.resumePage, 4)
    }

    @MainActor
    func testPageIsClamped() {
        let controller = VeilFirstRunOnboardingController(defaults: defaults)
        controller.remember(page: 99)
        XCTAssertEqual(controller.resumePage, 4)
    }

    func testLegalPageIsOutsideOnboardingSwipeGestureHierarchy() {
        XCTAssertTrue(VeilReleaseActivationInteractionPolicy.allowsOnboardingSwipe(on: 3))
        XCTAssertFalse(VeilReleaseActivationInteractionPolicy.allowsOnboardingSwipe(on: 4))
        XCTAssertFalse(VeilReleaseActivationInteractionPolicy.allowsOnboardingSwipe(on: 5))
    }
}
