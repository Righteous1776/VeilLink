import XCTest
@testable import VeilLink

final class ImageViewerPolicyTests: XCTestCase {
    func testTargetDevicesGetPurposeBuiltLargeImageBudgets() {
        XCTAssertEqual(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone8,4", previewMaxPixelSize: 640, highDefinitionOverride: false), 1_536)
        XCTAssertEqual(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone9,1", previewMaxPixelSize: 768, highDefinitionOverride: false), 2_048)
        XCTAssertEqual(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone12,8", previewMaxPixelSize: 1_024, highDefinitionOverride: false), 2_560)
        XCTAssertEqual(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone14,2", previewMaxPixelSize: 1_280, highDefinitionOverride: false), 3_072)
    }

    func testGodModeHighDefinitionOverrideAllows4096ViewerDecode() {
        XCTAssertEqual(ImageViewerPolicy.maxPixelSize(machineIdentifier: "iPhone8,4", previewMaxPixelSize: 2_048, highDefinitionOverride: true), 4_096)
    }

    func testUnknownDeviceUsesBoundedFallback() {
        XCTAssertEqual(ImageViewerPolicy.maxPixelSize(machineIdentifier: "unknown", previewMaxPixelSize: 1_024, highDefinitionOverride: false), 2_048)
        XCTAssertEqual(ImageViewerPolicy.maxPixelSize(machineIdentifier: "unknown", previewMaxPixelSize: 2_048, highDefinitionOverride: false), 3_072)
    }
}
