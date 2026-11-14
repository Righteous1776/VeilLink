import XCTest
import UIKit
@testable import VeilLink

@MainActor
final class DeepTelemetryTouchProbeTests: XCTestCase {
    func testGestureClassificationUsesCompletedTouchMovement() {
        XCTAssertEqual(DeepTelemetryTouchPolicy.kind(
            duration: 0.12, distance: 3, dx: 1, dy: 2, fingers: 1), "tap")
        XCTAssertEqual(DeepTelemetryTouchPolicy.kind(
            duration: 1.2, distance: 1, dx: 0, dy: 0, fingers: 1), "long_press")
        XCTAssertEqual(DeepTelemetryTouchPolicy.kind(
            duration: 0.23, distance: 90, dx: -90, dy: 5, fingers: 1), "swipe_left")
        XCTAssertEqual(DeepTelemetryTouchPolicy.kind(
            duration: 0.23, distance: 85, dx: 5, dy: 85, fingers: 1), "swipe_down")
        XCTAssertEqual(DeepTelemetryTouchPolicy.kind(
            duration: 0.33, distance: 60, dx: 50, dy: 10, fingers: 2), "multitouch")
    }

    func testOnlyOwnVisibleNormalApplicationWindowsAreEligible() {
        XCTAssertTrue(DeepTelemetryTouchPolicy.acceptsWindow(
            typeName: "_UIHostingWindow", level: 0, hasRoot: true, hidden: false))
        XCTAssertFalse(DeepTelemetryTouchPolicy.acceptsWindow(
            typeName: "UIRemoteKeyboardWindow", level: 0, hasRoot: true, hidden: false))
        XCTAssertFalse(DeepTelemetryTouchPolicy.acceptsWindow(
            typeName: "UITextEffectsWindow", level: 0, hasRoot: true, hidden: false))
        XCTAssertTrue(DeepTelemetryTouchPolicy.acceptsWindow(
            typeName: "_UIHostingWindow", level: 5, hasRoot: true, hidden: false))
        XCTAssertFalse(DeepTelemetryTouchPolicy.acceptsWindow(
            typeName: "_UIHostingWindow", level: 0, hasRoot: false, hidden: false))
        XCTAssertFalse(DeepTelemetryTouchPolicy.acceptsWindow(
            typeName: "_UIHostingWindow", level: 0, hasRoot: true, hidden: true))
    }

    func testRedactionCoversFocusedTextAndKeyboardEvenOutsidePasswordScreen() {
        XCTAssertFalse(DeepTelemetryTouchPolicy.redactCoordinates(
            sensitiveScreen: false, keyboardVisible: false,
            inputFocused: false, touchedInput: false))
        XCTAssertTrue(DeepTelemetryTouchPolicy.redactCoordinates(
            sensitiveScreen: false, keyboardVisible: true,
            inputFocused: false, touchedInput: false))
        XCTAssertTrue(DeepTelemetryTouchPolicy.redactCoordinates(
            sensitiveScreen: false, keyboardVisible: false,
            inputFocused: true, touchedInput: false))
        XCTAssertTrue(DeepTelemetryTouchPolicy.redactCoordinates(
            sensitiveScreen: false, keyboardVisible: false,
            inputFocused: false, touchedInput: true))
        XCTAssertTrue(DeepTelemetryTouchPolicy.redactCoordinates(
            sensitiveScreen: true, keyboardVisible: false,
            inputFocused: false, touchedInput: false))
    }
}