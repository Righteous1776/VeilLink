/// Pure Swift geometry, independent of Darwin/CoreGraphics overlay imports.
/// Convert to CGFloat only at the SwiftUI boundary.
public struct VeilopolyPanelFrame: Equatable, Sendable {
 public let x: Double
 public let y: Double
 public let width: Double
 public let height: Double
 public var minX: Double { x }
 public var minY: Double { y }
 public var maxX: Double { x + width }
 public var maxY: Double { y + height }
 public var midX: Double { x + width / 2 }
 public var midY: Double { y + height / 2 }
}

/// Presentation only. Coordinates are normalized to the available travel, so
/// safe-area/size changes cannot strand a panel offscreen. Never part of a save,
/// reducer move, stock clock, render ACK or network message.
public struct VeilopolyPanelAnchor: Equatable, Sendable {
 public var x: Double
 public var y: Double
 public init(x: Double, y: Double) {
  self.x = x.isFinite ? min(1, max(0, x)) : 1
  self.y = y.isFinite ? min(1, max(0, y)) : 0
 }
 public static let topRight = Self(x: 1, y: 0)
 public static let bottomRight = Self(x: 1, y: 1)
}

public struct VeilopolyPanelLayout: Equatable, Sendable {
 public enum Surface { case panel, chip }
 public let width: Double
 public let height: Double
 public static let edge = 6.0
 // Reserve the entire top strip for news + the destructive More/Exit capsule.
 public static let top = 54.0
 public static let bottom = 10.0
 public static let chipHeight = 72.0

 public init(width: Double, height: Double) {
  self.width = width.isFinite ? max(0, width) : 0
  self.height = height.isFinite ? max(0, height) : 0
 }

 public func frame(for surface: Surface, anchor: VeilopolyPanelAnchor,
                   dx: Double = 0, dy: Double = 0) -> VeilopolyPanelFrame {
  let usableWidth = max(0, width - 2 * Self.edge)
  let usableHeight = max(0, height - Self.top - Self.bottom)
  let w = surface == .panel
   ? min(usableWidth, VeilopolyLandscapeLayout.overlayDrawerWidth(for: width))
   : min(usableWidth, 280)
  let h = surface == .panel
   ? min(usableHeight, max(260, min(560, height * 0.78)))
   : min(usableHeight, Self.chipHeight)
  let left = min(Self.edge, width)
  let top = min(Self.top, height)
  let travelX = max(0, usableWidth - w)
  let travelY = max(0, usableHeight - h)
  let normalized = VeilopolyPanelAnchor(x: anchor.x, y: anchor.y)
  let x = left + min(travelX, max(0, travelX * normalized.x + (dx.isFinite ? dx : 0)))
  let y = top + min(travelY, max(0, travelY * normalized.y + (dy.isFinite ? dy : 0)))
  return VeilopolyPanelFrame(x: x, y: y, width: w, height: h)
 }

 /// Do not use the predicted end translation: a fast flick must not launch a
 /// financial panel across the screen or underneath the Exit control.
 public func moved(_ anchor: VeilopolyPanelAnchor, surface: Surface,
                   dx: Double, dy: Double) -> VeilopolyPanelAnchor {
  let original = frame(for: surface, anchor: anchor)
  let moved = frame(for: surface, anchor: anchor, dx: dx, dy: dy)
  let travelX = max(0, width - 2 * Self.edge - Double(original.width))
  let travelY = max(0, height - Self.top - Self.bottom - Double(original.height))
  return .init(x: travelX > 0 ? (Double(moved.minX) - Self.edge) / travelX : anchor.x,
               y: travelY > 0 ? (Double(moved.minY) - Self.top) / travelY : anchor.y)
 }
}

/// A new decision opens once. Prices, ACK refreshes, or re-observing the same
/// decision must not undo a deliberate suspension. Includes the subject so a
/// different purchase in the same phase is not mistaken for an old prompt.
public struct VeilopolyPanelDecision: Equatable, Sendable {
 public let seed: UInt64
 public let actor: Int
 public let phase: String
 public let subject: Int?
 public init(seed: UInt64, actor: Int, phase: String, subject: Int? = nil) {
  self.seed = seed; self.actor = actor; self.phase = phase; self.subject = subject
 }
}

public struct VeilopolyPanelWorkspace: Equatable, Sendable {
 public private(set) var isExpanded = false
 public var panelAnchor = VeilopolyPanelAnchor.topRight
 public var chipAnchor = VeilopolyPanelAnchor.bottomRight
 public private(set) var decision: VeilopolyPanelDecision?
 public init() {}
 public mutating func open() { isExpanded = true }
 public mutating func suspend() { isExpanded = false }
 public mutating func observe(_ decision: VeilopolyPanelDecision?) {
  guard self.decision != decision else { return }
  self.decision = decision
  if decision != nil { open() }
 }
 public mutating func resetPlacement() {
  panelAnchor = .topRight; chipAnchor = .bottomRight
 }
 public mutating func resetSession() { self = Self() }
}
