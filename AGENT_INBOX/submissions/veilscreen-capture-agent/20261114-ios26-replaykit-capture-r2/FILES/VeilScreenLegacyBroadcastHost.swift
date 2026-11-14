#if os(iOS)
import Foundation
import Combine

/// Signed host only. Preparation must occur after viewer acceptance and BEFORE
/// the person taps ReplayKit's system broadcast picker.
@MainActor
final class VeilScreenLegacyBroadcastHost: ObservableObject {
    @Published private(set) var isPrepared = false
    @Published private(set) var status = "未准备"
    private var mailbox: VeilScreenEncryptedMailbox?
    private var currentID: UUID?

    func prepare(sessionID: UUID, interval: Double = 2.5,
                 width: Int = 320, byteBudget: Int = 6 * 1024) -> Bool {
        stop()
        guard let config = VeilScreenBroadcastSecurityConfig.load() else {
            status = "缺少 App Group/钥匙串共享签名能力"
            return false
        }
        let expiration = Date().addingTimeInterval(1800)
        let item = VeilScreenBroadcastSessionConfig(
            sessionID: sessionID,
            expiresAt: expiration,
            frameIntervalSeconds: interval,
            targetWidth: width,
            byteBudget: byteBudget
        )
        guard item.valid(at: Date()) else { status = "视频采样参数无效"; return false }
        do {
            let bridge = VeilScreenEncryptedMailbox(config: config)
            try bridge.activate(item)
            self.mailbox = bridge
            currentID = sessionID
            isPrepared = true
            status = "请使用系统按钮开启屏幕广播"
            return true
        } catch {
            status = "系统广播准备失败：请检查签名配置"
            return false
        }
    }

    func stop() {
        if let currentID { mailbox?.deactivate(sessionID: currentID) }
        currentID = nil
        mailbox = nil
        isPrepared = false
        status = "已停止"
    }
}
#endif
