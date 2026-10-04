import SwiftUI
import SpriteKit

@MainActor
final class AfterglowConvoyViewModel: ObservableObject {
    @Published private(set) var snapshot: AfterglowConvoySnapshot
    @Published private(set) var storyLine: String

    let scene: AfterglowConvoyScene
    private var seed: UInt64

    init() {
        let seed = Self.seed(from: UUID().uuidString)
        self.seed = seed
        let scene = AfterglowConvoyScene(
            seed: seed,
            renderTier: VeilPerformanceOverrides.forceFullVisualEffects ? .full : .recommended
        )
        self.scene = scene
        snapshot = scene.currentSnapshot
        storyLine = "信标：线路建立。我们走吧。"

        scene.onSnapshot = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.snapshot = snapshot
                if let line = snapshot.storyLine, line != self.storyLine {
                    self.storyLine = line
                }
            }
        }
        scene.onEvent = { [weak self] event in
            guard case let .storyBeat(line) = event.kind else { return }
            Task { @MainActor [weak self] in self?.storyLine = line }
        }
    }

    func steer(_ value: Double) { scene.setVerticalSteering(value) }
    func setShielding(_ active: Bool) { scene.setShielding(active) }
    func configure(reduceMotion: Bool) { scene.setReduceMotion(reduceMotion) }
    func setPaused(_ paused: Bool) { scene.isPaused = paused }

    func restart() {
        seed &+= 0x9E3779B97F4A7C15
        storyLine = "信标：线路建立。我们再试一次。"
        scene.restart(seed: seed)
    }

    private static func seed(from text: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }
}

struct AfterglowConvoyLabView: View {
    @StateObject private var model = AfterglowConvoyViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsGuide = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: model.scene)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(steeringGesture(in: proxy.size))

                VStack(spacing: 0) {
                    hud
                    Spacer()
                    storyCard
                    controls
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)

                if model.snapshot.outcome != .running {
                    resultOverlay
                }
            }
            .background(Color.black)
        }
        .navigationTitle("余烬护航")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showsGuide = true } label: { Image(systemName: "questionmark.circle") }
                    .accessibilityLabel("打开余烬护航教程")
            }
        }
        .sheet(isPresented: $showsGuide) {
            RealtimeGameGuideView(
                title: "余烬护航",
                subtitle: "保护会说话的信标穿过风暴走廊。胜利不只取决于舰体，也取决于信标是否仍有能量。",
                steps: [
                    .init(id: 1, icon: "hand.draw.fill", title: "拖动改变高度", detail: "在画面任意位置上下拖动。护航艇具有惯性，提前回正比猛拉更安全。"),
                    .init(id: 2, icon: "shield.fill", title: "按住护盾", detail: "右下角护盾会同时保护舰体与信标，但会持续消耗护盾能量。风暴最强时再使用。"),
                    .init(id: 3, icon: "flame.fill", title: "回收余烬", detail: "靠近发光余烬缓存可以补充信标与护盾。普通残骸则需要避开。"),
                    .init(id: 4, icon: "sunrise.fill", title: "把光送到终点", detail: "信标归零或舰体损毁都会失败。接近终点时天空会逐渐转暖。")
                ]
            )
        }
        .onAppear {
            model.configure(reduceMotion: reduceMotion)
            model.setPaused(false)
        }
        .onDisappear { model.setPaused(true) }
        .onChange(of: scenePhase) { model.setPaused($0 != .active) }
        .onChange(of: showsGuide) { model.setPaused($0) }
        .onChange(of: reduceMotion) { model.configure(reduceMotion: $0) }
    }

    private var hud: some View {
        HStack(spacing: 8) {
            meter("HULL", model.snapshot.hull, .cyan)
            meter("BEACON", model.snapshot.beacon, .orange)
            meter("SHIELD", model.snapshot.shield, .blue)
            VStack(spacing: 3) {
                Text("DIST").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.46))
                Text("\(Int(model.snapshot.progress * 100))%")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.08), lineWidth: 0.8))
    }

    private var storyCard: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle().fill(beaconColor).frame(width: 8, height: 8)
                .shadow(color: beaconColor.opacity(0.8), radius: 5).padding(.top, 4)
            Text(model.storyLine)
                .font(.caption.weight(.medium))
                .foregroundColor(Color.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(beaconColor.opacity(0.18), lineWidth: 0.8))
        .padding(.bottom, 10)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("拖动画面控制高度").font(.caption2.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.74))
                Text("按住右侧护盾保护信标").font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.43))
            }
            Spacer()
            ZStack {
                Circle().fill(LinearGradient(colors: [Color.cyan.opacity(0.34), Color.blue.opacity(0.16)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().stroke(Color.cyan.opacity(0.56), lineWidth: 1.2)
                Image(systemName: "shield.fill").foregroundColor(Color.cyan.opacity(0.92))
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 64, height: 64)
            .contentShape(Circle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in model.setShielding(true) }
                .onEnded { _ in model.setShielding(false) })
            .accessibilityLabel("护盾")
        }
        .padding(12)
        .background(Color.black.opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var resultOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: resultIcon).font(.system(size: 34, weight: .semibold)).foregroundColor(resultColor)
            Text(resultTitle).font(.title3.weight(.semibold)).foregroundColor(.white)
            Text(resultDetail).font(.caption).multilineTextAlignment(.center)
                .foregroundColor(Color.white.opacity(0.62))
            Button("再护送一次") { model.restart() }
                .font(.caption.weight(.semibold))
                .foregroundColor(Color.black.opacity(0.82))
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(resultColor).clipShape(Capsule())
        }
        .padding(22)
        .frame(maxWidth: 290)
        .background(Color.black.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func meter(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text(title).font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.42))
                Spacer(minLength: 2)
                Text("\(Int(value.rounded()))").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.76))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color.opacity(0.82))
                        .frame(width: g.size.width * CGFloat(max(0, min(1, value / 100))))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func steeringGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged {
                let center = size.height * 0.5
                let normalized = Double((center - $0.location.y) / max(80, size.height * 0.36))
                model.steer(min(1, max(-1, normalized)))
            }
            .onEnded { _ in model.steer(0) }
    }

    private var beaconColor: Color {
        model.snapshot.beacon < 25 ? .red : (model.snapshot.beacon < 55 ? .orange : .yellow)
    }

    private var resultTitle: String {
        switch model.snapshot.outcome {
        case .running: return ""
        case .arrived: return "光送到了"
        case .signalLost: return "信标安静了"
        case .hullLost: return "护航艇失去动力"
        }
    }

    private var resultDetail: String {
        switch model.snapshot.outcome {
        case .running: return ""
        case .arrived: return "远处的接收塔重新亮起。最后一段风暴没有带走这束光。"
        case .signalLost: return "线路中断，但路径已经记录。换一种护盾节奏，再把它带过去。"
        case .hullLost: return "艇体撑不住了。避开碎片，把护盾留给最重的风段。"
        }
    }

    private var resultIcon: String {
        switch model.snapshot.outcome {
        case .running: return "circle"
        case .arrived: return "sun.max.fill"
        case .signalLost: return "waveform"
        case .hullLost: return "wrench.and.screwdriver.fill"
        }
    }

    private var resultColor: Color {
        switch model.snapshot.outcome {
        case .running: return .white
        case .arrived: return .yellow
        case .signalLost: return .orange
        case .hullLost: return .cyan
        }
    }
}
