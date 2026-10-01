import XCTest
@testable import VeilLink

@MainActor
private final class TestA10UltraComputeRuntime: A10UltraComputeRuntime {
    var state: A10UltraComputeState = .unloaded
    var lastBudget: A10UltraComputeBudget?
    let manifest = A10UltraComputeManifest(
        runtimeID: "test.a10.ultra.compute",
        displayName: "A10 Ultra Ω Test Compute",
        abiVersion: 1,
        artifactDigest: "test-digest",
        supportedTasks: [.textGeneration, .structuredReasoning],
        supportsStreaming: true,
        supportsCancellation: true,
        supportsStateSnapshot: true,
        minimumOSMajor: 15,
        notes: "test"
    )

    func prepare() async throws { state = .ready }

    func generateText(
        request: AgentTextRequest,
        onToken: @escaping @MainActor @Sendable (String) -> Void
    ) async throws -> AgentTextResult {
        state = .computing
        onToken("A10")
        state = .ready
        return AgentTextResult(text: "A10", emittedChunkCount: 1, estimatedTokenCount: 1)
    }

    func applyBudget(_ budget: A10UltraComputeBudget) { lastBudget = budget }
    func cancel() { if state == .computing { state = .ready } }
    func trimMemory() {}
    func unload() { state = .unloaded }
}

@MainActor
final class ThreeCoreIntegrationTests: XCTestCase {
    func testA10LanguageAdapterExposesComputeRuntimeWithoutHostMutationAPI() async throws {
        let runtime = TestA10UltraComputeRuntime()
        let adapter = A10UltraLanguageRuntimeAdapter(runtime: runtime)
        try await adapter.prepare()
        XCTAssertEqual(adapter.state, .ready)
        XCTAssertEqual(adapter.backendName, "A10 Ultra Ω Compute")
        XCTAssertEqual(adapter.manifest?.id, "test.a10.ultra.compute")
    }

    func testCoordinatorCanOverrideAndRestoreBaseLanguageRuntime() {
        let base = MockLocalTextModelRuntime()
        let coordinator = LocalTextModelCoordinator(runtime: base)
        XCTAssertFalse(coordinator.isUsingOverride)

        let runtime = TestA10UltraComputeRuntime()
        coordinator.activateOverride(A10UltraLanguageRuntimeAdapter(runtime: runtime))
        XCTAssertTrue(coordinator.isUsingOverride)
        XCTAssertEqual(coordinator.backendName, "A10 Ultra Ω Compute")

        coordinator.restoreBaseRuntime()
        XCTAssertFalse(coordinator.isUsingOverride)
    }

    func testThreeCoreInitialSnapshotKeepsMutationAuthorityInHost() {
        let snapshot = VeilThreeCoreSnapshot.initial(languageBackend: "foundation-mock", budgetMode: "balanced")
        XCTAssertEqual(snapshot.phase, .insertionReady)
        XCTAssertEqual(snapshot.a9Role, .governance)
        XCTAssertEqual(snapshot.a10Role, .compute)
        XCTAssertEqual(snapshot.lingCoreRole, .orchestration)
        XCTAssertEqual(snapshot.mutationAuthorityOwner, "VEILLINK_HOST_ACTION_LAYER")
    }
}
