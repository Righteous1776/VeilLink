import SwiftUI
import Foundation

struct TacticalLandscapeShellV2: View {
    let map: TacticalV2.Map
    let redacted: TacticalV2.RedactedTacticalViewV2
    let supplyField: TacticalV2.SupplyFieldV1?
    let simulationTurn: Int32
    let onSubmitOrder: (TacticalV2.OrderV2) -> Void

    @State private var overlay: TacticalV2.TacticalOverlayV2 = .battlefield
    @State private var selectedFriendlyID: String?
    @State private var viewport = TacticalV2.NormalizedRectV2(
        minX: 0, minY: 0, maxX: 1, maxY: 1
    )
    @State private var zoom: Double = 0.82
    @State private var routePlanner = TacticalV2.RouteDragPlannerV2()
    @State private var routePreview: TacticalV2.RoutePlanV2?


    private var objectiveDefinitions: [TacticalV2.ObjectiveDefinitionV2] {
        TacticalV2.GuanduObjectivesV2.definitions(map: map)
    }

    private var operationalField: TacticalV2.OperationalFieldV2 {
        TacticalV2.OperationalFieldBuilderV2.build(
            map: map,
            redacted: redacted,
            supplyField: supplyField,
            objectives: objectiveDefinitions
        )
    }

    private var commandAssessment: TacticalV2.CommandAssessmentV2? {
        TacticalV2.CommandAssessmentBuilderV2.assess(
            route: routePreview,
            field: operationalField,
            objectives: operationalField.objectives,
            map: map
        )
    }

    private var sectorIndex: TacticalV2.SectorIndexV2 {
        TacticalV2.SectorIndexV2(map: map)
    }

    private var renderSnapshot: TacticalV2.MapRenderSnapshotV2 {
        TacticalV2.MapRenderSnapshotBuilderV2.build(
            map: map,
            sectorIndex: sectorIndex,
            viewport: viewport,
            zoom: zoom,
            overlay: overlay,
            redacted: redacted,
            operational: operationalField
        )
    }

    private var selectedFriendly: TacticalV2.RedactedTacticalViewV2.FriendlyFormation? {
        guard let selectedFriendlyID else { return nil }
        return redacted.friendlies.first { $0.id == selectedFriendlyID }
    }


    private var confirmedEnemyCount: Int {
        redacted.enemyMarkers.filter { $0.level == .confirmed }.count
    }

    private var partialEnemyCount: Int {
        redacted.enemyMarkers.filter { $0.level == .partial }.count
    }

    private var suspectedEnemyCount: Int {
        redacted.enemyMarkers.filter { $0.level == .suspected }.count
    }

    private var visibleCoverage: Double {
        guard !map.cells.isEmpty else { return 0 }
        return Double(redacted.visibleCells.count) / Double(map.cells.count)
    }

    private var exploredCoverage: Double {
        guard !map.cells.isEmpty else { return 0 }
        return Double(redacted.exploredCells.count) / Double(map.cells.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.18)

            HStack(spacing: 0) {
                battlefield
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                commandSidebar
                    .frame(width: 276)
            }

            Divider().opacity(0.18)
            overlayBar
        }
        .background(VeilInstrumentBackground())
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("官渡决战")
                .font(.system(size: 15, weight: .semibold, design: .serif))

            Text("战役大地图 · \(map.width)×\(map.height)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            VeilInstrumentLabel(
                title: "FACTION",
                value: redacted.viewer == .cao ? "曹军" : "袁军",
                active: true
            )

            VeilInstrumentLabel(
                title: "LOD",
                value: lodTitle(renderSnapshot.lod),
                active: true
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            VeilInstrumentPlate(
                shape: Rectangle(),
                emphasized: false
            )
        )
    }

    private var battlefield: some View {
        GeometryReader { proxy in
            TacticalLandscapeCanvasV2(
                map: map,
                snapshot: renderSnapshot,
                routePreview: routePreview,
                selectedFriendlyID: selectedFriendlyID,
                viewport: viewport
            )
            .contentShape(Rectangle())
            .gesture(mapGesture(size: proxy.size))
            .overlay(alignment: .topLeading) {
                Text("北 ↑")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(8)
                    .background(.black.opacity(0.34))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(10)
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.30))
        .overlay(Rectangle().stroke(Color.black.opacity(0.48), lineWidth: 1))
        .clipped()
    }

    private var commandSidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("指挥")
                .font(.headline)

            if let unit = selectedFriendly {
                Text(unit.id)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                HStack {
                    metric("兵种", kindName(unit.kind))
                    metric("兵力", "\(unit.steps)")
                }

                if let routePreview {
                    metric("路线", "\(max(0, routePreview.cells.count - 1)) 段")
                    metric("预计耗费", String(format: "%.1f", Double(routePreview.totalCostMilli) / 1000.0))

                    if let assessment = commandAssessment {
                        HStack {
                            metric("补给", supplyTitle(assessment.supplyStatus))
                            metric("暴露", exposureTitle(assessment.exposureStatus))
                        }
                        if let objective = assessment.nearestObjectiveTitle {
                            metric("邻近目标", objective)
                        }
                    }

                    Button("下达行军命令") {
                        guard routePreview.cells.count >= 2 else { return }
                        let order = TacticalV2.OrderV2(
                            id: UUID().uuidString,
                            kind: .march,
                            actor: redacted.viewer,
                            issuedTurn: simulationTurn,
                            unitID: unit.id,
                            routeCells: routePreview.cells.map { UInt16($0) }
                        )
                        onSubmitOrder(order)
                    }
                    .buttonStyle(VeilPhysicalButtonStyle(accent: true))
                } else {
                    Text("拖动地图上的目标位置来规划路线。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("选择己方部队后，可直接在地图上拖出行军路线。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider().opacity(0.2)

            Text("敌情")
                .font(.system(size: 12, weight: .semibold))

            VeilStatusStrip(
                leftTitle: "CONFIRMED",
                leftValue: "\(confirmedEnemyCount)",
                rightTitle: "PARTIAL",
                rightValue: "\(partialEnemyCount)",
                active: confirmedEnemyCount + partialEnemyCount > 0
            )

            VeilStatusStrip(
                leftTitle: "SUSPECTED",
                leftValue: "\(suspectedEnemyCount)",
                rightTitle: "CONTACTS",
                rightValue: "\(redacted.enemyMarkers.count)",
                active: !redacted.enemyMarkers.isEmpty
            )

            VeilGaugeMeter(
                title: "VISIBLE AREA",
                value: visibleCoverage,
                text: "\(Int((visibleCoverage * 100).rounded()))%"
            )

            VeilGaugeMeter(
                title: "EXPLORED AREA",
                value: exploredCoverage,
                text: "\(Int((exploredCoverage * 100).rounded()))%"
            )

            Spacer()

            Button("取消路线") {
                routePlanner.cancel()
                routePreview = nil
            }
            .buttonStyle(VeilPhysicalButtonStyle())
            .disabled(routePreview == nil)
        }
        .padding(14)
        .background(
            VeilInstrumentPlate(
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                emphasized: true
            )
        )
        .padding(6)
    }

    private var overlayBar: some View {
        HStack(spacing: 8) {
            ForEach(TacticalV2.TacticalOverlayV2.allCases, id: \.self) { item in
                Button(overlayTitle(item)) {
                    overlay = item
                }
                .buttonStyle(VeilCompactKeyStyle(selected: overlay == item))
            }

            Spacer()

            VeilInstrumentLabel(
                title: "OVERLAY",
                value: overlayTitle(overlay),
                active: true
            )

            Button("－") {
                zoom = max(0.55, zoom - 0.15)
                applyZoom()
            }
            .buttonStyle(VeilCompactKeyStyle())

            Button("＋") {
                zoom = min(2.0, zoom + 0.15)
                applyZoom()
            }
            .buttonStyle(VeilCompactKeyStyle())
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            VeilInstrumentPlate(
                shape: Rectangle(),
                emphasized: false
            )
        )
    }

    private func mapGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let normalized = normalizedPoint(value.location, size: size)
                guard let target = TacticalV2.MapGeometryV2.nearestCell(
                    point: normalized,
                    map: map,
                    candidates: renderSnapshot.candidateCells
                ) else { return }

                if let selectedFriendly {
                    if routePlanner.originCell == nil {
                        routePlanner.begin(originCell: selectedFriendly.cell)
                    }
                    routePreview = routePlanner.update(
                        targetCell: target,
                        map: map
                    )
                } else {
                    selectFriendly(near: target)
                }
            }
            .onEnded { _ in
                if selectedFriendlyID == nil {
                    routePlanner.cancel()
                    routePreview = nil
                }
            }
    }

    private func selectFriendly(near cell: Int) {
        if let exact = redacted.friendlies.first(where: { $0.cell == cell }) {
            selectedFriendlyID = exact.id
            routePlanner.begin(originCell: exact.cell)
            routePreview = routePlanner.preview
        }
    }

    private func normalizedPoint(_ point: CGPoint, size: CGSize) -> TacticalV2.NormalizedPointV2 {
        let x = viewport.minX + Double(point.x / max(1, size.width)) * (viewport.maxX - viewport.minX)
        let y = viewport.minY + Double(point.y / max(1, size.height)) * (viewport.maxY - viewport.minY)
        return TacticalV2.NormalizedPointV2(
            x: min(1, max(0, x)),
            y: min(1, max(0, y))
        )
    }

    private func applyZoom() {
        let centerX = (viewport.minX + viewport.maxX) * 0.5
        let centerY = (viewport.minY + viewport.maxY) * 0.5
        let width = min(1, max(0.18, 0.82 / zoom))
        let height = min(1, max(0.18, 0.82 / zoom))
        let minX = min(1 - width, max(0, centerX - width * 0.5))
        let minY = min(1 - height, max(0, centerY - height * 0.5))
        viewport = TacticalV2.NormalizedRectV2(
            minX: minX,
            minY: minY,
            maxX: minX + width,
            maxY: minY + height
        )
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VeilLCDDisplay(title: title, value: value)
            .frame(maxWidth: .infinity)
    }

    private func kindName(_ kind: TacticalV2.UnitKind) -> String {
        switch kind {
        case .command: return "中军"
        case .infantry: return "步军"
        case .cavalry: return "骑军"
        case .ranged: return "远程"
        case .supply: return "辎重"
        }
    }


    private func supplyTitle(
        _ status: TacticalV2.CommandAssessmentV2.SupplyStatus
    ) -> String {
        switch status {
        case .cut: return "中断"
        case .strained: return "吃紧"
        case .connected: return "接通"
        case .strong: return "充足"
        }
    }

    private func exposureTitle(
        _ status: TacticalV2.CommandAssessmentV2.ExposureStatus
    ) -> String {
        switch status {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .severe: return "极高"
        }
    }

    private func overlayTitle(_ item: TacticalV2.TacticalOverlayV2) -> String {
        switch item {
        case .battlefield: return "战场"
        case .intelligence: return "情报"
        case .supply: return "补给"
        case .objectives: return "目标"
        case .threat: return "威胁"
        }
    }

    private func lodTitle(_ lod: TacticalV2.MapLODLevelV2) -> String {
        switch lod {
        case .campaign: return "战役视图"
        case .operational: return "作战视图"
        case .contact: return "接敌视图"
        }
    }
}
