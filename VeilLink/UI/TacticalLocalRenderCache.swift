import SwiftUI

/// Static, install-local render blueprints for the tactical board.
///
/// Nothing here loads or decodes an image. The app ships normalized geometry and
/// palette data as Swift code, warms it at launch, then scales it to the current
/// screen size. This keeps the battlefield available offline and avoids bitmap
/// decode spikes on legacy devices such as iPhone 7.
enum TacticalLocalRenderCache {
    struct UnitPoint: Hashable {
        let x: CGFloat
        let y: CGFloat
    }

    struct Segment: Hashable {
        let start: UnitPoint
        let end: UnitPoint
    }

    struct CellLayout: Hashable, Identifiable {
        let index: Int
        let centerX: CGFloat
        let centerY: CGFloat
        var id: Int { index }
    }

    struct CounterStyle {
        let fill: Color
        let border: Color
        let text: Color
        let flagGlyph: String
    }

    static let hexWidthFactor: CGFloat = 1.0 / 9.55
    static let hexHeightFactor: CGFloat = hexWidthFactor * 0.88
    /// Width / height of the actual cached 7×9 hex footprint. Keep this derived from
    /// the same geometry used by `cells` so the SwiftUI container cannot grow a
    /// phantom strip below the last row on compact phones.
    static let boardAspectRatio: CGFloat = 1.0 / (hexHeightFactor * (1.0 + 0.75 * CGFloat(TacticalState.rows - 1)))

    /// Normalized clockwise vertices of a flat-top hexagon.
    static let hexVertices: [UnitPoint] = [
        .init(x: 0.25, y: 0.00),
        .init(x: 0.75, y: 0.00),
        .init(x: 1.00, y: 0.50),
        .init(x: 0.75, y: 1.00),
        .init(x: 0.25, y: 1.00),
        .init(x: 0.00, y: 0.50)
    ]

    /// The 63 cell centers are calculated once per process, not on every body pass.
    static let cells: [CellLayout] = TacticalState.hexes.map { hex in
        CellLayout(
            index: hex.index,
            centerX: hexWidthFactor * 0.52
                + CGFloat(hex.col) * hexWidthFactor
                + (hex.row.isMultiple(of: 2) ? 0 : hexWidthFactor * 0.5),
            centerY: hexHeightFactor * 0.5
                + CGFloat(hex.row) * hexHeightFactor * 0.75
        )
    }

    /// Mirrors only cell positions, never the tile contents, so the guest sees their army at
    /// the near edge while labels/counters remain upright. Coordinates stay normalized to board width.
    static func displayCenter(for layout: CellLayout, flipped: Bool) -> UnitPoint {
        guard flipped else { return UnitPoint(x: layout.centerX, y: layout.centerY) }
        let boardHeightFactor = 1.0 / boardAspectRatio
        return UnitPoint(x: 1.0 - layout.centerX, y: boardHeightFactor - layout.centerY)
    }

    /// Tiny normalized line motifs used instead of SF Symbols or bitmap textures.
    static let terrainSegments: [TacticalTerrain: [Segment]] = [
        .plain: [
            .init(start: .init(x: 0.25, y: 0.66), end: .init(x: 0.75, y: 0.66))
        ],
        .road: [
            .init(start: .init(x: 0.12, y: 0.62), end: .init(x: 0.88, y: 0.38)),
            .init(start: .init(x: 0.10, y: 0.70), end: .init(x: 0.90, y: 0.46))
        ],
        .forest: [
            .init(start: .init(x: 0.30, y: 0.70), end: .init(x: 0.42, y: 0.30)),
            .init(start: .init(x: 0.42, y: 0.30), end: .init(x: 0.54, y: 0.70)),
            .init(start: .init(x: 0.50, y: 0.72), end: .init(x: 0.62, y: 0.34)),
            .init(start: .init(x: 0.62, y: 0.34), end: .init(x: 0.74, y: 0.72))
        ],
        .hill: [
            .init(start: .init(x: 0.18, y: 0.66), end: .init(x: 0.40, y: 0.38)),
            .init(start: .init(x: 0.40, y: 0.38), end: .init(x: 0.55, y: 0.56)),
            .init(start: .init(x: 0.55, y: 0.56), end: .init(x: 0.68, y: 0.40)),
            .init(start: .init(x: 0.68, y: 0.40), end: .init(x: 0.84, y: 0.66))
        ],
        .river: [
            .init(start: .init(x: 0.10, y: 0.43), end: .init(x: 0.32, y: 0.52)),
            .init(start: .init(x: 0.32, y: 0.52), end: .init(x: 0.52, y: 0.42)),
            .init(start: .init(x: 0.52, y: 0.42), end: .init(x: 0.72, y: 0.53)),
            .init(start: .init(x: 0.72, y: 0.53), end: .init(x: 0.90, y: 0.44)),
            .init(start: .init(x: 0.10, y: 0.58), end: .init(x: 0.30, y: 0.66)),
            .init(start: .init(x: 0.30, y: 0.66), end: .init(x: 0.50, y: 0.57)),
            .init(start: .init(x: 0.50, y: 0.57), end: .init(x: 0.70, y: 0.67)),
            .init(start: .init(x: 0.70, y: 0.67), end: .init(x: 0.90, y: 0.59))
        ],
        .ford: [
            .init(start: .init(x: 0.12, y: 0.45), end: .init(x: 0.88, y: 0.45)),
            .init(start: .init(x: 0.12, y: 0.58), end: .init(x: 0.88, y: 0.58)),
            .init(start: .init(x: 0.38, y: 0.26), end: .init(x: 0.38, y: 0.78)),
            .init(start: .init(x: 0.62, y: 0.26), end: .init(x: 0.62, y: 0.78))
        ],
        .camp: [
            .init(start: .init(x: 0.22, y: 0.70), end: .init(x: 0.50, y: 0.28)),
            .init(start: .init(x: 0.50, y: 0.28), end: .init(x: 0.78, y: 0.70)),
            .init(start: .init(x: 0.28, y: 0.70), end: .init(x: 0.72, y: 0.70))
        ]
    ]

    static let counterStyles: [TacticalFaction: CounterStyle] = [
        .cao: CounterStyle(
            fill: Color(red: 0.62, green: 0.16, blue: 0.13),
            border: Color(red: 0.94, green: 0.67, blue: 0.42),
            text: Color.white.opacity(0.96),
            flagGlyph: "曹"
        ),
        .yuan: CounterStyle(
            fill: Color(red: 0.13, green: 0.31, blue: 0.52),
            border: Color(red: 0.65, green: 0.80, blue: 0.94),
            text: Color.white.opacity(0.96),
            flagGlyph: "袁"
        )
    ]

    /// Called during app bootstrap so the static arrays/dictionaries are materialized
    /// before the player opens Game Hub. No disk/network image I/O is performed.
    static func warmUp() {
        _ = hexVertices.count
        _ = cells.count
        _ = terrainSegments.count
        _ = counterStyles.count
    }
}

struct TacticalCachedHexShape: Shape {
    func path(in rect: CGRect) -> Path {
        guard let first = TacticalLocalRenderCache.hexVertices.first else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: first.x * rect.width, y: first.y * rect.height))
        for point in TacticalLocalRenderCache.hexVertices.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * rect.width, y: point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

struct TacticalTerrainCodeMark: View {
    let terrain: TacticalTerrain

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for segment in TacticalLocalRenderCache.terrainSegments[terrain] ?? [] {
                    path.move(to: CGPoint(x: segment.start.x * proxy.size.width, y: segment.start.y * proxy.size.height))
                    path.addLine(to: CGPoint(x: segment.end.x * proxy.size.width, y: segment.end.y * proxy.size.height))
                }
            }
            .stroke(Color.white.opacity(terrain == .river || terrain == .ford ? 0.25 : 0.15), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, lineJoin: .round))
        }
        .allowsHitTesting(false)
    }
}

struct TacticalFactionFlagView: View {
    let faction: TacticalFaction
    var compact = false

    private var style: TacticalLocalRenderCache.CounterStyle {
        TacticalLocalRenderCache.counterStyles[faction]!
    }

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            Rectangle()
                .fill(style.border.opacity(0.78))
                .frame(width: compact ? 1 : 1.5)
            ZStack {
                TacticalFlagClothShape()
                    .fill(style.fill)
                TacticalFlagClothShape()
                    .stroke(style.border.opacity(0.72), lineWidth: 0.7)
                Text(style.flagGlyph)
                    .font(.system(size: compact ? 6 : 8, weight: .heavy, design: .serif))
                    .foregroundColor(style.text)
                    .offset(x: -1)
            }
            .frame(width: compact ? 13 : 18, height: compact ? 10 : 13)
        }
        .accessibilityLabel("\(faction.title)旗")
    }
}

private struct TacticalFlagClothShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.90))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct TacticalUnitCounterView: View {
    let unit: TacticalUnit
    let acted: Bool

    private var style: TacticalLocalRenderCache.CounterStyle {
        TacticalLocalRenderCache.counterStyles[unit.faction]!
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TacticalCounterShape()
                .fill(style.fill.opacity(acted ? 0.48 : 0.96))
            TacticalCounterShape()
                .stroke(style.border.opacity(acted ? 0.34 : 0.82), lineWidth: 0.9)

            Text(style.flagGlyph)
                .font(.system(size: 5.5, weight: .bold, design: .serif))
                .foregroundColor(style.text.opacity(acted ? 0.46 : 0.80))
                .padding(.leading, 3)
                .padding(.top, 2)

            VStack(spacing: 1) {
                Text(unit.kind.symbol)
                    .font(.system(size: 11.5, weight: .heavy, design: .serif))
                HStack(spacing: 2) {
                    ForEach(0..<unit.kind.maxSteps, id: \.self) { index in
                        Circle()
                            .fill(index < unit.steps ? style.text : style.text.opacity(0.18))
                            .frame(width: 3.4, height: 3.4)
                    }
                }
            }
            .foregroundColor(style.text.opacity(acted ? 0.50 : 0.98))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 29, height: 27)
        .shadow(color: Color.black.opacity(acted ? 0.06 : 0.28), radius: acted ? 0 : 2, y: 1)
        .accessibilityLabel("\(unit.faction.title)\(unit.name)，兵力\(unit.steps)")
    }
}

private struct TacticalCounterShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cut = min(rect.width, rect.height) * 0.16
        var path = Path()
        path.move(to: CGPoint(x: cut, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cut))
        path.addLine(to: CGPoint(x: rect.width - cut, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: cut))
        path.closeSubpath()
        return path
    }
}
