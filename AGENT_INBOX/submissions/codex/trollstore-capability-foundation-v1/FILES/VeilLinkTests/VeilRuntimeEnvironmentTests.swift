import XCTest
@testable import VeilLink

final class VeilRuntimeEnvironmentTests: XCTestCase {
    func testSimulatorWinsOverAllPackagingEvidence() {
        let snapshot = resolve(simulator: true, troll: true, receipt: true, receiptName: "receipt", provision: true)
        XCTAssertEqual(snapshot.channel, .simulator)
    }

    func testTrollStoreMarkerWinsOverReceiptAndProvision() {
        let snapshot = resolve(troll: true, receipt: true, receiptName: "receipt", provision: true)
        XCTAssertEqual(snapshot.channel, .trollStore)
        XCTAssertEqual(snapshot.profile, .enhancedCandidate)
        XCTAssertFalse(snapshot.elevatedEntitlementsVerified)
    }

    func testTrollStoreLiteMarkerIsDistinct() {
        XCTAssertEqual(resolve(trollLite: true).channel, .trollStoreLite)
    }

    func testSandboxReceiptMeansTestFlight() {
        XCTAssertEqual(resolve(receipt: true, receiptName: "sandboxReceipt").channel, .testFlight)
    }

    func testProductionReceiptMeansAppStore() {
        XCTAssertEqual(resolve(receipt: true, receiptName: "receipt").channel, .appStore)
    }

    func testProvisionWithoutReceiptMeansOrdinarySignedInstall() {
        let snapshot = resolve(provision: true)
        XCTAssertEqual(snapshot.channel, .provisioned)
        XCTAssertEqual(snapshot.profile, .standard)
    }

    func testNoEvidenceRemainsUnknownInsteadOfClaimingTrollStore() {
        XCTAssertEqual(resolve().channel, .unknown)
    }

    func testDeclaredBackgroundAndNetworkCapabilitiesAreReported() {
        let snapshot = resolve(modes: ["audio", "fetch", "bluetooth-central", "bluetooth-peripheral"], bonjour: true, live: true)
        XCTAssertEqual(state(.backgroundBluetooth, in: snapshot), .declared)
        XCTAssertEqual(state(.backgroundAudio, in: snapshot), .declared)
        XCTAssertEqual(state(.backgroundRefresh, in: snapshot), .declared)
        XCTAssertEqual(state(.localNetwork, in: snapshot), .declared)
        XCTAssertEqual(state(.liveActivity, in: snapshot), .declared)
    }

    func testTrollStoreOnlyMakesElevatedEntitlementsCandidate() {
        XCTAssertEqual(state(.elevatedEntitlements, in: resolve(troll: true)), .candidate)
        XCTAssertEqual(state(.elevatedEntitlements, in: resolve(provision: true)), .unavailable)
    }

    func testDiagnosticsDoNotContainFilesystemPathsOrPersonalData() {
        let report = resolve(troll: true).diagnosticsReport
        XCTAssertFalse(report.contains("/var/"))
        XCTAssertFalse(report.contains("bundle"))
        XCTAssertTrue(report.contains("channel=trollStore"))
    }

    private func resolve(
        simulator: Bool = false,
        troll: Bool = false,
        trollLite: Bool = false,
        receipt: Bool = false,
        receiptName: String? = nil,
        provision: Bool = false,
        modes: Set<String> = [],
        bonjour: Bool = false,
        live: Bool = false
    ) -> VeilRuntimeEnvironmentSnapshot {
        VeilRuntimeEnvironment.resolve(.init(
            isSimulator: simulator,
            hasTrollStoreMarker: troll,
            hasTrollStoreLiteMarker: trollLite,
            receiptPresent: receipt,
            receiptName: receiptName,
            hasEmbeddedProvision: provision,
            backgroundModes: modes,
            hasBonjourServices: bonjour,
            supportsLiveActivities: live
        ))
    }

    private func state(
        _ kind: VeilRuntimeCapability.Kind,
        in snapshot: VeilRuntimeEnvironmentSnapshot
    ) -> VeilCapabilityState? {
        snapshot.capabilities.first { $0.kind == kind }?.state
    }
}
