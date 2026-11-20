import SwiftUI

/// Lightweight observer lives outside ChatView's large ViewBuilder and never
/// inserts screen content into the persistent message timeline or database.
struct VeilScreenConversationHost: View {
    @ObservedObject var screen: VeilScreenCoordinator
    let peerID: String
    let peerDisplayName: String

    private var active: VeilScreenSnapshot? {
        guard let value = screen.snapshot,
              value.peerIdentityID == peerID,
              !value.isTerminal else { return nil }
        return value
    }

    var body: some View {
        Group {
            if let current = active {
                VeilScreenInviteCard(
                    snapshot: current, peerDisplayName: peerDisplayName,
                    now: screen.now,
                    onAccept: { _ = screen.accept() },
                    onDecline: { screen.decline() },
                    onSystemPicker: { screen.requestPicker() },
                    onOpenViewer: { screen.openViewer() },
                    onStop: { screen.stop() }
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("chat.veilscreen.session-card")
            }
        }
        .sheet(isPresented: Binding(
            get: { active?.role == .sender && screen.showsConsent },
            set: { if !$0 { screen.dismissConsent() } }
        )) {
            if let current = active, current.role == .sender {
                VeilScreenReplayKitConsentView(
                    sessionID: current.sessionID,
                    onCancel: { screen.stop() }
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { active?.role == .viewer && screen.showsViewer },
            set: { if !$0 { screen.dismissViewer() } }
        )) {
            if let current = active, current.role == .viewer {
                VeilScreenViewerView(
                    snapshot: current, frame: screen.receivedFrame,
                    now: screen.now, onStop: { screen.stop() },
                    onDismiss: { screen.dismissViewer() }
                )
            }
        }
    }
}
