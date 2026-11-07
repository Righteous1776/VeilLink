import XCTest
@testable import VeilopolyUI

final class VeilopolyIOS15DeploymentPolicyTests: XCTestCase {
 func testDeploymentContractIsIOS15() {
  XCTAssertEqual(VeilopolyDeploymentPolicy.minimumIOSMajorVersion, 15)
  XCTAssertEqual(VeilopolyDeploymentPolicy.referenceBoardDesignSize.width, 1024)
  XCTAssertEqual(VeilopolyDeploymentPolicy.referenceBoardDesignSize.height, 940)
  XCTAssertFalse(VeilopolyDeploymentPolicy.requiresIOS16SceneGeometryUpdate)
 }
}
