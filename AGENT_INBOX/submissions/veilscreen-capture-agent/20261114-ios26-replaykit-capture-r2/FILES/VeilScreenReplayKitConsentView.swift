#if os(iOS)
import SwiftUI

/// Present only after an authenticated viewer acceptance. Not a substitute for
/// the system ReplayKit picker; the user must explicitly tap Start Broadcast.
struct VeilScreenReplayKitConsentView: View {
    let sessionID: UUID
    let onCancel: () -> Void
    @StateObject private var host = VeilScreenLegacyBroadcastHost()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("通过蓝牙共享屏幕", systemImage: "rectangle.on.rectangle")
                .font(.title3.bold())
            Text("你正在向已确认的联系人请求系统屏幕广播。切换到其他 App 后，画面可能包含通知、聊天文字或其他私密内容。")
                .font(.callout)
            Text("仅传画面；不传麦克风或系统声音。你可以随时使用 iOS 的屏幕广播状态控制结束共享。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if host.isPrepared {
                HStack(spacing: 12) {
                    VeilScreenLegacyBroadcastPicker(
                        extensionBundleID: "studio.zeo.veillink.screenshare"
                    )
                    Text("点按系统按钮并确认开始广播")
                        .font(.caption)
                }
            } else {
                Text(host.status).foregroundStyle(.secondary).font(.footnote)
                Button("准备屏幕共享") {
                    _ = host.prepare(sessionID: sessionID)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("取消共享", role: .cancel) {
                host.stop()
                onCancel()
            }
            .buttonStyle(.bordered)
            Spacer(minLength: 0)
        }
        .padding(20)
    }
}
#endif
