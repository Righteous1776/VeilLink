import Foundation

/// Renderer-neutral, UIKit TOP-LEFT coordinate system measured in logical points.
/// Never confuse points, physical pixels or SpriteKit Y-up world coordinates.
public enum VeilRenderGeometry {
    public struct Point: Equatable, Sendable { public var x: Double; public var y: Double
        public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    }
    public struct Size: Equatable, Sendable { public var width: Double; public var height: Double
        public init(_ width: Double, _ height: Double) { self.width = width; self.height = height }
        public var valid: Bool { width.isFinite && height.isFinite && width > 0 && height > 0 }
    }
    public struct Insets: Equatable, Sendable { public var top, left, bottom, right: Double
        public init(top: Double = 0, left: Double = 0, bottom: Double = 0, right: Double = 0) {
            self.top = top; self.left = left; self.bottom = bottom; self.right = right
        }
        public var valid: Bool { [top, left, bottom, right].allSatisfy { $0.isFinite && $0 >= 0 } }
    }
    public struct Rect: Equatable, Sendable {
        public let x, y, width, height: Double
        public func contains(_ p: Point) -> Bool {
            x <= p.x && p.x <= x + width && y <= p.y && p.y <= y + height
        }
    }
    public struct Projection: Equatable, Sendable {
        public let canvas: Size
        public let available: Rect
        public let viewport: Rect
        public let scale: Double
        public let pixelsPerPoint: Double
        public func toView(_ logical: Point) -> Point {
            Point(viewport.x + logical.x * scale, viewport.y + logical.y * scale)
        }
        public func toLogical(_ view: Point) -> Point? {
            guard viewport.contains(view) else { return nil } // Letterbox is never tappable.
            return Point((view.x - viewport.x) / scale, (view.y - viewport.y) / scale)
        }
        public func toSpriteKit(_ logical: Point) -> Point {
            Point(logical.x, canvas.height - logical.y)
        }
        public var aspectDistortion: Double { abs(viewport.width / canvas.width - viewport.height / canvas.height) }
        public var drawablePixels: Size { Size(viewport.width * pixelsPerPoint, viewport.height * pixelsPerPoint) }
    }
    public enum Failure: Error, Equatable { case invalidCanvas, invalidView, invalidInsets, noDrawableArea, invalidScale }
    /// aspectFIT: preserve whole interactive canvas on every device, with symmetric letterboxing.
    /// Safe-area applies only when the container has not already been inset by SwiftUI/UIKit.
    public static func fit(canvas: Size, in view: Size, insets: Insets = .init(), pixelsPerPoint: Double = 2) throws -> Projection {
        guard canvas.valid else { throw Failure.invalidCanvas }
        guard view.valid else { throw Failure.invalidView }
        guard insets.valid else { throw Failure.invalidInsets }
        guard pixelsPerPoint.isFinite && pixelsPerPoint > 0 && pixelsPerPoint <= 8 else { throw Failure.invalidScale }
        let width = view.width - insets.left - insets.right
        let height = view.height - insets.top - insets.bottom
        guard width > 0 && height > 0 else { throw Failure.noDrawableArea }
        let scale = min(width / canvas.width, height / canvas.height)
        guard scale.isFinite && scale > 0 else { throw Failure.noDrawableArea }
        let viewportW = canvas.width * scale
        let viewportH = canvas.height * scale
        return Projection(canvas: canvas,
                available: Rect(x: insets.left, y: insets.top, width: width, height: height),
                viewport: Rect(x: insets.left + (width - viewportW) * 0.5,
                               y: insets.top + (height - viewportH) * 0.5,
                               width: viewportW, height: viewportH),
                scale: scale, pixelsPerPoint: pixelsPerPoint)
    }
}
