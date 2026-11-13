import Foundation
import SwiftUI
import UIKit

/// Platform-independent rendering of the Republic of China flag inside VeilLink.
///
/// Some iOS devices do not provide a glyph for the regional-indicator sequence
/// U+1F1F9 U+1F1FC. All views using this adapter draw a local vector-backed
/// image instead of consulting the platform's Emoji font or system region.
///
/// This is display-only. Do not rewrite message bodies, drafts, wire payloads,
/// database rows, exports or clipboard text.
@MainActor
enum VeilROCFlagText {
    static let emoji = "\u{1F1F9}\u{1F1FC}"
    static let spokenName = "中华民国国旗"

    /// Article 4: 3:2 red field, 1/4 blue canton (1/2 width × 1/2 height).
    /// Article 3: 12 white rays, blue gap, and white disk.
    static let horizontalUnits: CGFloat = 3
    static let verticalUnits: CGFloat = 2
    static let rayCount = 12

    private static let flagImage: Image = Image(uiImage: makeImage()).renderingMode(.original)

    static func containsFlag(_ value: String) -> Bool {
        value.contains(emoji)
    }

    /// Preserves SwiftUI Text wrapping, selection semantics and surrounding
    /// text styling; a collection of HStacks would break inline wrapping.
    static func render(_ value: String) -> Text {
        guard containsFlag(value) else { return Text(verbatim: value) }
        let pieces = value.components(separatedBy: emoji)
        var result = Text(verbatim: pieces[0])
        for part in pieces.dropFirst() {
            result = result + Text(flagImage) + Text(verbatim: part)
        }
        return result
    }

    /// Readable in VoiceOver even when the region has no emoji glyph.
    static func accessibilityDescription(for text: String) -> String {
        text.replacingOccurrences(of: emoji, with: spokenName)
    }

    /// Uses public drawing APIs, not an external image or a system emoji.
    /// The same colors and geometry are rendered on iOS 15 and iOS 26.
    static func makeImage(size: CGSize = CGSize(width: 24, height: 16)) -> UIImage {
        let width = max(3, size.width)
        let height = width * 2 / 3
        let actual = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: actual, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            let red = UIColor(red: 254 / 255, green: 0, blue: 0, alpha: 1)
            let blue = UIColor(red: 0, green: 0, blue: 149 / 255, alpha: 1)
            cg.setFillColor(red.cgColor)
            cg.fill(CGRect(origin: .zero, size: actual))

            let canton = CGRect(x: 0, y: 0, width: width / 2, height: height / 2)
            cg.setFillColor(blue.cgColor)
            cg.fill(canton)

            let center = CGPoint(x: canton.midX, y: canton.midY)
            let diskRadius = canton.width / 8
            let gap = (2 * diskRadius) / 15 // Statutory blue ring.
            let baseRadius = diskRadius + gap
            let tipRadius = diskRadius * 2

            // A 30-degree angle at each ray tip, with 12 tips at 30° intervals.
            // Solve half base-angle once; no magic-size dependence.
            let halfAngle = rayHalfBaseAngle(baseRadius: baseRadius, tipRadius: tipRadius)
            cg.setFillColor(UIColor.white.cgColor)
            for ray in 0..<rayCount {
                let angle = CGFloat(ray) * CGFloat.pi / 6 - CGFloat.pi / 2
                let path = UIBezierPath()
                path.move(to: polar(center, distance: tipRadius, angle: angle))
                path.addLine(to: polar(center, distance: baseRadius, angle: angle - halfAngle))
                path.addLine(to: polar(center, distance: baseRadius, angle: angle + halfAngle))
                path.close()
                path.fill()
            }

            let disk = CGRect(x: center.x - diskRadius, y: center.y - diskRadius,
                              width: diskRadius * 2, height: diskRadius * 2)
            cg.fillEllipse(in: disk)
        }
    }

    private static func polar(_ c: CGPoint, distance r: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(x: c.x + r * cos(angle), y: c.y + r * sin(angle))
    }

    private static func rayHalfBaseAngle(baseRadius: CGFloat, tipRadius: CGFloat) -> CGFloat {
        let tangent = CGFloat(tan(Double.pi / 12)) // Half the 30-degree tip angle.
        var low: CGFloat = 0
        var high = CGFloat.pi / 6
        for _ in 0..<25 {
            let middle = (low + high) / 2
            let ratio = baseRadius * sin(middle) /
                (tipRadius - baseRadius * cos(middle))
            if ratio < tangent { low = middle } else { high = middle }
        }
        return (low + high) / 2
    }
}

/// Reusable explicit flag view for future country/region pickers or contact cards.
@MainActor
struct VeilROCFlagView: View {
    var body: some View {
        Image(uiImage: VeilROCFlagText.makeImage())
            .renderingMode(.original)
            .interpolation(.high)
            .resizable()
            .aspectRatio(1.5, contentMode: .fit)
            .frame(width: 24, height: 16)
            .accessibilityLabel(VeilROCFlagText.spokenName)
    }
}
