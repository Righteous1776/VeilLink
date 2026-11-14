#if os(iOS)
import SwiftUI
import ReplayKit

/// Host-app picker control for iOS 26, displayed ONLY after the viewer accepts.
/// Unlike screen recorder startCapture(), ReplayKit broadcast captures OTHER APPS.
struct VeilScreenLegacyBroadcastPicker: UIViewRepresentable {
    let extensionBundleID: String
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let view = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 72, height: 72))
        view.preferredExtension = extensionBundleID
        view.showsMicrophoneButton = false
        return view
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
#endif
