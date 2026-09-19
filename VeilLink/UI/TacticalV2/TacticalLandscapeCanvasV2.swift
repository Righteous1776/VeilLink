import SwiftUI
import Foundation

struct TacticalLandscapeCanvasV2: View {
    let map: TacticalV2.Map
    let snapshot: TacticalV2.MapRenderSnapshotV2
    let routePreview: TacticalV2.RoutePlanV2?
    let selectedFriendlyID: String?
    let viewport: TacticalV2.NormalizedRectV2

    var body: some View {
        Canvas(opaque: true, rendersAsynchronously: true) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(red: 0.075, green: 0.071, blue: 0.061))
            )

            drawTerrain(context: &context, size: size)
            drawOperationalOverlay(context: &context, size: size)
            drawFog(context: &context, size: size)
            drawRoute(context: &context, size: size)
            drawFriendlies(context: &context, size: size)
            drawEnemyIntel(context: &context, size: size)
        }
        .accessibilityLabel("官渡战役大地图")
    }

    private func screenPoint(
        cell: Int,
        size: CGSize
    ) -> CGPoint? {
        guard let c = map.cell(cell) else { return nil }
        let p = TacticalV2.MapGeometryV2.normalizedCenter(cell: c, map: map)

        let nx = (p.x - viewport.minX) / max(0.0001, viewport.maxX - viewport.minX)
        let ny = (p.y - viewport.minY) / max(0.0001, viewport.maxY - viewport.minY)
        return CGPoint(x: nx * size.width, y: ny * size.height)
    }

    private func cellRadius(size: CGSize) -> CGFloat {
        let normalizedWidth = max(0.001, viewport.maxX - viewport.minX)
        let visibleColumns = CGFloat(Double(map.width) * normalizedWidth)
        return max(4, min(20, size.width / max(8, visibleColumns) * 0.58))
    }

    private func hexPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for i in 0..<6 {
            let angle = CGFloat.pi / 3 * CGFloat(i)
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius * 0.86
            )
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func terrainColor(_ code: String) -> Color {
        switch code {
        case "forest": return Color(red: 0.13, green: 0.18, blue: 0.12)
        case "wetland": return Color(red: 0.10, green: 0.15, blue: 0.15)
        case "fortified": return Color(red: 0.18, green: 0.14, blue: 0.11)
        case "riverbank": return Color(red: 0.10, green: 0.14, blue: 0.17)
        case "rear": return Color(red: 0.15, green: 0.14, blue: 0.11)
        default: return Color(red: 0.16, green: 0.15, blue: 0.12)
        }
    }

    private func drawTerrain(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let r = cellRadius(size: size)

        for index in snapshot.candidateCells {
            guard let cell = map.cell(index),
                  let center = screenPoint(cell: index, size: size) else { continue }

            let path = hexPath(center: center, radius: r)
            context.fill(path, with: .color(terrainColor(cell.terrainCode)))

            if cell.road && snapshot.lod != .campaign {
                var road = Path()
                road.move(to: CGPoint(x: center.x - r * 0.7, y: center.y + r * 0.2))
                road.addLine(to: CGPoint(x: center.x + r * 0.7, y: center.y - r * 0.2))
                context.stroke(
                    road,
                    with: .color(Color(red: 0.58, green: 0.48, blue: 0.30).opacity(0.45)),
                    lineWidth: max(0.7, r * 0.08)
                )
            }
        }
    }


    private func drawOperationalOverlay(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        switch snapshot.overlay {
        case .supply:
            drawScalarField(
                snapshot.supplyPermille,
                context: &context,
                size: size,
                warm: false
            )
        case .threat:
            drawScalarField(
                snapshot.threatPermille,
                context: &context,
                size: size,
                warm: true
            )
        case .objectives:
            drawObjectives(
                context: &context,
                size: size
            )
        case .battlefield, .intelligence:
            break
        }
    }

    private func drawScalarField(
        _ values: [Int16],
        context: inout GraphicsContext,
        size: CGSize,
        warm: Bool
    ) {
        let r = cellRadius(size: size)
        for index in snapshot.candidateCells {
            guard values.indices.contains(index),
                  values[index] > 0,
                  let center = screenPoint(cell: index, size: size) else {
                continue
            }

            let intensity = min(
                1.0,
                max(0.0, Double(values[index]) / 1000.0)
            )
            let color: Color = warm
                ? Color(red: 0.82, green: 0.20, blue: 0.12)
                : Color(red: 0.22, green: 0.58, blue: 0.42)

            context.fill(
                hexPath(center: center, radius: r),
                with: .color(color.opacity(0.08 + intensity * 0.30))
            )
        }
    }

    private func drawObjectives(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        for objective in snapshot.objectives {
            guard let center = screenPoint(
                cell: objective.cell,
                size: size
            ) else {
                continue
            }

            let radius = max(10, cellRadius(size: size) * 1.05)
            let ring = Path(
                ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )

            let color: Color
            switch objective.side {
            case .neutral:
                color = Color.white.opacity(0.45)
            case .local:
                color = Color(red: 0.90, green: 0.70, blue: 0.30)
            case .contested:
                color = Color(red: 0.88, green: 0.48, blue: 0.22)
            case .enemyKnown:
                color = Color(red: 0.42, green: 0.62, blue: 0.86)
            }

            context.stroke(
                ring,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: objective.side == .contested ? 2.2 : 1.4,
                    dash: objective.side == .neutral ? [4, 4] : []
                )
            )

            if snapshot.lod != .campaign {
                context.draw(
                    Text(objective.title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(color),
                    at: CGPoint(
                        x: center.x,
                        y: center.y - radius - 8
                    ),
                    anchor: .center
                )
            }
        }
    }

    private func drawFog(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let r = cellRadius(size: size)

        for index in snapshot.candidateCells {
            guard let center = screenPoint(cell: index, size: size) else { continue }

            if snapshot.visibleCells.contains(index) {
                continue
            }

            let path = hexPath(center: center, radius: r)
            if snapshot.exploredCells.contains(index) {
                context.fill(path, with: .color(Color.black.opacity(0.35)))
            } else {
                context.fill(path, with: .color(Color.black.opacity(0.78)))
            }
        }
    }

    private func drawRoute(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard let cells = routePreview?.cells, cells.count > 1 else { return }
        var route = Path()
        for (i, cell) in cells.enumerated() {
            guard let point = screenPoint(cell: cell, size: size) else { continue }
            if i == 0 { route.move(to: point) } else { route.addLine(to: point) }
        }
        context.stroke(
            route,
            with: .color(Color(red: 0.90, green: 0.74, blue: 0.36).opacity(0.92)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawFriendlies(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let r = max(7, cellRadius(size: size) * 0.72)

        for marker in snapshot.friendlies {
            guard let center = screenPoint(cell: marker.cell, size: size) else { continue }
            let rect = CGRect(
                x: center.x - r,
                y: center.y - r * 0.62,
                width: r * 2,
                height: r * 1.24
            )
            let path = Path(roundedRect: rect, cornerRadius: 3)

            context.fill(
                path,
                with: .color(Color(red: 0.66, green: 0.18, blue: 0.13).opacity(
                    marker.id == selectedFriendlyID ? 1.0 : 0.86
                ))
            )
            context.stroke(
                path,
                with: .color(Color(red: 0.92, green: 0.72, blue: 0.40)),
                lineWidth: marker.id == selectedFriendlyID ? 2.0 : 1.0
            )
        }
    }

    private func drawEnemyIntel(
        context: inout GraphicsContext,
        size: CGSize
    ) {
        let r = max(6, cellRadius(size: size) * 0.60)

        for marker in snapshot.enemies {
            guard let cell = marker.estimatedCell,
                  let center = screenPoint(cell: cell, size: size) else { continue }

            let alpha: Double
            switch marker.level {
            case .confirmed: alpha = 0.90
            case .partial: alpha = 0.68
            case .suspected: alpha = 0.42
            case .unknown: alpha = 0
            }

            guard alpha > 0 else { continue }
            let rect = CGRect(
                x: center.x - r,
                y: center.y - r * 0.58,
                width: r * 2,
                height: r * 1.16
            )
            let path = Path(roundedRect: rect, cornerRadius: 3)
            context.fill(
                path,
                with: .color(Color(red: 0.18, green: 0.36, blue: 0.58).opacity(alpha))
            )
            context.stroke(
                path,
                with: .color(Color(red: 0.62, green: 0.78, blue: 0.94).opacity(alpha)),
                lineWidth: 1
            )

            if marker.level == .suspected {
                let uncertainty = CGFloat(max(1, marker.uncertaintyRadius)) * r * 0.55
                let ring = Path(ellipseIn: CGRect(
                    x: center.x - r - uncertainty,
                    y: center.y - r - uncertainty,
                    width: (r + uncertainty) * 2,
                    height: (r + uncertainty) * 2
                ))
                context.stroke(
                    ring,
                    with: .color(Color.white.opacity(0.14)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }
        }
    }
}
