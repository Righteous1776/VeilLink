/// Portable interaction state for card presentation. SpriteKit can finish
/// its sound/reveal timeline, but the queue must not advance until the player
/// explicitly dismisses the visible card. No wall clock or random source.
public enum CardDismissAction: Equatable, Sendable {
 case none
 case advanceQueue
 case finishAnimation
}
public struct CardRevealGate: Equatable, Sendable {
 public private(set) var isPresented = false
 public private(set) var animationCompleted = false
 public init() {}
 public mutating func present() {
  isPresented = true
  animationCompleted = false
 }
 @discardableResult
 public mutating func animationDidComplete() -> Bool {
  guard isPresented else { return true }
  animationCompleted = true
  return false
 }
 public mutating func dismiss() -> CardDismissAction {
  guard isPresented else { return .none }
  let result: CardDismissAction = animationCompleted ? .advanceQueue : .finishAnimation
  reset()
  return result
 }
 public mutating func reset() {
  isPresented = false
  animationCompleted = false
 }
}
