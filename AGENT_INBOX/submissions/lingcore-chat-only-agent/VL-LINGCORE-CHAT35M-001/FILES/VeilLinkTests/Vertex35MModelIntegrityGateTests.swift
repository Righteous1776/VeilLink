import XCTest
@testable import VeilLink

final class Vertex35MModelIntegrityGateTests: XCTestCase {
    func testGGUFV3Header() {
        XCTAssertTrue(Vertex35MModelIntegrityGate.isGGUFv3Header(
            Data([0x47, 0x47, 0x55, 0x46, 0x03, 0, 0, 0])
        ))
        XCTAssertFalse(Vertex35MModelIntegrityGate.isGGUFv3Header(Data("NOT-GGUF".utf8)))
        XCTAssertFalse(Vertex35MModelIntegrityGate.isGGUFv3Header(Data()))
    }

    func testSizeCheckFailsClosedWithoutLoadingWeights() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("GGUF".utf8).write(to: url)
        do {
            try await Vertex35MModelIntegrityGate.validate(url: url)
            XCTFail("Expected rejection of truncated GGUF")
        } catch Vertex35MModelIntegrityGate.Failure.wrongSize {
            // Correct: truncated artifact cannot be loaded.
        }
    }
}
