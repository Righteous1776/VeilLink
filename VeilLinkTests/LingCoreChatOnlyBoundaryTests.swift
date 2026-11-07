import XCTest
@testable import VeilLink

@MainActor
final class LingCoreChatOnlyBoundaryTests: XCTestCase {
    private final class RuntimeSpy: LocalTextModelRuntime {
        var state: AgentRuntimeState = .unloaded
        let manifest: LocalTextModelManifest? = nil
        var lastRequest: AgentTextRequest?
        var generateCount = 0

        func prepare() async throws { state = .ready }

        func generate(
            request: AgentTextRequest,
            onToken: @escaping @MainActor @Sendable (String) -> Void
        ) async throws -> AgentTextResult {
            lastRequest = request
            generateCount += 1
            onToken("hello")
            return AgentTextResult(
                text: "hello",
                emittedChunkCount: 1,
                estimatedTokenCount: 1
            )
        }

        func cancel() { state = .ready }
        func trimMemory() {}
        func unload() { state = .unloaded }
    }

    func testRequestNeverReceivesPrivilegedContext() async throws {
        let spy = RuntimeSpy()
        let boundary = LingCoreChatOnlyBoundary(runtime: spy)

        let reply = try await boundary.reply(to: "/game move") { _ in }

        XCTAssertEqual(reply, "hello")
        XCTAssertEqual(spy.generateCount, 1)
        XCTAssertEqual(spy.lastRequest?.userText, "/game move")
        XCTAssertNil(spy.lastRequest?.visualContext)
        XCTAssertNil(spy.lastRequest?.localContext)
        XCTAssertEqual(spy.lastRequest?.maxNewTokens, 96)
        XCTAssertEqual(boundary.messageCount, 2)
        // The literal text "/game move" is only a prompt here: there is no
        // AgentToolRouter or host action-layer dependency in the boundary.
    }

    func testLongPromptRejectedBeforeInference() async {
        let spy = RuntimeSpy()
        let boundary = LingCoreChatOnlyBoundary(runtime: spy)

        do {
            _ = try await boundary.reply(to: String(repeating: "x", count: 513)) { _ in }
            XCTFail("Expected input rejection")
        } catch {
            XCTAssertEqual(spy.generateCount, 0)
        }
    }

    func testClearRemovesConversationMemory() async throws {
        let spy = RuntimeSpy()
        let boundary = LingCoreChatOnlyBoundary(runtime: spy)
        _ = try await boundary.reply(to: "hello") { _ in }
        boundary.clear()
        XCTAssertEqual(boundary.messageCount, 0)
    }

    private final class SuspendedRuntimeSpy: LocalTextModelRuntime {
        var state: AgentRuntimeState = .ready
        let manifest: LocalTextModelManifest? = nil
        var pending: CheckedContinuation<AgentTextResult, Never>?
        var didStart: (() -> Void)?

        func prepare() async throws { state = .ready }
        func generate(request: AgentTextRequest,
                      onToken: @escaping @MainActor @Sendable (String) -> Void) async throws -> AgentTextResult {
            await withCheckedContinuation { continuation in
                pending = continuation
                didStart?()
            }
        }
        func finish() {
            pending?.resume(returning: AgentTextResult(text: "late response", emittedChunkCount: 1, estimatedTokenCount: 2))
            pending = nil
        }
        func cancel() { }
        func trimMemory() { }
        func unload() { state = .unloaded }
    }

    func testClearCannotRestoreLateGeneratedHistory() async throws {
        let spy = SuspendedRuntimeSpy()
        let boundary = LingCoreChatOnlyBoundary(runtime: spy)
        let started = expectation(description: "inference started")
        spy.didStart = { started.fulfill() }
        let inFlight = Task { try await boundary.reply(to: "hello") { _ in } }
        await fulfillment(of: [started], timeout: 5)
        boundary.clear()
        spy.finish()
        do {
            _ = try await inFlight.value
            XCTFail("Cleared session must reject stale inference completion")
        } catch AgentRuntimeError.cancelled {
            XCTAssertEqual(boundary.messageCount, 0)
        }
    }
    func testChineseInputIsForwardedVerbatimWithoutPrivilegedContext() async throws {
        let spy = RuntimeSpy()
        let boundary = LingCoreChatOnlyBoundary(runtime: spy)
        let query = "你好！请用中文介绍一下自己。"
        _ = try await boundary.reply(to: query) { _ in }
        XCTAssertEqual(spy.lastRequest?.userText, query)
        XCTAssertNil(spy.lastRequest?.visualContext)
        XCTAssertNil(spy.lastRequest?.localContext)
    }

    func testMixedChineseEmojiInputNeverExecutesSlashCommand() async throws {
        let spy = RuntimeSpy()
        let boundary = LingCoreChatOnlyBoundary(runtime: spy)
        let query = "你好 👋 /ble refresh 只是文字"
        _ = try await boundary.reply(to: query) { _ in }
        XCTAssertEqual(spy.lastRequest?.userText, query)
        XCTAssertEqual(spy.generateCount, 1)
    }

}
