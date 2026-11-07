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
    .background(LandscapeSceneRequest())
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

/// iOS 15 supports controller-declared orientations and the public
/// attemptRotationToDeviceOrientation() fallback. iOS 16+ additionally
/// supports an explicit UIWindowScene geometry preference request.
/// Both paths require landscape in the *host* UISupportedInterfaceOrientations;
/// a child package cannot override the host's Info.plist.
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
  if #available(iOS 16.0, *) {
   setNeedsUpdateOfSupportedInterfaceOrientations()
   windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
    NSLog("Veilopoly landscape request denied by host: %@", String(describing: error))
   }
  } else {
   // Public iOS 15 API: system may rotate if the host explicitly allows it.
   UIViewController.attemptRotationToDeviceOrientation()
  }
 }

 override func viewDidDisappear(_ animated: Bool) {
  super.viewDidDisappear(animated)
  guard requested, let windowScene = lastWindowScene else { return }
  requested = false
  lastWindowScene = nil
  if #available(iOS 16.0, *) {
   windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: restoreOrientation)) { error in
    NSLog("Veilopoly orientation restoration denied by host: %@", String(describing: error))
   }
  } else {
   UIViewController.attemptRotationToDeviceOrientation()
  }
 }
}
#endif
