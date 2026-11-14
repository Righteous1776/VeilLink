import ImageIO
import UIKit
import XCTest
@testable import VeilLink

final class ImageTranscoderTests: XCTestCase {
    func testAggressiveOutputStaysDecodableAndWithinWireLimit() throws {
        let size = CGSize(width: 1_800, height: 1_200)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for i in 0..<160 {
                UIColor(
                    hue: CGFloat(i % 29) / 29, saturation: 0.55,
                    brightness: 0.6 + CGFloat(i % 5) / 15, alpha: 1
                ).setFill()
                context.fill(CGRect(
                    x: CGFloat((i * 53) % 1_800), y: CGFloat((i * 79) % 1_200),
                    width: 150, height: 90
                ))
            }
            ("Readable screenshot text" as NSString).draw(
                at: CGPoint(x: 70, y: 80),
                withAttributes: [.font: UIFont.systemFont(ofSize: 42)]
            )
        }
        let sourceData = try XCTUnwrap(image.pngData())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("veil-image-test-\(UUID().uuidString).png")
        try sourceData.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        for profile: ImageTransportProfile in [.bluetooth, .fastLAN] {
            let result = try ImageTranscoder.prepareSynchronously(at: url, profile: profile)
            XCTAssertTrue(MediaTransferPolicy.supportsImageMIMEType(result.mimeType))
            XCTAssertTrue(MediaTransferPolicy.mayTransmit(byteCount: result.data.count))
            XCTAssertLessThanOrEqual(result.data.count, sourceData.count)
            let decodedSource = try XCTUnwrap(
                CGImageSourceCreateWithData(result.data as CFData, nil)
            )
            let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(decodedSource, 0, nil))
            XCTAssertEqual(decoded.width, result.pixelWidth)
            XCTAssertEqual(decoded.height, result.pixelHeight)
            XCTAssertGreaterThan(decoded.width, 0)
            XCTAssertGreaterThan(decoded.height, 0)
            XCTAssertLessThanOrEqual(max(decoded.width, decoded.height), 4_096)
        }
    }
}
