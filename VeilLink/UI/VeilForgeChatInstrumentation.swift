import SwiftUI

/// Chat instrumentation only decorates existing layout slots. No gesture
/// recognizers, looping timelines, ordering changes or scroll-to commands.
struct VeilForgeConversationPlate: View {
    let selected: Bool
    let unreadCount: Int

    var body: some View {
        let shape = VeilPanelShape(cut: 15, radius: 2)
        shape
            .fill(selected ? VeilTheme.panelSoft : VeilTheme.elevated)
            .overlay(shape.stroke(
                selected ? VeilTheme.gold.opacity(0.50) : VeilTheme.hairline,
                lineWidth: 1
            ))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(selected ? VeilTheme.goldBright :
                          unreadCount > 0 ? VeilTheme.gold : VeilTheme.hairline)
                    .frame(width: 3)
                    .padding(.vertical, 12)
                    .scaleEffect(x: 1, y: selected || unreadCount > 0 ? 1 : 0.38)
                    .animation(.easeOut(duration: 0.15), value: selected)
                    .animation(.easeOut(duration: 0.15), value: unreadCount > 0)
            }
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(selected ? VeilTheme.goldBright : VeilTheme.paleMetal.opacity(0.32))
                    .frame(width: selected ? 34 : 14, height: 1)
                    .padding(.leading, 11)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct VeilForgeUnreadLatch: View {
    let count: Int

    var body: some View {
        ZStack {
            VeilPanelShape(cut: 5, radius: 1)
                .fill(VeilTheme.goldBright)
            HStack(spacing: 2) {
                Text(count > 99 ? "99+" : String(max(0, count)))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.black.opacity(0.90))
                    .monospacedDigit()
                Rectangle()
                    .fill(Color.black.opacity(0.60))
                    .frame(width: 2, height: 9)
            }
        }
        .frame(width: 37, height: 20)
        .accessibilityLabel("\(count) 条未读")
    }
}

/// Mutually exclusive real delivery-state detents; never a fake progress bar.
enum VeilForgeChatDeliveryPolicy {
    static func position(_ state: ChatMessage.DeliveryState) -> Int {
        switch state {
        case .queued: return 0
        case .sending: return 1
        case .delivered: return 2
        case .paused, .cancelled, .failed: return 0
        }
    }
    static func code(_ state: ChatMessage.DeliveryState) -> String {
        switch state {
        case .queued: return "QUEUE"
        case .sending: return "TX"
        case .delivered: return "ACK"
        case .paused: return "HOLD"
        case .cancelled: return "STOP"
        case .failed: return "ERR"
        }
    }
}

struct VeilForgeDeliveryRail: View {
    let state: ChatMessage.DeliveryState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var stage: Int { VeilForgeChatDeliveryPolicy.position(state) }
    private var failed: Bool { state == .failed }
    private var halted: Bool { state == .paused || state == .cancelled }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Rectangle()
                    .fill(index == stage
                          ? (failed ? VeilTheme.danger :
                             halted ? VeilTheme.mutedGold : VeilTheme.goldBright)
                          : VeilTheme.hairline)
                    .frame(width: 8, height: index == stage ? 5 : 2)
            }
            Text(VeilForgeChatDeliveryPolicy.code(state))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(failed ? VeilTheme.danger :
                                 halted ? VeilTheme.mutedGold : VeilTheme.secondaryText)
                .frame(width: 36, alignment: .leading)
        }
        .frame(height: 12)
        .animation(
            VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion),
            value: stage
        )
        .animation(
            VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion),
            value: state
        )
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(VeilForgeChatDeliveryPolicy.code(state))
    }
}

struct VeilForgeBubbleSurface: View {
    let outgoing: Bool

    var body: some View {
        let shape = VeilPanelShape(cut: 11, radius: 2)
        shape
            .fill(outgoing ? VeilTheme.goldBright : VeilTheme.panel)
            .overlay(shape.stroke(
                outgoing ? Color.black.opacity(0.15) : VeilTheme.hairline,
                lineWidth: 1
            ))
            .overlay(alignment: outgoing ? .bottomTrailing : .topLeading) {
                Rectangle()
                    .fill(outgoing ? Color.black.opacity(0.42) : VeilTheme.gold.opacity(0.75))
                    .frame(width: 15, height: 2)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Existing native Button(action:) remains the sole interaction surface.
struct VeilForgeSendPlunger: View {
    let armed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VeilPanelShape(cut: 9, radius: 2)
                .fill(armed ? VeilTheme.goldBright : VeilTheme.panelSoft)
            VeilPanelShape(cut: 9, radius: 2)
                .stroke(armed ? VeilTheme.gold : VeilTheme.hairline, lineWidth: 1)
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(armed ? Color.black.opacity(0.90) : VeilTheme.tertiaryText)
                .offset(y: armed ? -1 : 1)
            Rectangle()
                .fill(armed ? Color.black.opacity(0.55) : VeilTheme.tertiaryText)
                .frame(width: 11, height: 1)
                .offset(y: 11)
        }
        .frame(width: 36, height: 36)
        .animation(
            VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion),
            value: armed
        )
        .contentShape(Rectangle())
        .accessibilityLabel(armed ? "发送加密消息" : "没有可发送的内容")
    }
}

/// Fixed-size composer overlay: no extra footer height and no keyboard reflow.
struct VeilForgeComposerLatch: View {
    let armed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(VeilTheme.hairline)
                .frame(maxWidth: .infinity, maxHeight: 1)
            Rectangle()
                .fill(armed ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                .frame(width: armed ? 22 : 8, height: 2)
            Text(armed ? "TX ARMED" : "TX STANDBY")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(armed ? VeilTheme.goldBright : VeilTheme.tertiaryText)
                .frame(width: 72)
            Rectangle()
                .fill(VeilTheme.hairline)
                .frame(maxWidth: .infinity, maxHeight: 1)
        }
        .frame(height: 2)
        .animation(
            VeilMotionPolicy.animation(.resolve, reduceMotionRequested: reduceMotion),
            value: armed
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
