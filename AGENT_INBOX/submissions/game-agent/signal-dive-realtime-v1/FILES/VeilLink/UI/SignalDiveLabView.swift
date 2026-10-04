import SwiftUI
import SpriteKit

@MainActor
final class SignalDiveViewModel: ObservableObject {
    @Published private(set) var snapshot: SignalDiveSnapshot
    @Published private(set) var line =
        "控制台：四个失联信标。下潜，找到它们，再回来。"
    @Published private(set) var floodlight = true

    let scene: SignalDiveScene
    private var seed: UInt64

    init() {
        seed = Self.seed(
            from: UUID().uuidString
        )

        let scene =
            SignalDiveScene(
                seed: seed
            )

        self.scene = scene
        snapshot = scene.snapshot

        scene.onSnapshot = {
            [weak self] value in
            Task {
                @MainActor
                [weak self] in

                guard let self else {
                    return
                }

                snapshot = value

                if let active =
                        value.lastLine,
                   active != line {
                    line = active
                }
            }
        }

        scene.onEvent = {
            [weak self] event in

            guard case let
                    .radio(text) =
                    event.kind else {
                return
            }

            Task {
                @MainActor
                [weak self] in

                self?.line = text
            }
        }
    }

    func thrust(
        x: Double,
        y: Double
    ) {
        scene.setThrust(
            x: x,
            y: y
        )
    }

    func stopThrust() {
        scene.setThrust(
            x: 0,
            y: 0
        )
    }

    func sonar() {
        guard snapshot.sonarCooldown <= 0,
              snapshot.power >= 1.8 else {
            return
        }

        scene.triggerSonar()
        line = "声呐：脉冲已发出。"
    }

    func toggleFloodlight() {
        floodlight.toggle()

        scene.setFloodlight(
            floodlight
        )
    }

    func restart() {
        seed &+=
            0x9E3779B97F4A7C15

        floodlight = true

        line =
            "控制台：下潜线路重置。深处只相信声呐和你自己的灯。"

        scene.restart(
            seed: seed
        )

        scene.setFloodlight(
            true
        )
    }

    private static func seed(
        from text: String
    ) -> UInt64 {
        var hash: UInt64 =
            1469598103934665603

        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }

        return hash
    }
}

struct SignalDiveLabView: View {
    @StateObject private var model =
        SignalDiveViewModel()

    @State private var controlOrigin:
        CGPoint?

    @State private var controlVector =
        CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(
                    scene: model.scene
                )
                .ignoresSafeArea()
                .contentShape(
                    Rectangle()
                )
                .gesture(
                    thrustGesture(
                        in: proxy.size
                    )
                )

                VStack(spacing: 0) {
                    hud
                    Spacer()
                    signalCard
                    controls
                }
                .padding(
                    .horizontal,
                    14
                )
                .padding(
                    .top,
                    10
                )
                .padding(
                    .bottom,
                    14
                )

                if model.snapshot.outcome
                    != .running {
                    resultOverlay
                }
            }
            .background(
                Color.black
            )
        }
        .navigationTitle(
            "深潜信号"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    private var hud: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                meter(
                    "HULL",
                    model.snapshot.hull,
                    .cyan
                )

                meter(
                    "POWER",
                    model.snapshot.power,
                    .yellow
                )

                meter(
                    "PRESS",
                    min(
                        100,
                        model.snapshot.pressure /
                        1.15 * 100
                    ),
                    .blue
                )

                meter(
                    "NOISE",
                    model.snapshot.noise * 100,
                    .orange
                )
            }

            HStack {
                metric(
                    "DEPTH",
                    "\(Int(model.snapshot.depth))m"
                )

                metric(
                    "SIGNAL",
                    "\(model.snapshot.recovered)/\(model.snapshot.totalBeacons)"
                )

                metric(
                    "SONAR",
                    sonarText
                )

                metric(
                    "X",
                    "\(Int(model.snapshot.x))"
                )
            }
        }
        .padding(10)
        .background(
            Color.black.opacity(0.38)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
            .stroke(
                Color.cyan.opacity(0.11),
                lineWidth: 0.8
            )
        )
    }

    private var signalCard: some View {
        HStack(
            alignment: .top,
            spacing: 9
        ) {
            Circle()
                .fill(
                    Color.cyan.opacity(0.82)
                )
                .frame(
                    width: 7,
                    height: 7
                )
                .shadow(
                    color:
                        .cyan.opacity(0.8),
                    radius: 5
                )
                .padding(
                    .top,
                    4
                )

            Text(model.line)
                .font(
                    .caption.weight(
                        .medium
                    )
                )
                .foregroundColor(
                    .white.opacity(0.86)
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Spacer(
                minLength: 0
            )
        }
        .padding(11)
        .background(
            Color.black.opacity(0.50)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
        .padding(
            .bottom,
            9
        )
    }

    private var controls: some View {
        HStack(spacing: 12) {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(
                    "拖动画面控制推进方向"
                )
                .font(
                    .caption2.weight(
                        .semibold
                    )
                )
                .foregroundColor(
                    .white.opacity(0.72)
                )

                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            Color.cyan.opacity(0.85)
                        )
                        .frame(
                            width: 6,
                            height: 6
                        )

                    Text(
                        "越深，压力越高；声呐会增加扰动。"
                    )
                    .font(
                        .system(
                            size: 10
                        )
                    )
                    .foregroundColor(
                        .white.opacity(0.43)
                    )
                }
            }

            Spacer(
                minLength: 6
            )

            Button {
                model.toggleFloodlight()
            } label: {
                Image(
                    systemName:
                        model.floodlight
                        ? "flashlight.on.fill"
                        : "flashlight.off.fill"
                )
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundColor(
                    model.floodlight
                    ? .cyan
                    : .gray
                )
                .frame(
                    width: 52,
                    height: 52
                )
                .background(
                    Color.black.opacity(0.38)
                )
                .clipShape(
                    Circle()
                )
                .overlay(
                    Circle()
                        .stroke(
                            (
                                model.floodlight
                                ? Color.cyan
                                : Color.gray
                            )
                            .opacity(0.42),
                            lineWidth: 1
                        )
                )
            }
            .accessibilityLabel(
                model.floodlight
                ? "关闭探照灯"
                : "打开探照灯"
            )

            Button {
                model.sonar()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(
                                        0.32
                                    ),
                                    Color.blue.opacity(
                                        0.15
                                    )
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Circle()
                        .stroke(
                            Color.cyan.opacity(0.62),
                            lineWidth: 1.2
                        )

                    Image(
                        systemName:
                            "dot.radiowaves.left.and.right"
                    )
                    .font(
                        .system(
                            size: 19,
                            weight: .semibold
                        )
                    )
                    .foregroundColor(
                        .cyan
                    )
                }
                .frame(
                    width: 62,
                    height: 62
                )
                .opacity(
                    model.snapshot.sonarCooldown > 0
                    ? 0.42
                    : 1
                )
            }
            .disabled(
                model.snapshot.sonarCooldown > 0 ||
                model.snapshot.power < 1.8
            )
            .accessibilityLabel(
                "发送声呐脉冲"
            )
        }
        .padding(12)
        .background(
            Color.black.opacity(0.42)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
    }

    private func thrustGesture(
        in size: CGSize
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 0
        )
        .onChanged { value in
            let origin =
                controlOrigin ??
                value.startLocation

            if controlOrigin == nil {
                controlOrigin = origin
            }

            let dx =
                value.location.x -
                origin.x

            let dy =
                value.location.y -
                origin.y

            let radius =
                max(
                    72,
                    min(
                        size.width,
                        size.height
                    ) * 0.18
                )

            let x =
                Double(
                    max(
                        -1,
                        min(
                            1,
                            dx / radius
                        )
                    )
                )

            let y =
                Double(
                    max(
                        -1,
                        min(
                            1,
                            dy / radius
                        )
                    )
                )

            controlVector =
                CGSize(
                    width: x,
                    height: y
                )

            model.thrust(
                x: x,
                y: y
            )
        }
        .onEnded { _ in
            controlOrigin = nil
            controlVector = .zero
            model.stopThrust()
        }
    }

    private func meter(
        _ title: String,
        _ value: Double,
        _ color: Color
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            Text(title)
                .font(
                    .system(
                        size: 8,
                        weight: .bold,
                        design: .monospaced
                    )
                )
                .foregroundColor(
                    .white.opacity(0.42)
                )

            GeometryReader {
                geometry in

                ZStack(
                    alignment: .leading
                ) {
                    Capsule()
                        .fill(
                            Color.white.opacity(0.08)
                        )

                    Capsule()
                        .fill(
                            color.opacity(0.84)
                        )
                        .frame(
                            width:
                                geometry.size.width *
                                CGFloat(
                                    max(
                                        0,
                                        min(
                                            1,
                                            value / 100
                                        )
                                    )
                                )
                        )
                }
            }
            .frame(
                height: 4
            )

            Text(
                "\(Int(value.rounded()))"
            )
            .font(
                .caption2
                    .bold()
                    .monospacedDigit()
            )
            .foregroundColor(
                .white.opacity(0.76)
            )
        }
        .frame(
            maxWidth: .infinity
        )
    }

    private func metric(
        _ title: String,
        _ value: String
    ) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(
                    .system(
                        size: 8,
                        weight: .bold,
                        design: .monospaced
                    )
                )
                .foregroundColor(
                    .white.opacity(0.40)
                )

            Text(value)
                .font(
                    .caption2
                        .bold()
                        .monospacedDigit()
                )
                .foregroundColor(
                    .white.opacity(0.80)
                )
        }
        .frame(
            maxWidth: .infinity
        )
    }

    private var sonarText: String {
        model.snapshot.sonarCooldown <= 0
        ? "READY"
        : String(
            format: "%.1fs",
            model.snapshot.sonarCooldown
        )
    }

    private var resultOverlay: some View {
        VStack(spacing: 12) {
            Image(
                systemName: resultIcon
            )
            .font(
                .system(
                    size: 34,
                    weight: .semibold
                )
            )
            .foregroundColor(
                resultColor
            )

            Text(resultTitle)
                .font(
                    .title3.weight(
                        .semibold
                    )
                )
                .foregroundColor(
                    .white
                )

            Text(
                "回收 \(model.snapshot.recovered)/\(model.snapshot.totalBeacons) 个失联信标"
            )
            .font(
                .caption
                    .monospacedDigit()
            )
            .foregroundColor(
                .white.opacity(0.60)
            )

            Button(
                "再次下潜"
            ) {
                model.restart()
            }
            .font(
                .caption.weight(
                    .semibold
                )
            )
            .foregroundColor(
                .black.opacity(0.82)
            )
            .padding(
                .horizontal,
                18
            )
            .padding(
                .vertical,
                10
            )
            .background(
                resultColor
            )
            .clipShape(
                Capsule()
            )
        }
        .padding(22)
        .frame(
            maxWidth: 300
        )
        .background(
            Color.black.opacity(0.87)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
    }

    private var resultTitle: String {
        switch model.snapshot.outcome {
        case .running:
            return ""

        case .surfaced:
            return "信号回到水面"

        case .hullFailure:
            return "艇体失压"

        case .powerLoss:
            return "深海断电"
        }
    }

    private var resultIcon: String {
        switch model.snapshot.outcome {
        case .running:
            return "circle"

        case .surfaced:
            return "sun.horizon.fill"

        case .hullFailure:
            return "water.waves"

        case .powerLoss:
            return "battery.0"
        }
    }

    private var resultColor: Color {
        switch model.snapshot.outcome {
        case .running:
            return .white

        case .surfaced:
            return .cyan

        case .hullFailure:
            return .orange

        case .powerLoss:
            return .blue
        }
    }
}
