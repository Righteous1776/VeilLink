import SwiftUI
import SpriteKit

@MainActor
final class RainlineViewModel: ObservableObject {
    @Published private(set) var snapshot: RainlineSnapshot
    @Published private(set) var line = "广播：雨线已经压到高架桥。末班车不停站。"

    let scene: RainlineLastTrainScene
    private var seed: UInt64

    init() {
        seed = Self.seed(from: UUID().uuidString)
        let scene = RainlineLastTrainScene(seed: seed)
        self.scene = scene
        snapshot = scene.snapshot

        scene.onSnapshot = { [weak self] value in
            Task { @MainActor [weak self] in
                guard let self else { return }
                snapshot = value
                if let active = value.activeLine, active != line {
                    line = active
                }
            }
        }
    }

    func move(_ value: Double) { scene.setMove(value) }
    func repair(_ active: Bool) { scene.setRepairing(active) }
    func boost(_ active: Bool) { scene.setGridBoost(active) }

    func restart() {
        seed &+= 0x9E3779B97F4A7C15
        line = "广播：雨线重启。把八节车厢带到终点。"
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

struct RainlineLastTrainLabView: View {
    @StateObject private var model = RainlineViewModel()

    var body: some View {
        ZStack {
            SpriteView(scene: model.scene)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                hud
                Spacer()
                lineCard
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
        .navigationTitle("雨线末班车")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hud: some View {
        HStack(spacing: 8) {
            meter("GRID", model.snapshot.trainPower, .yellow)
            meter("DRIVE", model.snapshot.traction, .cyan)
            metric("LIGHT", "\\(model.snapshot.litCars)/8")
            metric("FAULT", "\\(model.snapshot.activeFaults)")
            metric("ROUTE", "\\(Int(model.snapshot.progress * 100))%")
        }
        .padding(10)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    private var lineCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "tram.fill")
                .foregroundColor(.yellow.opacity(0.85))
            Text(model.line)
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.87))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color.black.opacity(0.46))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 9)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                controlButton("向前", icon: "arrow.right") {
                    model.move(1)
                } end: {
                    model.move(0)
                }

                controlButton("向后", icon: "arrow.left") {
                    model.move(-1)
                } end: {
                    model.move(0)
                }
            }

            HStack(spacing: 10) {
                controlButton(
                    "按住抢修",
                    icon: "wrench.and.screwdriver.fill",
                    accent: .orange
                ) {
                    model.repair(true)
                } end: {
                    model.repair(false)
                }

                controlButton(
                    "电网超载",
                    icon: "bolt.fill",
                    accent: .cyan
                ) {
                    model.boost(true)
                } end: {
                    model.boost(false)
                }
            }

            HStack {
                Text("当前位置：第 \\(model.snapshot.playerCar + 1) 节")
                Spacer()
                Text("已修复 \\(model.snapshot.repairedFaults)")
            }
            .font(.caption2.monospacedDigit())
            .foregroundColor(.white.opacity(0.48))
        }
        .padding(12)
        .background(Color.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func controlButton(
        _ title: String,
        icon: String,
        accent: Color = .white,
        began: @escaping () -> Void,
        end: @escaping () -> Void
    ) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white.opacity(0.90))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(accent.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.34), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in began() }
                    .onEnded { _ in end() }
            )
    }

    private func meter(
        _ title: String,
        _ value: Double,
        _ color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.42))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(color.opacity(0.84))
                        .frame(
                            width: geometry.size.width *
                                CGFloat(max(0, min(1, value / 100)))
                        )
                }
            }
            .frame(height: 4)

            Text("\\(Int(value.rounded()))")
                .font(.caption2.bold().monospacedDigit())
                .foregroundColor(.white.opacity(0.76))
        }
        .frame(maxWidth: .infinity)
    }

    private func metric(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.42))

            Text(value)
                .font(.caption.bold().monospacedDigit())
                .foregroundColor(.white.opacity(0.80))
        }
        .frame(maxWidth: .infinity)
    }

    private var resultOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: resultIcon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(resultColor)

            Text(resultTitle)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)

            Text("亮灯车厢 \\(model.snapshot.litCars)/8 · 修复 \\(model.snapshot.repairedFaults) 次")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.60))

            Button("再发一班") {
                model.restart()
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(.black.opacity(0.82))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(resultColor)
            .clipShape(Capsule())
        }
        .padding(22)
        .frame(maxWidth: 300)
        .background(Color.black.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var resultTitle: String {
        switch model.snapshot.outcome {
        case .running:
            return ""
        case .arrived:
            return "末班车到站"
        case .blackout:
            return "全车断电"
        case .stalled:
            return "列车停在雨里"
        }
    }

    private var resultIcon: String {
        switch model.snapshot.outcome {
        case .running:
            return "circle"
        case .arrived:
            return "tram.circle.fill"
        case .blackout:
            return "lightbulb.slash.fill"
        case .stalled:
            return "exclamationmark.triangle.fill"
        }
    }

    private var resultColor: Color {
        switch model.snapshot.outcome {
        case .running:
            return .white
        case .arrived:
            return .yellow
        case .blackout:
            return .orange
        case .stalled:
            return .cyan
        }
    }
}
