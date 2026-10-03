import SwiftUI
import SpriteKit

@MainActor
final class SpaceGameSession: ObservableObject, SpaceGameSceneOutput {
    @Published private(set) var snapshot: SpaceGameSnapshot
    let scene: SpaceGameScene

    init(configuration: SpaceGameConfiguration = .standard) {
        let scene = SpaceGameScene(configuration: configuration)
        self.scene = scene
        self.snapshot = SpaceSimulation(configuration: configuration).snapshot
        scene.output = self
    }

    var isPaused: Bool { snapshot.phase == .paused }
    var isGameOver: Bool { snapshot.phase == .gameOver }

    func togglePause() {
        guard !isGameOver else { return }
        scene.setGamePaused(!isPaused)
    }

    func pause() {
        guard snapshot.phase == .playing else { return }
        scene.setGamePaused(true)
    }

    func resume() {
        guard snapshot.phase == .paused else { return }
        scene.setGamePaused(false)
    }

    func restart() {
        scene.restart()
    }

    func spaceScene(_ scene: SpaceGameScene, didRender snapshot: SpaceGameSnapshot) {
        self.snapshot = snapshot
    }
}

/// Standalone entry point for the real-time arcade game. It intentionally has
/// no dependency on the turn-based mini-game wire protocol.
@MainActor
struct VeilVoidSwarmView: View {
    @StateObject private var session = SpaceGameSession()
    @State private var pausedByLifecycle = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(red: 0.008, green: 0.012, blue: 0.045)
                .ignoresSafeArea()

            SpriteView(
                scene: session.scene,
                preferredFramesPerSecond: ArcadeRenderPolicy.preferredFramesPerSecond,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea()
            .accessibilityLabel("虚空蜂群实时战场")

            VStack(spacing: 0) {
                hud
                Spacer()
                controlHint
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if session.isPaused {
                pausePanel
            } else if session.isGameOver {
                gameOverPanel
            }
        }
        .navigationTitle("虚空蜂群")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: session.togglePause) {
                    Image(systemName: session.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .disabled(session.isGameOver)
                .accessibilityLabel(session.isPaused ? "继续游戏" : "暂停游戏")
            }
        }
        .onAppear {
            if pausedByLifecycle {
                pausedByLifecycle = false
                session.resume()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                if pausedByLifecycle {
                    pausedByLifecycle = false
                    session.resume()
                }
            } else if session.snapshot.phase == .playing {
                pausedByLifecycle = true
                session.pause()
            }
        }
        .onDisappear {
            if session.snapshot.phase == .playing { pausedByLifecycle = true }
            session.pause()
        }
    }

    private var hud: some View {
        HStack(spacing: 10) {
            hudBadge(icon: "scope", value: "\(session.snapshot.score)", tint: .cyan)
            hudBadge(icon: "wave.3.right", value: "第 \(session.snapshot.wave) 波", tint: .purple)
            Spacer(minLength: 4)
            healthGauge
        }
        .allowsHitTesting(false)
    }

    private func hudBadge(icon: String, value: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.34), lineWidth: 1))
    }

    private var healthGauge: some View {
        let health = max(0, session.snapshot.player.health)
        let maximum = max(1, session.snapshot.player.maximumHealth)
        return VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(health > maximum * 0.30 ? .mint : .red)
                Text("\(Int(health.rounded()))")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(health > maximum * 0.30 ? Color.mint : Color.red)
                        .frame(width: proxy.size.width * CGFloat(health / maximum))
                }
            }
            .frame(width: 82, height: 5)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var controlHint: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.draw.fill")
            Text("按住并拖动驾驶 · 武器自动锁敌")
        }
        .font(.system(.caption, design: .rounded).weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.25), in: Capsule())
        .allowsHitTesting(false)
    }

    private var pausePanel: some View {
        modalPanel(
            icon: "pause.circle.fill",
            title: "战斗暂停",
            detail: "飞船与整个战场已冻结",
            actionTitle: "继续突围",
            action: session.resume
        )
    }

    private var gameOverPanel: some View {
        modalPanel(
            icon: "sparkles",
            title: "信号熄灭",
            detail: "得分 \(session.snapshot.score) · 抵达第 \(session.snapshot.wave) 波\n最高连击 ×\(session.snapshot.highCombo)",
            actionTitle: "重新出击",
            action: session.restart
        )
    }

    private func modalPanel(
        icon: String,
        title: String,
        detail: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.cyan)
                .shadow(color: .cyan.opacity(0.7), radius: 14)
            Text(title)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
            Text(detail)
                .font(.system(.subheadline, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.68))
            Button(action: action) {
                Text(actionTitle)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.black)
            }
        }
        .padding(24)
        .frame(maxWidth: 310)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.cyan.opacity(0.32), lineWidth: 1)
        )
        .padding(24)
    }
}
