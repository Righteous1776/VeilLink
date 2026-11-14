#if DEBUG && os(iOS)
import SwiftUI

/// Xcode design-time only. No BLE, no capture, no real peer data.
struct VeilScreenPreviewGallery: View {
    private let incoming = VeilScreenSnapshot.incoming(peerID: "demo-peer", at: 100, id: UUID())
    private let outgoing = VeilScreenSnapshot.outgoing(peerID: "demo-peer", at: 100)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("VeilScreen · R1 UI Gallery")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("仅为界面预览，不会连接蓝牙或打开系统录屏。")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("01 / 对方发来邀请").font(.caption.bold()).foregroundColor(.white)
                card(incoming)
                Text("02 / 等待对方接受").font(.caption.bold()).foregroundColor(.white)
                card(outgoing)
                Text("03 / 接收端无画面时").font(.caption.bold()).foregroundColor(.white)
                VeilScreenViewerView(snapshot: incoming, frame: nil, now: 103,
                                     onStop: {}, onDismiss: {})
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(18)
        }
        .background(Color.black)
    }

    private func card(_ snapshot: VeilScreenSnapshot) -> some View {
        VeilScreenInviteCard(snapshot: snapshot, peerDisplayName: "好友", now: 110,
                             onAccept: {}, onDecline: {}, onSystemPicker: {},
                             onOpenViewer: {}, onStop: {})
    }
}

struct VeilScreenPreviewGallery_Previews: PreviewProvider {
    static var previews: some View {
        VeilScreenPreviewGallery().preferredColorScheme(.dark)
    }
}
#endif
