#if canImport(UIKit) && canImport(SpriteKit)
import XCTest
import SpriteKit
import UIKit
@testable import VeilLink

/// Apple-SDK-only tests. These are NOT executed by Linux SwiftPM.
@MainActor final class VeilRhythmNativeSceneSmokeTests: XCTestCase {
    func testSceneHasFixedCanvasAndAspectFit() {
        let scene = VeilRhythmNativeScene(size: CGSize(width:390,height:600))
        XCTAssertEqual(scene.size.width,390)
        XCTAssertEqual(scene.size.height,600)
        XCTAssertEqual(scene.scaleMode,.aspectFit)
    }
    func testDifferentViewportDoesNotMutateWorldSize() {
        let scene = VeilRhythmNativeScene(size: CGSize(width:390,height:600))
        let view = SKView(frame: CGRect(x:0,y:0,width:375,height:667))
        view.isUserInteractionEnabled = false
        view.presentScene(scene)
        XCTAssertEqual(scene.size,CGSize(width:390,height:600))
        view.frame = CGRect(x:0,y:0,width:1024,height:768)
        XCTAssertEqual(scene.size,CGSize(width:390,height:600))
        XCTAssertFalse(view.isUserInteractionEnabled)
    }
}
#endif
