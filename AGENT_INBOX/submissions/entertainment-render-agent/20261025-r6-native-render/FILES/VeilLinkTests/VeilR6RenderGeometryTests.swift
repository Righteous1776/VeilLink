import XCTest
@testable import VeilMegaEngines

final class VeilR6RenderGeometryTests: XCTestCase {
    typealias G = VeilRenderGeometry
    func testNoAspectDistortionAcrossScreens() throws {
        let devices = [G.Size(375,667), G.Size(390,844), G.Size(428,926), G.Size(768,1024), G.Size(1024,768), G.Size(320,568), G.Size(800,600), G.Size(390,390)]
        for device in devices {
            let p = try G.fit(canvas: .init(390,600), in: device)
            XCTAssertEqual(p.aspectDistortion, 0, accuracy: 1e-9)
            XCTAssertLessThanOrEqual(p.viewport.width, device.width+1e-9)
            XCTAssertLessThanOrEqual(p.viewport.height, device.height+1e-9)
        }
    }
    func testRoundTripScreenTouchMapping() throws {
        for device in [G.Size(375,667), G.Size(390,844), G.Size(768,1024), G.Size(1024,768)] {
            let p = try G.fit(canvas: .init(390,600), in: device)
            for pt in [G.Point(0,0), G.Point(100,200), G.Point(195,300), G.Point(390,600)] {
                let roundtrip = try XCTUnwrap(p.toLogical(p.toView(pt)))
                XCTAssertEqual(roundtrip.x, pt.x, accuracy: 1e-7)
                XCTAssertEqual(roundtrip.y, pt.y, accuracy: 1e-7)
            }
        }
    }
    func testLetterboxIsNotInteractive() throws {
        let p = try G.fit(canvas: .init(390,600), in: .init(1024,768))
        XCTAssertNil(p.toLogical(.init(0,0)))
        XCTAssertNil(p.toLogical(.init(1024,768)))
        XCTAssertNotNil(p.toLogical(p.toView(.init(195,300))))
    }
    func testSafeInsetsAreRespected() throws {
        let p = try G.fit(canvas: .init(390,600), in: .init(390,844), insets: .init(top: 47, bottom: 34))
        XCTAssertGreaterThanOrEqual(p.viewport.y,47)
        XCTAssertLessThanOrEqual(p.viewport.y+p.viewport.height,810)
    }
    func testRejectInvalidDimensionsAndInsets() throws {
        XCTAssertThrowsError(try G.fit(canvas:.init(0,600),in:.init(300,500)))
        XCTAssertThrowsError(try G.fit(canvas:.init(390,600),in:.init(.nan,500)))
        XCTAssertThrowsError(try G.fit(canvas:.init(390,600),in:.init(100,100),insets:.init(top:80,bottom:80)))
        XCTAssertThrowsError(try G.fit(canvas:.init(390,600),in:.init(100,100),pixelsPerPoint:.infinity))
    }
    func testSpriteKitYFlipsOnceOnly() throws {
        let p = try G.fit(canvas: .init(390,600), in:.init(390,600))
        XCTAssertEqual(p.toSpriteKit(.init(200,80)),.init(200,520))
        XCTAssertEqual(p.toSpriteKit(.init(200,500)),.init(200,100))
    }
    func testPixelSizeOnlyChangesDensity() throws {
        let p1 = try G.fit(canvas: .init(390,600), in:.init(390,600),pixelsPerPoint:1)
        let p3 = try G.fit(canvas: .init(390,600), in:.init(390,600),pixelsPerPoint:3)
        XCTAssertEqual(p1.viewport,p3.viewport)
        XCTAssertEqual(p3.drawablePixels.width,3*p1.drawablePixels.width)
    }
    func testFuzzViewportsAreFinite() throws {
        for w in stride(from: 240.0, through: 1280.0, by: 17.0) {
            for h in stride(from: 240.0, through: 930.0, by: 37.0) {
                let p = try G.fit(canvas: .init(390,600), in:.init(w,h))
                XCTAssertTrue(p.scale.isFinite)
                XCTAssertEqual(p.aspectDistortion,0,accuracy:1e-9)
                XCTAssertNotNil(p.toLogical(p.toView(.init(195,300))))
            }
        }
    }
}
