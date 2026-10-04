import SwiftUI
import SpriteKit

@MainActor
final class BlackoutDistrictViewModel: ObservableObject {
    @Published private(set) var snapshot: BlackoutSnapshot
    @Published private(set) var line =
        "调度：暴雨导致多点电压波动。保持街区供电，优先关键节点。"

    let scene: BlackoutDistrictScene
    private var seed: UInt64

    init() {
        seed = Self.seed(
            from: UUID().uuidString
        )

        let scene =
            BlackoutDistrictScene(
                seed: seed
            )

        self.scene = scene
        snapshot = scene.snapshot

        scene.onSnapshot = {
            [weak self] value in

            Task {
                @MainActor
                [weak self] in

                self?.snapshot = value
            }
        }

        scene.onEvent = {
            [weak self] event in

            guard case let .radio(text) =
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

    func drive(
        throttle: Double,
        steering: Double
    ) {
        scene.setDrive(
            throttle: throttle,
            steering: steering
        )
    }

    func stopDriving() {
        scene.setDrive(
            throttle: 0,
            steering: 0
        )
    }

    func setRepairing(
        _ enabled: Bool
    ) {
        scene.setRepairing(
            enabled
        )
    }

    func setReduceMotion(
        _ enabled: Bool
    ) {
        scene.setReduceMotion(
            enabled
        )
    }

    func restart() {
        seed &+=
            0x9E3779B97F4A7C15

        line =
            "调度：新一轮风暴窗口开始。先找到最近的红色故障节点。"

        scene.restart(
            seed: seed
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

struct BlackoutDistrictLabView: View {
    @StateObject private var model =
        BlackoutDistrictViewModel()

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State private var controlOrigin:
        CGPoint?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(
                    scene: model.scene
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    hud
                    Spacer()
                    dispatchCard
                    controls(
                        in: proxy.size
                    )
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
        .onAppear {
            model.setReduceMotion(
                reduceMotion
            )
        }
        .onChange(
            of: reduceMotion
        ) {
            model.setReduceMotion(
                $0
            )
        }
        .navigationTitle(
            "熄灯街区"
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
    }

    private var hud: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                meter(
                    "GRID",
                    model.snapshot.gridStability * 100,
                    .cyan
                )

                meter(
                    "POWER",
                    Double(model.snapshot.poweredNodes) /
                        Double(max(1, model.snapshot.totalNodes)) *
                        100,
                    .blue
                )

                meter(
                    "LIGHTS",
                    Double(model.snapshot.litBuildings) /
                        Double(max(1, model.snapshot.totalBuildings)) *
                        100,
                    .yellow
                )

                meter(
                    "STORM",
                    model.snapshot.storm * 100,
                    .orange
                )
            }

            HStack {
                metric(
                    "FAULT",
                    "\(model.snapshot.activeFaults)"
                )

                metric(
                    "NODE",
                    "\(model.snapshot.poweredNodes)/\(model.snapshot.totalNodes)"
                )

                metric(
                    "BUILD",
                    "\(model.snapshot.litBuildings)/\(model.snapshot.totalBuildings)"
                )

                metric(
                    "TIME",
                    "\(Int(model.snapshot.timeRemaining))s"
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
                Color.cyan.opacity(0.10),
                lineWidth: 0.8
            )
        )
    }

    private var dispatchCard: some View {
        HStack(
            alignment: .top,
            spacing: 9
        ) {
            Image(
                systemName:
                    "bolt.horizontal.circle.fill"
            )
            .font(
                .caption
            )
            .foregroundColor(
                .cyan.opacity(0.88)
            )
            .padding(
                .top,
                2
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
            Color.black.opacity(0.46)
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

    private func controls(
        in size: CGSize
    ) -> some View {
        HStack(spacing: 12) {
            drivePad(
                size: size
            )

            Spacer(
                minLength: 8
            )

            VStack(spacing: 8) {
                Text(
                    model.snapshot.repairTarget == nil
                    ? "靠近红色节点\n低速按住维修"
                    : "正在维修\n\(Int(model.snapshot.repairProgress * 100))%"
                )
                .font(
                    .caption2
                        .weight(
                            .semibold
                        )
                )
                .multilineTextAlignment(
                    .center
                )
                .foregroundColor(
                    .white.opacity(0.70)
                )

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(
                                        0.36
                                    ),
                                    Color.blue.opacity(
                                        0.16
                                    )
                                ],
                                startPoint:
                                    .topLeading,
                                endPoint:
                                    .bottomTrailing
                            )
                        )

                    Circle()
                        .stroke(
                            Color.cyan.opacity(0.58),
                            lineWidth: 1.2
                        )

                    Image(
                        systemName:
                            "wrench.adjustable.fill"
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                    .foregroundColor(
                        .cyan
                    )
                }
                .frame(
                    width: 68,
                    height: 68
                )
                .contentShape(
                    Circle()
                )
                .gesture(
                    DragGesture(
                        minimumDistance: 0
                    )
                    .onChanged { _ in
                        model.setRepairing(
                            true
                        )
                    }
                    .onEnded { _ in
                        model.setRepairing(
                            false
                        )
                    }
                )
                .accessibilityLabel(
                    "按住维修电网节点"
                )
            }
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

    private func drivePad(
        size: CGSize
    ) -> some View {
        ZStack {
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .fill(
                Color.white.opacity(0.04)
            )

            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(0.10),
                lineWidth: 1
            )

            VStack(spacing: 3) {
                Image(
                    systemName:
                        "arrow.up.circle.fill"
                )
                .font(
                    .title2
                )

                Text(
                    "拖动驾驶"
                )
                .font(
                    .caption2.weight(
                        .semibold
                    )
                )

                Image(
                    systemName:
                        "arrow.down.circle"
                )
                .font(
                    .caption
                )
            }
            .foregroundColor(
                .white.opacity(0.54)
            )
        }
        .frame(
            width: min(
                190,
                size.width * 0.48
            ),
            height: 94
        )
        .contentShape(
            Rectangle()
        )
        .gesture(
            DragGesture(
                minimumDistance: 0
            )
            .onChanged { value in
                let origin =
                    controlOrigin ??
                    value.startLocation

                if controlOrigin == nil {
                    controlOrigin =
                        origin
                }

                let dx =
                    value.location.x -
                    origin.x

                let dy =
                    value.location.y -
                    origin.y

                let steering =
                    Double(
                        max(
                            -1,
                            min(
                                1,
                                -dx / 70
                            )
                        )
                    )

                let throttle =
                    Double(
                        max(
                            -1,
                            min(
                                1,
                                -dy / 55
                            )
                        )
                    )

                model.drive(
                    throttle: throttle,
                    steering: steering
                )
            }
            .onEnded { _ in
                controlOrigin = nil
                model.stopDriving()
            }
        )
        .accessibilityLabel(
            "驾驶维修车"
        )
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
                            Color.white.opacity(
                                0.08
                            )
                        )

                    Capsule()
                        .fill(
                            color.opacity(
                                0.84
                            )
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

    private var resultOverlay: some View {
        VStack(spacing: 12) {
            Image(
                systemName:
                    resultIcon
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

            Text(
                resultTitle
            )
            .font(
                .title3.weight(
                    .semibold
                )
            )
            .foregroundColor(
                .white
            )

            Text(
                "\(model.snapshot.litBuildings)/\(model.snapshot.totalBuildings) 栋楼宇仍有灯光"
            )
            .font(
                .caption
                    .monospacedDigit()
            )
            .foregroundColor(
                .white.opacity(0.60)
            )

            Button(
                "重新出车"
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

        case .stabilized:
            return "街区重新亮了"

        case .gridCollapse:
            return "主网失稳"

        case .timeExpired:
            return "维修窗口关闭"
        }
    }

    private var resultIcon: String {
        switch model.snapshot.outcome {
        case .running:
            return "circle"

        case .stabilized:
            return "building.2.crop.circle.fill"

        case .gridCollapse:
            return "bolt.slash.fill"

        case .timeExpired:
            return "clock.fill"
        }
    }

    private var resultColor: Color {
        switch model.snapshot.outcome {
        case .running:
            return .white

        case .stabilized:
            return .cyan

        case .gridCollapse:
            return .red

        case .timeExpired:
            return .orange
        }
    }
}
