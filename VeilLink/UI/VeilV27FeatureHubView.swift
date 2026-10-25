import SwiftUI

struct VeilV27FeatureHubView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeFeatureID: String?

    private static let registry: VeilFeatureRegistry = {
        let items: [VeilFeatureDescriptor] = [
            item("v27.mission-control", "mission-control-r1", "任务控制台", "20 项离线通信与会话诊断", .diagnostics, .standard, ["诊断", "通信", "安全"]),
            item("v27.rare-lab", "rare-lab-r1", "RareLab", "40 项离线稀有分析运算器", .experimental, .standard, ["分析", "取证", "实验"]),
            item("v27.productivity", "feature-century-f1", "效率实验室", "模板、差异、合并与时区规划", .productivity, .featherweight, ["文本", "合并", "时区"]),
            item("v27.emotion-garden", "emotion-value-v1", "情绪花园", "1,000 条可交互微仪式", .emotion, .standard, ["陪伴", "情绪", "计时"]),
            item("v27.aether-lab", "aether-lab-r1", "AetherLab", "100 项本地算法实验", .experimental, .standard, ["算法", "信号", "几何"]),
            item("v27.story-lab", "entertainment-e01", "故事实验室", "分支叙事与多结局体验", .entertainment, .standard, ["剧情", "选择", "结局"]),
            item("v27.rhythm", "entertainment-r7", "实时节奏远征", "SpriteKit 实时判定与原生渲染", .games, .renderHeavy, ["节奏", "实时", "SpriteKit"]),
            item("v27.lattice", "lattice-clash-v1", "晶格冲突", "确定性单机策略对战", .games, .standard, ["策略", "单机", "棋盘"]),
            item("v27.qr-reader", "practical-qr-r1", "离线二维码", "相机扫描与本地文本交换", .communication, .featherweight, ["二维码", "相机", "配对"]),
            item("v27.html-reader", "practical-html-r2", "离线 HTML 阅读器", "从文件提取正文并搜索", .utilities, .standard, ["HTML", "文件", "阅读"]),
            item("v27.backup-preflight", "backup-preflight-r3", "备份安全体检", "恢复前检查 ZIP 结构与完整性", .utilities, .standard, ["备份", "ZIP", "CRC"])
        ]
        return try! VeilFeatureRegistry(features: items)
    }()

    var body: some View {
        ZStack {
            VeilFeatureLibraryView(
                registry: Self.registry,
                profile: runtimeProfile,
                passedGates: [],
                onOpen: { activeFeatureID = $0 }
            )

            NavigationLink(
                destination: destination,
                isActive: Binding(
                    get: { activeFeatureID != nil },
                    set: { if !$0 { activeFeatureID = nil } }
                ),
                label: { EmptyView() }
            )
            .hidden()
        }
    }

    private var destination: AnyView {
        switch activeFeatureID {
        case "v27.mission-control": return AnyView(VeilMissionControlView())
        case "v27.rare-lab": return AnyView(VeilRareLabView())
        case "v27.productivity": return AnyView(VeilProductivityLabView())
        case "v27.emotion-garden": return AnyView(VeilEmotionGardenView())
        case "v27.aether-lab": return AnyView(VeilAetherLabView())
        case "v27.story-lab": return AnyView(VeilStoryLabView())
        case "v27.rhythm": return AnyView(VeilRhythmR6NativeGameView())
        case "v27.lattice": return AnyView(LatticeClashLabView())
        case "v27.qr-reader": return AnyView(VeilOfflineQRReaderView())
        case "v27.html-reader": return AnyView(VeilOfflineHTMLReaderView())
        case "v27.backup-preflight": return AnyView(VeilBackupPreflightView())
        default: return AnyView(EmptyView())
        }
    }

    private var runtimeProfile: VeilFeatureRuntimeProfile {
        let thermal: VeilFeatureRuntimeProfile.ThermalPressure
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .serious
        }
        return VeilFeatureRuntimeProfile(
            isLegacyDevice: VeilRenderProfile.usesLegacyCompositorPath,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            reduceMotion: reduceMotion,
            godModeHighQuality: VeilPerformanceOverrides.forceFullVisualEffects,
            thermalPressure: thermal
        )
    }

    private static func item(
        _ id: String,
        _ packID: String,
        _ title: String,
        _ subtitle: String,
        _ domain: VeilFeatureDomain,
        _ resourceClass: VeilFeatureResourceClass,
        _ keywords: [String]
    ) -> VeilFeatureDescriptor {
        VeilFeatureDescriptor(
            id: id,
            packID: packID,
            title: title,
            subtitle: subtitle,
            domain: domain,
            keywords: keywords,
            resourceClass: resourceClass,
            requiredGates: [],
            conflictGroup: nil,
            isExperimental: domain == .experimental
        )
    }
}
