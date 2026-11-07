import SwiftUI
import SpriteKit

@MainActor
final class AshHarborViewModel: ObservableObject {
    @Published private(set) var snapshot: AshHarborSnapshot
    @Published private(set) var radioLine = "港务台：灰港东侧全部断电。灯塔线还有四组求救信号。"

    let scene: AshHarborScene
    private var seed: UInt64

    init() {
        let seed = Self.seed(from: UUID().uuidString)
        self.seed = seed

        let scene = AshHarborScene(seed: seed)
        self.scene = scene
        self.snapshot = scene.snapshot

        scene.onSnapshot = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.snapshot = snapshot
            }
        }

        scene.onEvent = { [weak self] event in
            switch event.kind {
            case let .radio(line), let .rescueCompleted(_, line):
                Task { @MainActor [weak self] in
                    self?.radioLine = line
                }

            case .reachedHarbor:
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.radioLine = self.snapshot.rescued == self.snapshot.totalRescues
                        ? "灯塔：四组信号都回来了。今晚灰港不是全黑。"
                        : "灯塔：你到了。还有信号留在风里。"
                }

            case .hullLost:
                Task { @MainActor [weak self] in
                    self?.radioLine = "港务台：失去你的应答。航迹最后位置已记录。"
                }

            case .timeExpired:
                Task { @MainActor [weak self] in
                    self?.radioLine = "灯塔：风墙封港。线路暂时关了。"
                }

            default:
                break
            }
        }
    }

    func setThrottle(_ value: Double) {
        scene.setThrottle(value)
    }

    func setRudder(_ value: Double) {
        scene.setRudder(value)
    }

    func setRescuing(_ active: Bool) {
        scene.setRescuing(active)
    }

    func setSearchlight(_ active: Bool) {
        scene.setSearchlight(active)
    }

    func setReduceMotion(_ enabled: Bool) {
        scene.setReduceMotion(enabled)
    }

    func restart() {
        seed &+= 0x9E3779B97F4A7C15
        radioLine = "港务台：灯塔线重开。风还在，慢一点靠近求救点。"
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

struct AshHarborLabView: View {
    @StateObject private var model = AshHarborViewModel()
    @State private var throttle = 0.58
    @State private var searchlight = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: model.scene)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(rudderGesture(in: proxy.size))

                VStack(spacing: 0) {
                    hud
                    Spacer()
                    radioCard
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
        .navigationTitle("灰港")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.setThrottle(throttle)
            model.setSearchlight(searchlight)
            model.setReduceMotion(reduceMotion)
        }
        .onChange(of: reduceMotion) {
            model.setReduceMotion($0)
        }
    }

    private var hud: some View {
        HStack(spacing: 8) {
            meter("HULL", model.snapshot.hull, .cyan)
            meter("LIGHT", model.snapshot.battery, .yellow)
            meter(
                "RESCUE",
                Double(model.snapshot.rescued) /
                    Double(max(1, model.snapshot.totalRescues)) * 100,
                .orange
            )

            VStack(spacing: 3) {
                Text("TIME")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.42))

                Text("\(Int(model.snapshot.timeRemaining))")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundColor(.white)

                Text("sec")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    private var radioCard: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.caption)
                .foregroundColor(.orange.opacity(0.88))
                .padding(.top, 2)

            Text(model.radioLine)
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color.black.opacity(0.44))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.bottom, 9)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("油门")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))

                Slider(value: $throttle, in: 0...1, step: 0.02)
                    .tint(.cyan)
                    .onChange(of: throttle) {
                        model.setThrottle($0)
                    }

                Text("\(Int(throttle * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.white.opacity(0.62))
                    .frame(width: 36)
            }

            HStack(spacing: 12) {
                Button {
                    searchlight.toggle()
                    model.setSearchlight(searchlight)
                } label: {
                    Label(
                        searchlight ? "探照灯 ON" : "探照灯 OFF",
                        systemImage: searchlight ? "flashlight.on.fill" : "flashlight.off.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    HarborButtonStyle(accent: searchlight ? .yellow : .gray)
                )

                Text("按住救援")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.black.opacity(0.78))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                model.setRescuing(true)
                            }
                            .onEnded { _ in
                                model.setRescuing(false)
                            }
                    )
            }

            if model.snapshot.activeRescueID != nil {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))

                        Capsule()
                            .fill(Color.orange.opacity(0.88))
                            .frame(
                                width: geometry.size.width *
                                    CGFloat(model.snapshot.rescueProgress)
                            )
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var resultOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: resultIcon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(resultColor)

            Text(resultTitle)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)

            Text("救回 \(model.snapshot.rescued)/\(model.snapshot.totalRescues) 组信号")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.60))

            Button("重新出港") {
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
        .frame(maxWidth: 290)
        .background(Color.black.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func rudderGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = size.height * 0.55
                let normalized = Double(
                    (center - value.location.y) /
                    max(90, size.height * 0.30)
                )
                model.setRudder(min(1, max(-1, normalized)))
            }
            .onEnded { _ in
                model.setRudder(0)
            }
    }

    private func meter(
        _ title: String,
        _ value: Double,
        _ color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.42))

                Spacer(minLength: 2)

                Text("\(Int(value.rounded()))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.76))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(color.opacity(0.82))
                        .frame(
                            width: geometry.size.width *
                                CGFloat(max(0, min(1, value / 100)))
                        )
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultTitle: String {
        switch model.snapshot.outcome {
        case .running:
            return ""
        case .reachedHarbor:
            return "灯塔线重新亮了"
        case .hullLost:
            return "灰港吞没了航迹"
        case .timeExpired:
            return "风墙封港"
        }
    }

    private var resultIcon: String {
        switch model.snapshot.outcome {
        case .running:
            return "circle"
        case .reachedHarbor:
            return "light.beacon.max.fill"
        case .hullLost:
            return "water.waves"
        case .timeExpired:
            return "clock.fill"
        }
    }

    private var resultColor: Color {
        switch model.snapshot.outcome {
        case .running:
            return .white
        case .reachedHarbor:
            return .yellow
        case .hullLost:
            return .cyan
        case .timeExpired:
            return .orange
        }
    }
}

private struct HarborButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundColor(.white.opacity(0.90))
            .padding(.vertical, 12)
            .background(
                accent.opacity(configuration.isPressed ? 0.25 : 0.16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.46), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
