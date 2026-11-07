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
        let runtime = Vertex35MChatRuntime(importedModelURL: url)
        let boundary = LingCoreChatOnlyBoundary(runtime: runtime)
        let answer = try await boundary.reply(to: "Hello, say hi.") { _ in }
        XCTAssertFalse(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertGreaterThan(runtime.lastGenerationStats?.promptTokenCount ?? 0, 0)
        XCTAssertGreaterThan(runtime.lastGenerationStats?.generatedTokenCount ?? 0, 0)
        print("VERTEX35M_ENGLISH_TOKENS input=\(runtime.lastGenerationStats?.promptTokenCount ?? -1) generated=\(runtime.lastGenerationStats?.generatedTokenCount ?? -1)")
        boundary.cancel()
    }
    func testChineseConversationEndToEndAndRecordLanguageQuality() async throws {
        let name = "Vertex-0.6-35M-Instruct-Q4_K_M"
        guard let url = Bundle.main.url(forResource: name, withExtension: "gguf", subdirectory: "LocalAI")
            ?? Bundle.main.url(forResource: name, withExtension: "gguf") else {
            XCTFail("Pinned Vertex GGUF was not bundled")
            return
        }
        let runtime = Vertex35MChatRuntime(importedModelURL: url)
        let boundary = LingCoreChatOnlyBoundary(runtime: runtime)
        let answer = try await boundary.reply(to: "你好，请用简体中文介绍自己。") { _ in }
        let hanCount = answer.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        print("VERTEX35M_CHINESE_QUALITY output_chars=\(answer.count) han_chars=\(hanCount) output_tokens=\(runtime.lastGenerationStats?.generatedTokenCount ?? 0)")
        XCTAssertGreaterThan(runtime.lastGenerationStats?.promptTokenCount ?? 0, 0)
        XCTAssertFalse(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Model produced an empty Chinese conversation reply")
        runtime.unload()
    }

}
#endif
