import XCTest
@testable import VeilLink

final class VeilOpponentAvatarPolicyTests: XCTestCase {
    func testSwitchIsOffUnlessExplicitlyEnabled() {
        XCTAssertFalse(VeilOpponentAvatarPolicy.shouldRender(enabled: false, hasComputerOpponent: true))
        XCTAssertTrue(VeilOpponentAvatarPolicy.shouldRender(enabled: true, hasComputerOpponent: true))
        XCTAssertFalse(VeilOpponentAvatarPolicy.shouldRender(enabled: true, hasComputerOpponent: false))
    }

    func testSafeFramePacing() {
        XCTAssertEqual(VeilOpponentAvatarPolicy.frameInterval(lowPower: false), 1.0 / 30.0)
        XCTAssertEqual(VeilOpponentAvatarPolicy.frameInterval(lowPower: true), 1.0 / 15.0)
    }

    func testOwnerKeyAndMood() {
        XCTAssertEqual(VeilOpponentAvatarPolicy.preferenceKey, "owner.grokbot.original.enabled.v1")
        XCTAssertEqual(VeilOpponentAvatarMood.thinking.label, "正在思考")
        XCTAssertEqual(VeilOpponentAvatarMood.won.label, "电脑获胜")
    }

    func testMotionStopsInBackgroundOrReducedMotion() {
        XCTAssertTrue(VeilOpponentAvatarPolicy.shouldAnimate(
            reduceMotion: false, sceneIsActive: true
        ))
        XCTAssertFalse(VeilOpponentAvatarPolicy.shouldAnimate(
            reduceMotion: false, sceneIsActive: false
        ))
        XCTAssertFalse(VeilOpponentAvatarPolicy.shouldAnimate(
            reduceMotion: true, sceneIsActive: true
        ))
    }

    func testSpringResponseIsFiniteAndSettles() {
        XCTAssertEqual(VeilOpponentAvatarPolicy.rebound(elapsed: 0), 0)
        XCTAssertLessThan(abs(VeilOpponentAvatarPolicy.rebound(elapsed: 3)), 0.0001)
        XCTAssertLessThanOrEqual(abs(VeilOpponentAvatarPolicy.rebound(elapsed: 0.5)), 1)
        XCTAssertTrue(VeilOpponentAvatarPolicy.rebound(elapsed: 1000).isFinite)
    }
    func testRoundedVideoCardScalesWithAvatar() {
        XCTAssertEqual(VeilOpponentAvatarPolicy.videoCornerRadius(for: 42), 12.6, accuracy: 0.001)
        XCTAssertEqual(VeilOpponentAvatarPolicy.videoCornerRadius(for: 76), 22.8, accuracy: 0.001)
        XCTAssertEqual(VeilOpponentAvatarPolicy.videoCornerRadius(for: 112), 26, accuracy: 0.001)
        XCTAssertEqual(VeilOpponentAvatarPolicy.videoCornerRadius(for: 0), 0)
    }

}
