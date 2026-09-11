import XCTest
import UIKit
@testable import VeilLink

final class TransferShardViewTests: XCTestCase {
    func testShardFactoryProducesThirtyPixelAlignedPieces() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 600), format: format).image { context in
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 500, height: 600))
        }

        let shards = TransferShardImageFactory.makeShards(from: source)

        XCTAssertEqual(shards.count, 30)
        XCTAssertTrue(shards.allSatisfy { $0.cgImage?.width == 100 })
        XCTAssertTrue(shards.allSatisfy { $0.cgImage?.height == 100 })
    }

    func testShardFactoryRejectsImagesTooSmallToSplitSafely() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 5), format: format).image { _ in }

        XCTAssertTrue(TransferShardImageFactory.makeShards(from: source).isEmpty)
    }
}
