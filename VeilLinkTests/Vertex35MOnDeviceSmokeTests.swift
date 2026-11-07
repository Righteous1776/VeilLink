import XCTest
@testable import VeilLink

#if VERTEX_CHAT_ONLY && canImport(llama)
@MainActor
final class Vertex35MOnDeviceSmokeTests: XCTestCase {
    func testPinnedModelCanGenerateTextWithoutTools() async throws {
        let name = "Vertex-0.6-35M-Instruct-Q4_K_M"
        guard let url = Bundle.main.url(forResource: name, withExtension: "gguf", subdirectory: "LocalAI")
            ?? Bundle.main.url(forResource: name, withExtension: "gguf") else {
            XCTFail("Vertex model not bundled in test-host application")
            return
        }
        let boundary = LingCoreChatOnlyBoundary(runtime: Vertex35MChatRuntime(importedModelURL: url))
        let answer = try await boundary.reply(to: "Hello, say hi.") { _ in }
        XCTAssertFalse(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        boundary.cancel()
    }
}
#endif
