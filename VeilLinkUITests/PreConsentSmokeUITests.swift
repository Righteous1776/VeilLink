import XCTest

final class PreConsentSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testUnsignedFirstLaunchKeepsDiagnosticsReachable() {
        let app = XCUIApplication()
        app.launch()

        // The isolated pre-consent exporter must be accessible before sign-in,
        // without creating a profile or granting Bluetooth/network permission.
        let export = app.buttons["preconsent.blackbox.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 20),
                      "Unsigned launch must expose the isolated black-box control.")
        XCTAssertTrue(export.isHittable,
                      "System appearance, safe-area and onboarding overlays must not swallow taps.")
    }
}
