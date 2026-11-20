#if os(iOS)
import SwiftUI
import UIKit

/// Presentation only. It has zero direct access to camera, screen, BLE or storage.
/// The owning authenticated coordinator supplies a snapshot and handles actions.
struct VeilScreenInviteCard: View {
    let snapshot: VeilScreenSnapshot
    let peerDisplayName: String
    let now: TimeInterval
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onSystemPicker: () -> Void
    let onOpenViewer: () -> Void
    let onStop: () -> Void

    private var status: String {
        switch snapshot.phase {
        case .inviting: return "已发送邀请 · 等待对方确认"
        case .incomingInvite: return "对方邀请你观看屏幕"
        case .awaitingSystemConsent: return "对方已接受 · 等待你授权系统采集"
        case .awaitingSender: return "已接受 · 等待对方开始共享"
        case .connecting: return "正在连接屏幕画面"
        case .live: return snapshot.role == .sender ? "正在共享屏幕" : "正在接收屏幕"
        case .stalled: return "画面更新延迟 · 正在恢复"
        case .ended: return "屏幕共享已结束"
        case .failed: return "屏幕共享失败"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 42, height: 42)
                    .foregroundColor(.black)
                    .background(VeilScreenColors.accent, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("VeilScreen")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("蓝牙 · 端到端加密 · 无声音")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(VeilScreenColors.secondary)
                }
                Spacer(minLength: 0)
                if snapshot.phase == .live {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(VeilScreenColors.accent)
                        .accessibilityLabel("共享正在进行")
                }
            }

            Text(status)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(VeilScreenColors.secondary)
                .fixedSize(horizontal: false, vertical: true)

            actionRows
        }
        .padding(16)
        .frame(maxWidth: 355, alignment: .leading)
        .background(VeilScreenColors.panel, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(VeilScreenColors.hairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var detail: String {
        switch snapshot.phase {
        case .inviting, .incomingInvite:
            return "邀请有效期约 \(max(0, Int(snapshot.expiresAt - now))) 秒。接受邀请不代表允许远程自动录屏。"
        case .awaitingSystemConsent:
            return "只有你在苹果系统界面明确授权并启动后，\(peerDisplayName) 才能看到画面。"
        case .awaitingSender, .connecting:
            return "连接尚未建立，屏幕画面没有开始传输。"
        case .live:
            return "仅传输屏幕画面，不传输麦克风或应用声音。随时可以结束。"
        case .stalled:
            return "保留最后一帧供查看，但画面可能已过时。"
        case .ended, .failed:
            return "此会话已关闭，不会自动重新开始。"
        }
    }

    @ViewBuilder private var actionRows: some View {
        switch snapshot.phase {
        case .incomingInvite:
            HStack(spacing: 9) {
                secondaryButton("拒绝", action: onDecline)
                primaryButton("接受观看", icon: "checkmark", action: onAccept)
            }
        case .awaitingSystemConsent:
            primaryButton("打开苹果系统共享选择器", icon: "rectangle.on.rectangle", action: onSystemPicker)
            secondaryButton("取消邀请", action: onStop)
        case .inviting:
            secondaryButton("撤销邀请", action: onStop)
        case .awaitingSender, .connecting:
            secondaryButton("取消等待", action: onStop)
        case .live, .stalled:
            if snapshot.role == .viewer {
                primaryButton("查看共享屏幕", icon: "arrow.up.left.and.arrow.down.right", action: onOpenViewer)
                secondaryButton("结束观看", action: onStop)
            } else {
                secondaryButton("停止共享", action: onStop)
            }
        case .ended, .failed:
            EmptyView()
        }
    }

    private func primaryButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundColor(.black)
                .background(VeilScreenColors.accent, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundColor(.white)
                .background(VeilScreenColors.panel2, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// User-controlled system consent. Rendering this does NOT start capture.
struct VeilScreenCaptureConsentView: View {
    let peerDisplayName: String
    let onOpenSystemPicker: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("共享自己的屏幕")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Spacer()
                Button("取消", action: onCancel)
                    .font(.subheadline)
            }
            .foregroundColor(.white)

            Image(systemName: "iphone.radiowaves.left.and.right")
                .resizable().scaledToFit()
                .frame(height: 86)
                .frame(maxWidth: .infinity)
                .foregroundColor(VeilScreenColors.accent)
                .padding(.vertical, 10)

            Text("你的整块系统屏幕可能包含通知、聊天和其他敏感画面。")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text("请先检查屏幕内容。开始后，\(peerDisplayName) 才能看到你主动选择的共享内容。此功能默认没有声音，不会在本机保存画面。")
                .font(.system(size: 13))
                .foregroundColor(VeilScreenColors.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onOpenSystemPicker) {
                Label("继续到苹果系统授权", systemImage: "rectangle.on.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(VeilScreenColors.accent, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundColor(.black)
            }
            .buttonStyle(.plain)
            Text("未经系统授权，VeilLink 不应采集或传输屏幕。")
                .font(.system(size: 11))
                .foregroundColor(VeilScreenColors.secondary)
            Spacer(minLength: 0)
        }
        .padding(22)
        .background(VeilScreenColors.background.ignoresSafeArea())
    }
}

/// The viewer is not a recorder: holds only the latest in-memory JPEG.
struct VeilScreenReceivedFrame: Equatable {
    let sessionID: UUID
    let frameID: UInt64
    let receivedAt: TimeInterval
    let jpeg: Data
}

struct VeilScreenViewerView: View {
    let snapshot: VeilScreenSnapshot
    let frame: VeilScreenReceivedFrame?
    let now: TimeInterval
    let onStop: () -> Void
    let onDismiss: () -> Void

    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat = 1
    @State private var pan: CGSize = .zero

    private var validFrame: VeilScreenReceivedFrame? {
        guard snapshot.role == .viewer,
              snapshot.isActivelyReceiving,
              let frame = frame, frame.sessionID == snapshot.sessionID,
              frame.frameID == snapshot.lastFrameID,
              !frame.jpeg.isEmpty, frame.jpeg.count <= 32 * 1024 else { return nil }
        return frame
    }

    private var age: TimeInterval? {
        guard let last = validFrame?.receivedAt else { return nil }
        return max(0, now - last)
    }

    var body: some View {
        ZStack {
            VeilScreenColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ZStack {
                    if let pixels = validFrame?.jpeg, let picture = UIImage(data: pixels) {
                        GeometryReader { geometry in
                            Image(uiImage: picture)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .scaleEffect(zoom)
                                .offset(pan)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { scale in zoom = min(5, max(1, zoomStart * scale)) }
                                        .onEnded { _ in zoomStart = zoom; if zoom == 1 { pan = .zero } }
                                )
                                .simultaneousGesture(DragGesture()
                                    .onChanged { drag in
                                        if zoom > 1 { pan = drag.translation }
                                    }
                                    .onEnded { _ in if zoom == 1 { pan = .zero } })
                                .onTapGesture(count: 2) {
                                    zoom = zoom == 1 ? 2.5 : 1
                                    zoomStart = zoom
                                    pan = .zero
                                }
                                .accessibilityLabel("远程屏幕画面。双击放大，捏合缩放")
                        }
                        .clipped()
                    } else {
                        VStack(spacing: 13) {
                            Image(systemName: "display")
                                .font(.system(size: 40, weight: .ultraLight))
                            Text(snapshot.isTerminal ? "共享已经结束" : "等待第一帧屏幕画面")
                                .font(.system(size: 15, weight: .medium))
                            Text("连接成功与收到画面是两个独立状态")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(VeilScreenColors.secondary)
                        .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 42, height: 42)
                    .background(VeilScreenColors.panel2, in: Circle())
            }
            .accessibilityLabel("收起观看界面")
            VStack(alignment: .leading, spacing: 4) {
                Text("VeilScreen").font(.system(size: 16, weight: .semibold))
                Text(statusLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(VeilScreenColors.secondary)
            }
            Spacer()
            Button("结束观看", action: onStop)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(Color.red.opacity(0.70), in: Capsule())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
    }

    private var statusLabel: String {
        switch snapshot.phase {
        case .stalled: return "画面延迟 · 保留最后一帧"
        case .live:
            guard let age = age else { return "已连接 · 等待画面" }
            return age >= 8 ? "画面已过时 · \(Int(age)) 秒" : "上一帧 \(String(format: "%.1f", age)) 秒前"
        case .ended: return "共享已结束"
        case .failed: return "连接失败"
        default: return "等待连接"
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "lock.shield")
                Text("仅观看 · 无声音 · 不保存")
                Spacer()
                Text("\(Int(zoom * 100))%")
                    .monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundColor(VeilScreenColors.secondary)
            Text("双击放大 · 双指缩放 · 拖动查看细节")
                .font(.system(size: 11))
                .foregroundColor(VeilScreenColors.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(VeilScreenColors.panel)
    }
}

private enum VeilScreenColors {
    static let background = Color(red: 0.035, green: 0.045, blue: 0.055)
    static let panel = Color(red: 0.075, green: 0.090, blue: 0.105)
    static let panel2 = Color(red: 0.14, green: 0.16, blue: 0.19)
    static let secondary = Color(red: 0.65, green: 0.67, blue: 0.69)
    static let accent = Color(red: 0.84, green: 0.72, blue: 0.48)
    static let hairline = Color.white.opacity(0.13)
}
#endif
