/// Renderer-only acknowledgment gate. It is intentionally portable so that
/// stale callbacks, double completion, skip, and command replacement are tested
/// without requiring an Apple SDK. This does not import or mutate game logic.
public struct RenderCommandAckGate: Sendable {
 public private(set) var nextID: UInt64 = 0
 public private(set) var pending: UInt64?

 public init() {}

 /// Replacing an unfinished render command invalidates its previous ACK token.
 @discardableResult
 public mutating func begin() -> UInt64 {
  nextID &+= 1
  pending = nextID
  return nextID
 }

 /// Return true only for the first ACK of the currently active command.
 /// All stale, duplicate, and superseded acknowledgments are ignored.
 @discardableResult
 public mutating func acknowledge(_ id: UInt64) -> Bool {
  guard pending == id else { return false }
  pending = nil
  return true
 }

 /// Invalidate the active ACK without dispatching a completion.
 public mutating func cancel() {
  pending = nil
 }
}
