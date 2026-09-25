import XCTest
@testable import VeilLink

@MainActor
final class VeilTalkLiteRuntimeTests: XCTestCase {
    func testManifestIsZeroWeight() {
        let runtime = VeilTalkLiteRuntime()
        XCTAssertEqual(runtime.manifest?.displayName, "VeilTalk Lite")
        XCTAssertEqual(runtime.manifest?.byteCount, 0)
        XCTAssertEqual(runtime.manifest?.quantization, "none")
    }

    func testFactoryCoreBackendIsVeilTalkLite() {
        #if !canImport(llama)
        XCTAssertEqual(LocalTextModelRuntimeFactory.backendName, "VeilTalk Lite")
        XCTAssertFalse(LocalTextModelRuntimeFactory.isRealLocalInferenceCompiled)
        #endif
    }

    func testReplyDoesNotPretendToBeLLM() {
        let reply = VeilTalkLiteRuntime.reply(to: "你是什么模型", localContext: nil)
        XCTAssertTrue(reply.contains("没有内置大语言模型"))
        XCTAssertFalse(reply.contains("Foundation Mock"))
    }
}
