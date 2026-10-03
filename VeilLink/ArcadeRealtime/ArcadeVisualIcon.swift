import SwiftUI

/// Asset-free arcade artwork. Each motif has its own silhouette and remains
/// recognizable when rendered at the 44-point compact size.
struct ArcadeVisualIcon: View {
    let motif: ArcadeVisualMotif
    var animated = true
    var accessibilityLabel: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var permitsAmbientMotion: Bool {
        animated
            && !VeilMotionPolicy.usesReducedMotion(reduceMotion)
            && VeilMotionPolicy.allowsContinuousDecorativeMotion
    }

    var body: some View {
        Group {
            if permitsAmbientMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    face(phase: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                face(phase: 0)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? "\(motif.accessibilityName)游戏图标")
    }

    private func face(phase: TimeInterval) -> some View {
        Canvas { context, size in
            let palette = ArcadeVisualPalette.palette(for: motif)
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let bounds = CGRect(
                x: center.x - side * 0.5,
                y: center.y - side * 0.5,
                width: side,
                height: side
            )

            drawBackdrop(in: &context, bounds: bounds, palette: palette)
            drawOrbit(in: &context, bounds: bounds, phase: phase, palette: palette)
            drawMotif(in: &context, bounds: bounds, phase: phase, palette: palette)
            drawSpecular(in: &context, bounds: bounds)
        }
    }

    private func drawBackdrop(
        in context: inout GraphicsContext,
        bounds: CGRect,
        palette: ArcadeVisualPalette
    ) {
        let outer = Path(roundedRect: bounds.insetBy(dx: bounds.width * 0.03, dy: bounds.height * 0.03), cornerRadius: bounds.width * 0.25)
        context.fill(
            outer,
            with: .linearGradient(
                Gradient(colors: [palette.shadow, Color(red: 0.025, green: 0.035, blue: 0.075)]),
                startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
                endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)
            )
        )
        context.stroke(outer, with: .color(palette.primary.opacity(0.65)), lineWidth: max(1, bounds.width * 0.018))

        let glowRect = bounds.insetBy(dx: bounds.width * 0.13, dy: bounds.height * 0.13)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [palette.primary.opacity(0.38), .clear]),
                center: CGPoint(x: glowRect.midX, y: glowRect.midY),
                startRadius: 0,
                endRadius: glowRect.width * 0.53
            )
        )
    }

    private func drawOrbit(
        in context: inout GraphicsContext,
        bounds: CGRect,
        phase: TimeInterval,
        palette: ArcadeVisualPalette
    ) {
        let orbit = bounds.insetBy(dx: bounds.width * 0.15, dy: bounds.height * 0.26)
        context.stroke(
            Path(ellipseIn: orbit),
            with: .color(palette.secondary.opacity(0.32)),
            style: StrokeStyle(lineWidth: max(1, bounds.width * 0.012), dash: [bounds.width * 0.045, bounds.width * 0.055])
        )

        let angle = phase * 1.15
        let point = CGPoint(
            x: orbit.midX + CGFloat(cos(angle)) * orbit.width * 0.5,
            y: orbit.midY + CGFloat(sin(angle)) * orbit.height * 0.5
        )
        let dot = bounds.width * 0.035
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)),
            with: .color(palette.highlight)
        )
    }

    private func drawMotif(
        in context: inout GraphicsContext,
        bounds: CGRect,
        phase: TimeInterval,
        palette: ArcadeVisualPalette
    ) {
        switch motif {
        case .comet:
            drawComet(in: &context, bounds: bounds, phase: phase, palette: palette)
        case .guardian:
            drawGuardian(in: &context, bounds: bounds, palette: palette)
        case .pulse:
            drawPulse(in: &context, bounds: bounds, phase: phase, palette: palette)
        case .bloom:
            drawBloom(in: &context, bounds: bounds, phase: phase, palette: palette)
        case .circuit:
            drawCircuit(in: &context, bounds: bounds, phase: phase, palette: palette)
        case .tide:
            drawTide(in: &context, bounds: bounds, phase: phase, palette: palette)
        }
    }

    private func drawComet(
        in context: inout GraphicsContext,
        bounds: CGRect,
        phase: TimeInterval,
        palette: ArcadeVisualPalette
    ) {
        let drift = CGFloat(sin(phase * 2.4)) * bounds.width * 0.018
        var tail = Path()
        tail.move(to: CGPoint(x: bounds.minX + bounds.width * 0.20, y: bounds.maxY - bounds.height * 0.25 + drift))
        tail.addCurve(
            to: CGPoint(x: bounds.minX + bounds.width * 0.61, y: bounds.minY + bounds.height * 0.40 + drift),
            control1: CGPoint(x: bounds.minX + bounds.width * 0.32, y: bounds.maxY - bounds.height * 0.50),
            control2: CGPoint(x: bounds.minX + bounds.width * 0.46, y: bounds.minY + bounds.height * 0.46)
        )
        context.stroke(tail, with: .linearGradient(
            Gradient(colors: [.clear, palette.secondary, palette.highlight]),
            startPoint: CGPoint(x: bounds.minX, y: bounds.maxY),
            endPoint: CGPoint(x: bounds.maxX, y: bounds.minY)
        ), style: StrokeStyle(lineWidth: bounds.width * 0.12, lineCap: .round))

        let head = CGPoint(x: bounds.minX + bounds.width * 0.65, y: bounds.minY + bounds.height * 0.36 + drift)
        let radius = bounds.width * 0.15
        context.fill(
            Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [palette.highlight, palette.primary]),
                center: head,
                startRadius: 1,
                endRadius: radius
            )
        )
    }

    private func drawGuardian(
        in context: inout GraphicsContext,
        bounds: CGRect,
        palette: ArcadeVisualPalette
    ) {
        var shield = Path()
        shield.move(to: CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.20))
        shield.addLine(to: CGPoint(x: bounds.maxX - bounds.width * 0.22, y: bounds.minY + bounds.height * 0.31))
        shield.addLine(to: CGPoint(x: bounds.maxX - bounds.width * 0.28, y: bounds.maxY - bounds.height * 0.27))
        shield.addQuadCurve(
            to: CGPoint(x: bounds.midX, y: bounds.maxY - bounds.height * 0.15),
            control: CGPoint(x: bounds.maxX - bounds.width * 0.38, y: bounds.maxY - bounds.height * 0.18)
        )
        shield.addQuadCurve(
            to: CGPoint(x: bounds.minX + bounds.width * 0.28, y: bounds.maxY - bounds.height * 0.27),
            control: CGPoint(x: bounds.minX + bounds.width * 0.38, y: bounds.maxY - bounds.height * 0.18)
        )
        shield.addLine(to: CGPoint(x: bounds.minX + bounds.width * 0.22, y: bounds.minY + bounds.height * 0.31))
        shield.closeSubpath()
        context.fill(shield, with: .linearGradient(
            Gradient(colors: [palette.highlight, palette.primary, palette.secondary]),
            startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
            endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)
        ))

        var mark = Path()
        mark.move(to: CGPoint(x: bounds.midX, y: bounds.minY + bounds.height * 0.32))
        mark.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY - bounds.height * 0.30))
        mark.move(to: CGPoint(x: bounds.minX + bounds.width * 0.36, y: bounds.midY))
        mark.addLine(to: CGPoint(x: bounds.maxX - bounds.width * 0.36, y: bounds.midY))
        context.stroke(mark, with: .color(Color.white.opacity(0.82)), style: StrokeStyle(lineWidth: bounds.width * 0.055, lineCap: .round))
    }

    private func drawPulse(
        in context: inout GraphicsContext,
        bounds: CGRect,
        phase: TimeInterval,
        palette: ArcadeVisualPalette
    ) {
        for ring in 0..<3 {
            let base = CGFloat(ring) * 0.09
            let expansion = CGFloat((sin(phase * 2 + Double(ring)) + 1) * 0.015)
            let inset = bounds.width * (0.20 + base - expansion)
            context.stroke(
                Path(ellipseIn: bounds.insetBy(dx: inset, dy: inset)),
                with: .color((ring == 0 ? palette.highlight : palette.primary).opacity(0.82 - Double(ring) * 0.20)),
                lineWidth: max(1.5, bounds.width * 0.026)
            )
        }
        let core = bounds.insetBy(dx: bounds.width * 0.40, dy: bounds.height * 0.40)
        context.fill(Path(ellipseIn: core), with: .color(palette.highlight))
    }

    private func drawBloom(
        in context: inout GraphicsContext,
        bounds: CGRect,
        phase: TimeInterval,
        palette: ArcadeVisualPalette
    ) {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let turn = phase * 0.28
        for petal in 0..<6 {
            let angle = Double(petal) * .pi / 3 + turn
            let radius = bounds.width * 0.18
            let point = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            let rect = CGRect(
                x: point.x - bounds.width * 0.09,
                y: point.y - bounds.height * 0.14,
                width: bounds.width * 0.18,
                height: bounds.height * 0.28
            )
            context.fill(Path(ellipseIn: rect), with: .color((petal.isMultiple(of: 2) ? palette.primary : palette.secondary).opacity(0.86)))
        }
        let coreRadius = bounds.width * 0.09
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)),
            with: .color(palette.highlight)
        )
    }

    private func drawCircuit(
        in context: inout GraphicsContext,
        bounds: CGRect,
        phase: TimeInterval,
        palette: ArcadeVisualPalette
    ) {
        var circuit = Path()
        let points = [
            CGPoint(x: 0.26, y: 0.30), CGPoint(x: 0.50, y: 0.30),
            CGPoint(x: 0.50, y: 0.50), CGPoint(x: 0.72, y: 0.50),
            CGPoint(x: 0.72, y: 0.70), CGPoint(x: 0.39, y: 0.70),
            CGPoint(x: 0.39, y: 0.52), CGPoint(x: 0.26, y: 0.52)
        ].map { CGPoint(x: bounds.minX + bounds.width * $0.x, y: bounds.minY + bounds.height * $0.y) }
        circuit.move(to: points[0])
        for point in points.dropFirst() { circuit.addLine(to: point) }
        context.stroke(circuit, with: .linearGradient(
            Gradient(colors: [palette.secondary, palette.highlight, palette.primary]),
            startPoint: CGPoint(x: bounds.minX, y: bounds.minY),
            endPoint: CGPoint(x: bounds.maxX, y: bounds.maxY)
        ), style: StrokeStyle(lineWidth: bounds.width * 0.055, lineCap: .round, lineJoin: .round))

        for (index, point) in points.enumerated() where index.isMultiple(of: 2) {
            let pulse = bounds.width * (0.035 + CGFloat((sin(phase * 2.8 + Double(index)) + 1) * 0.008))
            context.fill(Path(ellipseIn: CGRect(x: point.x - pulse, y: point.y - pulse, width: pulse * 2, height: pulse * 2)), with: .color(palette.highlight))
        }
    }

    private func drawTide(
        in context: inout GraphicsContext,
        bounds: CGRect,
        phase: TimeInterval,
        palette: ArcadeVisualPalette
    ) {
        for wave in 0..<3 {
            let y = bounds.minY + bounds.height * (0.37 + CGFloat(wave) * 0.13)
            var path = Path()
            path.move(to: CGPoint(x: bounds.minX + bounds.width * 0.18, y: y))
            let offset = CGFloat(sin(phase * 1.9 + Double(wave))) * bounds.height * 0.025
            path.addCurve(
                to: CGPoint(x: bounds.maxX - bounds.width * 0.18, y: y + offset),
                control1: CGPoint(x: bounds.minX + bounds.width * 0.35, y: y - bounds.height * 0.18 + offset),
                control2: CGPoint(x: bounds.minX + bounds.width * 0.62, y: y + bounds.height * 0.18 - offset)
            )
            context.stroke(
                path,
                with: .color((wave == 1 ? palette.highlight : palette.primary).opacity(0.92 - Double(wave) * 0.16)),
                style: StrokeStyle(lineWidth: bounds.width * 0.055, lineCap: .round)
            )
        }
    }

    private func drawSpecular(in context: inout GraphicsContext, bounds: CGRect) {
        var slash = Path()
        slash.move(to: CGPoint(x: bounds.minX + bounds.width * 0.22, y: bounds.minY + bounds.height * 0.17))
        slash.addLine(to: CGPoint(x: bounds.maxX - bounds.width * 0.22, y: bounds.minY + bounds.height * 0.17))
        context.stroke(slash, with: .color(Color.white.opacity(0.20)), style: StrokeStyle(lineWidth: max(1, bounds.width * 0.014), lineCap: .round))
    }
}
