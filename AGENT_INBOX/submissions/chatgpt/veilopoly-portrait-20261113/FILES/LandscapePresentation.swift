#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// Orientation follows the host's currently allowed portrait or landscape mode.
/// No geometry/rotation request is issued by the Veilopoly presentation.
/// Public presentation entry for Veilopoly. This uses a full-screen cover, not a
/// game-card embedded in the VeilLink game hall. Host Info.plist remains authoritative.
@MainActor
public struct VeilopolyFullscreenModifier: ViewModifier {
 @Binding private var isPresented: Bool
 private let seed: UInt64?
 private let humanCount: Int

 public init(isPresented: Binding<Bool>, seed: UInt64?, humanCount: Int) {
  _isPresented = isPresented
  self.seed = seed
  self.humanCount = humanCount
 }

 public func body(content: Content) -> some View {
  content.fullScreenCover(isPresented: $isPresented) {
   VeilopolyGameView(seed: seed, humanCount: humanCount, onExit: { isPresented = false })
    .statusBarHidden(true)
  }
 }
}

@MainActor
public extension View {
 /// Local game-hall entry. Nil uses fresh-match entropy; existing saves resume
 /// their persisted seed. Explicit seeds remain available for deterministic tests.
 func veilopolyFullscreen(isPresented: Binding<Bool>, seed: UInt64? = nil,
                          humanCount: Int = 1) -> some View {
  modifier(VeilopolyFullscreenModifier(isPresented: isPresented, seed: seed, humanCount: humanCount))
 }
}

/// The host supplies the already-bound live model; never creates a solo save
/// or a second game while presenting a multiplayer room.
@MainActor
public struct VeilopolyMultiplayerGameView: View {
 private let session: GameSessionModel
 private let onExit: () -> Void
 public init(session: GameSessionModel, onExit: @escaping () -> Void) {
  self.session = session; self.onExit = onExit
 }
 public var body: some View {
  VeilopolyGameView(session: session, onExit: onExit)
   .statusBarHidden(true)
 }
}

#endif
