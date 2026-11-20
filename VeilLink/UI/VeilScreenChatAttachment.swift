#if os(iOS)
import SwiftUI

/// Ephemeral session card only. This is deliberately separate from MessageBubble
/// and is not written to the chat database, search index or durable outbox.
struct VeilScreenChatAttachment: View {
    @ObservedObject var controller: VeilScreenBridgeController
    let peerIdentityID: String
    let peerDisplayName: String

    var body: some View {
        Group {
            if let state = controller.snapshot,
               state.peerIdentityID == peerIdentityID, !state.isTerminal {
                VeilScreenInviteCard(
                    snapshot: state,
                    peerDisplayName: peerDisplayName,
                    now: Date().timeIntervalSince1970,
                    onAccept: { controller.accept() },
                    onDecline: { controller.decline() },
                    onSystemPicker: { controller.requestCaptureConsent() },
                    onOpenViewer: { controller.showsViewer = true },
                    onStop: { controller.stop() }
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .sheet(isPresented: $controller.showsConsent) {
            if let state = controller.snapshot, state.role == .sender,
               state.peerIdentityID == peerIdentityID,
               (state.phase == .connecting || state.phase == .live || state.phase == .stalled) {
                VeilScreenReplayKitConsentView(
                    sessionID: state.sessionID,
                    onCancel: { controller.stop() },
                    host: controller.broadcastHost,
                    onPrepare: { controller.prepareCapture() }
                )
            }
        }
        .sheet(isPresented: $controller.showsViewer) {
            if let state = controller.snapshot, state.role == .viewer,
               state.peerIdentityID == peerIdentityID {
                VeilScreenViewerView(
                    snapshot: state,
                    frame: controller.receivedFrame,
                    now: Date().timeIntervalSince1970,
                    onStop: { controller.stop() },
                    onDismiss: { controller.showsViewer = false }
                )
            }
        }
    }
}
#endif
