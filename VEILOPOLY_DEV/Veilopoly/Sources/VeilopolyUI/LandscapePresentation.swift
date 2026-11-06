#if os(iOS) && canImport(SwiftUI)
import SwiftUI
import UIKit

/// The parent app target must opt in to landscape in UISupportedInterfaceOrientations.
/// `preferredInterfaceOrientations` of its root/container controller must not
/// suppress landscape; a scene request alone cannot override Info.plist.
/// Public presentation entry for Veilopoly. This uses a full-screen cover, not a
/// game-card embedded in the VeilLink game hall. The orientation request requires
/// the host iOS target to declare landscape orientations in Info.plist.
@MainActor
public struct VeilopolyFullscreenModifier: ViewModifier {
 @Binding private var isPresented: Bool
 private let seed: UInt64
 private let humanCount: Int

 public init(isPresented: Binding<Bool>, seed: UInt64, humanCount: Int) {
  _isPresented = isPresented
  self.seed = seed
  self.humanCount = humanCount
 }

 public func body(content: Content) -> some View {
  content.fullScreenCover(isPresented: $isPresented) {
   VeilopolyGameView(seed: seed, humanCount: humanCount, onExit: { isPresented = false })
    .background(LandscapeSceneRequest())
    .statusBarHidden(true)
    .persistentSystemOverlays(.hidden)
  }
 }
}

@MainActor
public extension View {
 /// Call on an existing parent view with a state binding. P5 is responsible for
 /// invoking this from the actual VeilLink game hall after separate approval.
 func veilopolyFullscreen(isPresented: Binding<Bool>, seed: UInt64 = 1729123,
                          humanCount: Int = 1) -> some View {
  modifier(VeilopolyFullscreenModifier(isPresented: isPresented, seed: seed, humanCount: humanCount))
 }
}

/// Requests landscape through the iOS 16 UIWindowScene API. It never mutates
/// UIApplication private selectors, UIDevice orientation or global app delegates.
/// If the host denies landscape, the game shows a rotate-device explanation.
private struct LandscapeSceneRequest: UIViewControllerRepresentable {
 func makeUIViewController(context: Context) -> OrientationProbe { OrientationProbe() }
 func updateUIViewController(_ uiViewController: OrientationProbe, context: Context) {}
}

private final class OrientationProbe: UIViewController {
 private var requested = false
 private weak var lastWindowScene: UIWindowScene?
 private var restoreOrientation: UIInterfaceOrientationMask = .portrait
 override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
 override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
 override var prefersStatusBarHidden: Bool { true }

 override func viewDidAppear(_ animated: Bool) {
  super.viewDidAppear(animated)
  guard !requested, let windowScene = view.window?.windowScene else { return }
  requested = true
  lastWindowScene = windowScene
  switch windowScene.interfaceOrientation {
  case .landscapeLeft: restoreOrientation = .landscapeLeft
  case .landscapeRight: restoreOrientation = .landscapeRight
  default: restoreOrientation = .portrait
  }
  setNeedsUpdateOfSupportedInterfaceOrientations()
  windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
   // This can be denied when the host Info.plist does not support landscape,
   // or in certain multitasking configurations. Surface is portraitFallback.
   NSLog("Veilopoly landscape request was not accepted: %@", String(describing: error))
  }
 }

 override func viewDidDisappear(_ animated: Bool) {
  super.viewDidDisappear(animated)
  guard requested, let windowScene = lastWindowScene else { return }
  requested = false
  lastWindowScene = nil
  windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: restoreOrientation)) { error in
   NSLog("Veilopoly portrait restoration was not accepted: %@", String(describing: error))
  }
 }
}
#endif
