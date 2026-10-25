import XCTest
@testable import VeilLink

final class VeilFeatureRegistryTests: XCTestCase {
    func testRejectsCaseInsensitiveDuplicateIDs() {
        XCTAssertThrowsError(try VeilFeatureRegistry(features: [feature(id: "tool.one"), feature(id: "TOOL.ONE")])) {
            XCTAssertEqual($0 as? VeilFeatureRegistryError, .duplicateID("TOOL.ONE"))
        }
    }

    func testIndexedLookupAndPagedQueryAreBounded() throws {
        let features = (0..<250).map { feature(id: "tool.\($0)", domain: $0.isMultiple(of: 2) ? .utilities : .productivity) }
        let registry = try VeilFeatureRegistry(features: features)

        XCTAssertEqual(registry.count, 250)
        XCTAssertEqual(registry.feature(id: " TOOL.249 ")?.id, "tool.249")
        let first = registry.query(VeilFeatureQuery(limit: 30))
        XCTAssertEqual(first.items.count, 30)
        XCTAssertEqual(first.totalCount, 250)
        XCTAssertTrue(first.hasMore)
        let clamped = registry.query(VeilFeatureQuery(offset: 240, limit: 500))
        XCTAssertEqual(clamped.items.count, 10)
        XCTAssertFalse(clamped.hasMore)
    }

    func testSearchNormalizesCaseWidthAndDiacritics() throws {
        let registry = try VeilFeatureRegistry(features: [
            feature(id: "emotion.cafe", title: "Café 安静陪伴", keywords: ["ＥＭＯＴＩＯＮ"]),
            feature(id: "game.rain", title: "雨线列车", domain: .games)
        ])

        XCTAssertEqual(registry.query(VeilFeatureQuery(text: "cafe")).items.map(\.id), ["emotion.cafe"])
        XCTAssertEqual(registry.query(VeilFeatureQuery(text: "emotion")).items.map(\.id), ["emotion.cafe"])
        XCTAssertEqual(registry.query(VeilFeatureQuery(text: "列车", domain: .games)).items.map(\.id), ["game.rain"])
    }

    func testLaunchGateFailsClosedWithReadableMissingChecks() throws {
        let guarded = feature(id: "guarded", requiredGates: [.p0TouchVerified, .appleBuildVerified])
        let registry = try VeilFeatureRegistry(features: [guarded])
        let decision = registry.launchDecision(
            for: "guarded",
            profile: profile(),
            passedGates: [.p0TouchVerified]
        )

        XCTAssertEqual(decision.state, .blocked)
        XCTAssertFalse(decision.canLaunch)
        XCTAssertTrue(decision.reason?.contains("Apple 构建") == true)
    }

    func testLegacyDeviceAdaptsWhileGodModeForcesHighQuality() throws {
        let registry = try VeilFeatureRegistry(features: [feature(id: "render", resourceClass: .renderHeavy)])
        let legacy = registry.launchDecision(
            for: "render",
            profile: profile(isLegacy: true),
            passedGates: []
        )
        XCTAssertEqual(legacy.state, .degraded)
        XCTAssertEqual(legacy.renderTier, .reduced)

        let god = registry.launchDecision(
            for: "render",
            profile: profile(isLegacy: true, godMode: true),
            passedGates: []
        )
        XCTAssertEqual(god.state, .available)
        XCTAssertEqual(god.renderTier, .high)
    }

    func testCriticalThermalPressureDefersHeavyRenderEvenInGodMode() throws {
        let registry = try VeilFeatureRegistry(features: [feature(id: "render", resourceClass: .renderHeavy)])
        let decision = registry.launchDecision(
            for: "render",
            profile: profile(godMode: true, thermal: .critical),
            passedGates: []
        )
        XCTAssertEqual(decision.state, .thermallyDeferred)
        XCTAssertFalse(decision.canLaunch)
    }

    func testAuditCountsPacksAndSurfacesCrossPackConflictGroups() throws {
        let registry = try VeilFeatureRegistry(features: [
            feature(id: "mission.a", pack: "mission-a", conflictGroup: "mission-control-r1"),
            feature(id: "mission.b", pack: "mission-b", conflictGroup: "mission-control-r1"),
            feature(id: "emotion.1", pack: "emotion")
        ])
        let audit = registry.audit()
        XCTAssertEqual(audit.featureCount, 3)
        XCTAssertEqual(audit.packCounts["emotion"], 1)
        XCTAssertEqual(audit.conflictGroups["mission-control-r1"], ["mission-a", "mission-b"])
    }

    private func feature(
        id: String,
        pack: String = "test-pack",
        title: String = "测试功能",
        domain: VeilFeatureDomain = .utilities,
        keywords: [String] = [],
        resourceClass: VeilFeatureResourceClass = .featherweight,
        requiredGates: VeilFeatureGate = [],
        conflictGroup: String? = nil
    ) -> VeilFeatureDescriptor {
        VeilFeatureDescriptor(
            id: id,
            packID: pack,
            title: title,
            subtitle: "用于注册表测试",
            domain: domain,
            keywords: keywords,
            resourceClass: resourceClass,
            requiredGates: requiredGates,
            conflictGroup: conflictGroup,
            isExperimental: false
        )
    }

    private func profile(
        isLegacy: Bool = false,
        godMode: Bool = false,
        thermal: VeilFeatureRuntimeProfile.ThermalPressure = .nominal
    ) -> VeilFeatureRuntimeProfile {
        VeilFeatureRuntimeProfile(
            isLegacyDevice: isLegacy,
            lowPowerMode: false,
            reduceMotion: false,
            godModeHighQuality: godMode,
            thermalPressure: thermal
        )
    }
}
