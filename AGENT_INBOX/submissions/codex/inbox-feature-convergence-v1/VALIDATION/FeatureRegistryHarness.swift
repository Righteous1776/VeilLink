import Foundation

@main
enum FeatureRegistryHarness {
    static func main() throws {
        let features = (0..<5_000).map { index in
            VeilFeatureDescriptor(
                id: String(format: "feature.%04d", index),
                packID: "pack.\(index / 100)",
                title: "功能 \(index)",
                subtitle: index.isMultiple(of: 2) ? "离线工具" : "实时娱乐",
                domain: index.isMultiple(of: 2) ? .utilities : .entertainment,
                keywords: [index.isMultiple(of: 10) ? "里程碑" : "常规"],
                resourceClass: index.isMultiple(of: 7) ? .renderHeavy : .featherweight,
                requiredGates: index.isMultiple(of: 5) ? .releaseBaseline : [],
                conflictGroup: index == 0 || index == 100 ? "sample-conflict" : nil,
                isExperimental: false
            )
        }

        let buildStart = Date()
        let registry = try VeilFeatureRegistry(features: features)
        let buildMilliseconds = Int(Date().timeIntervalSince(buildStart) * 1_000)
        precondition(registry.count == 5_000)
        precondition(registry.feature(id: " FEATURE.4999 ")?.id == "feature.4999")

        let firstPage = registry.query(VeilFeatureQuery(text: "里程碑", domain: .utilities, limit: 40))
        precondition(firstPage.items.count == 40)
        precondition(firstPage.totalCount == 500)
        precondition(firstPage.items.allSatisfy { $0.domain == .utilities })

        let audit = registry.audit()
        precondition(audit.packCounts.count == 50)
        precondition(audit.conflictGroups["sample-conflict"] == ["pack.0", "pack.1"])

        let legacy = VeilFeatureRuntimeProfile(
            isLegacyDevice: true,
            lowPowerMode: false,
            reduceMotion: false,
            godModeHighQuality: false,
            thermalPressure: .nominal
        )
        precondition(registry.launchDecision(for: "feature.0007", profile: legacy, passedGates: []).renderTier == .reduced)

        let queryStart = Date()
        for index in 0..<10_000 {
            precondition(registry.feature(id: "feature.\(String(format: "%04d", index % 5_000))") != nil)
        }
        let queryMilliseconds = Int(Date().timeIntervalSince(queryStart) * 1_000)

        print("REGISTRY_BUILD_5000_MS=\(buildMilliseconds)")
        print("REGISTRY_LOOKUP_10000_MS=\(queryMilliseconds)")
        print("FEATURE_REGISTRY_5000_PASS")
    }
}
