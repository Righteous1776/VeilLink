import SpriteKit
import SwiftUI

/// Standalone integration entry point for the real-time platformer.
///
/// It owns the SpriteKit scene lifecycle, so callers can use it directly as a
/// `NavigationLink` destination without supplying a model or coordinator.
struct VeilPulseRunnerView: View {
    @StateObject private var session = PlatformerGameSession()
    @State private var pausedByLifecycle = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            SpriteView(scene: session.scene)
                .ignoresSafeArea()
                .accessibilityLabel("星隙快递实时横版游戏场景")

            VStack(spacing: 0) {
                hud
                Spacer(minLength: 16)
                messagePill
                controls
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 14)

            if session.phase == .paused {
                pauseOverlay
            } else if session.phase == .gameOver || session.phase == .campaignComplete {
                resultOverlay
            }
        }
        .background(Color(red: 0.025, green: 0.035, blue: 0.09))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("星隙快递")
                    .font(.headline.weight(.bold))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    session.phase == .paused ? session.resume() : session.pause()
                } label: {
                    Image(systemName: session.phase == .paused ? "play.fill" : "pause.fill")
                }
                .disabled(session.phase != .playing && session.phase != .paused)
                .accessibilityLabel(session.phase == .paused ? "继续游戏" : "暂停游戏")
            }
        }
        .onAppear {
            if pausedByLifecycle {
                pausedByLifecycle = false
                session.resume()
            } else {
                session.start()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                if pausedByLifecycle {
                    pausedByLifecycle = false
                    session.resume()
                }
            } else if session.phase == .playing {
                pausedByLifecycle = true
                session.pause()
            }
        }
        .onDisappear {
            if session.phase == .playing { pausedByLifecycle = true }
            session.pause()
        }
    }

    private var hud: some View {
        HStack(spacing: 9) {
            hudBadge(icon: "location.north.line.fill", value: "\(session.levelIndex + 1)/\(session.levels.count)")
            hudBadge(icon: "diamond.fill", value: "\(session.collectedCrystals)/\(session.requiredCrystals)", tint: .cyan)
            hudBadge(icon: "heart.fill", value: "\(session.lives)", tint: .pink)
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%05d", session.score))
                    .font(.system(.headline, design: .monospaced).weight(.black))
                Text(timeText)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundColor(.white.opacity(0.68))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .foregroundColor(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(session.levelIndex + 1) 关，星核 \(session.collectedCrystals) 个，共 \(session.requiredCrystals) 个，生命 \(session.lives)，得分 \(session.score)")
    }

    private var messagePill: some View {
        Text(session.message)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white.opacity(0.92))
            .lineLimit(1)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.42), in: Capsule())
            .overlay(Capsule().stroke(Color.cyan.opacity(0.25), lineWidth: 1))
            .padding(.bottom, 10)
    }

    private var controls: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 12) {
                holdControl(icon: "arrow.left", accessibilityName: "向左移动", direction: -1)
                holdControl(icon: "arrow.right", accessibilityName: "向右移动", direction: 1)
            }
            Spacer()
            HStack(spacing: 12) {
                actionControl(
                    icon: "bolt.fill",
                    title: "冲刺",
                    tint: session.dashReady ? .pink : .gray,
                    enabled: session.dashReady,
                    action: session.dash
                )
                jumpControl
            }
        }
    }

    private func holdControl(icon: String, accessibilityName: String, direction: CGFloat) -> some View {
        Image(systemName: icon)
            .font(.system(size: 24, weight: .black))
            .foregroundColor(.white)
            .frame(width: 64, height: 64)
            .background(
                Circle().fill(Color(red: 0.08, green: 0.14, blue: 0.25).opacity(0.9))
            )
            .overlay(Circle().stroke(Color.cyan.opacity(0.6), lineWidth: 2))
            .shadow(color: .cyan.opacity(0.24), radius: 10)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in session.move(horizontal: direction) }
                    .onEnded { _ in session.move(horizontal: 0) }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(accessibilityName)
    }

    private var jumpControl: some View {
        Image(systemName: "arrow.up.right.circle.fill")
            .font(.system(size: 31, weight: .black))
            .foregroundColor(.white)
            .frame(width: 72, height: 72)
            .background(Circle().fill(Color.cyan.opacity(0.78)))
            .overlay(Circle().stroke(Color.white.opacity(0.76), lineWidth: 2))
            .shadow(color: .cyan.opacity(0.42), radius: 13)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in session.jump() }
                    .onEnded { _ in session.releaseJump() }
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("跳跃")
    }

    private func actionControl(
        icon: String,
        title: String,
        tint: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 22, weight: .black))
                Text(title).font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(width: 62, height: 62)
            .background(Circle().fill(tint.opacity(enabled ? 0.78 : 0.35)))
            .overlay(Circle().stroke(Color.white.opacity(enabled ? 0.58 : 0.2), lineWidth: 2))
            .shadow(color: tint.opacity(enabled ? 0.35 : 0), radius: 10)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }

    private var pauseOverlay: some View {
        overlayCard(
            icon: "pause.circle.fill",
            title: "信号暂停",
            subtitle: "进度保留在本机",
            buttonTitle: "继续传送",
            action: session.resume
        )
    }

    private var resultOverlay: some View {
        overlayCard(
            icon: session.phase == .campaignComplete ? "sparkles" : "waveform.path.ecg.rectangle",
            title: session.phase == .campaignComplete ? "极光信标已点亮" : "连接中断",
            subtitle: session.phase == .campaignComplete ? "最终得分 \(session.score)" : "最终得分 \(session.score) · 再试一次",
            buttonTitle: session.phase == .campaignComplete ? "重新出发" : "重新连接",
            action: session.start
        )
    }

    private func overlayCard(
        icon: String,
        title: String,
        subtitle: String,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 43, weight: .bold))
                .foregroundColor(.cyan)
            Text(title).font(.title2.weight(.black))
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Button(buttonTitle, action: action)
                .font(.headline.weight(.bold))
                .foregroundColor(Color(red: 0.025, green: 0.035, blue: 0.09))
                .padding(.horizontal, 24)
                .padding(.vertical, 11)
                .background(Color.cyan, in: Capsule())
        }
        .foregroundColor(.white)
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 30)
        .padding(24)
    }

    private func hudBadge(icon: String, value: String, tint: Color = .white) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(tint)
            Text(value).font(.caption.monospacedDigit().weight(.bold))
        }
    }

    private var timeText: String {
        let total = Int(session.elapsedTime)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
