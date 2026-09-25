import SwiftUI
import Foundation

/// Native motion/physicality layer for VeilLink.
///
/// Design goals:
/// - Make controls feel like objects with depth, inertia and material feedback.
/// - Keep every interaction interruptible and short.
/// - Preserve iPhone 7 / iOS 15 stability by automatically reducing persistent effects.
/// - Avoid Web/JS runtimes; ideas from open-source motion libraries are reimplemented in native SwiftUI.
enum VeilMotionPolicy {
    private static var runtimeConstrained: Bool {
        let process = ProcessInfo.processInfo
        return process.isLowPowerModeEnabled || process.thermalState == .serious || process.thermalState == .critical
    }

    static var allowsFullSpatialEffects: Bool {
        VeilRenderProfile.allowsExpensiveVisualEffects
            && !VeilRenderProfile.usesLegacyCompositorPath
            && !runtimeConstrained
    }

    static var allowsContinuousDecorativeMotion: Bool {
        VeilRenderProfile.allowsPersistentAnimations
            && !VeilRenderProfile.usesLegacyCompositorPath
            && !runtimeConstrained
    }

    static var pressScale: CGFloat {
        allowsFullSpatialEffects ? 0.960 : 0.978
    }

    static var maxTiltDegrees: Double {
        allowsFullSpatialEffects ? 6.0 : 2.2
    }

    static var staggerStep: Double {
        allowsFullSpatialEffects ? 0.036 : 0.018
    }

    static var spring: Animation {
        allowsFullSpatialEffects
            ? .interactiveSpring(response: 0.28, dampingFraction: 0.69, blendDuration: 0.08)
            : .interactiveSpring(response: 0.24, dampingFraction: 0.86, blendDuration: 0.04)
    }
}

private struct VeilMotionSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}

/// Touch-position-aware spatial press effect. The surface tilts toward the finger, receives a
/// local radial specular highlight, compresses to 0.96 on capable hardware, then springs home.
struct VeilSpatialPressModifier: ViewModifier {
    var maximumTilt: Double = VeilMotionPolicy.maxTiltDegrees
    var cornerRadius: CGFloat = 16
    var highlightColor: Color = .white

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var press: DragGesture.Value? = nil
    @State private var measuredSize: CGSize = .zero

    func body(content: Content) -> some View {
        let point = press?.location ?? CGPoint(x: measuredSize.width * 0.5, y: measuredSize.height * 0.5)
        let normalizedX = normalized(point.x, dimension: measuredSize.width)
        let normalizedY = normalized(point.y, dimension: measuredSize.height)
        let dx = (normalizedX - 0.5) * 2
        let dy = (normalizedY - 0.5) * 2
        let magnitude = min(1, abs(dx) + abs(dy))
        let angle = reduceMotion ? 0 : maximumTilt * Double(magnitude)
        let axisX = -dy
        let axisY = dx
        let isPressed = press != nil
        let full = VeilMotionPolicy.allowsFullSpatialEffects && !reduceMotion

        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: VeilMotionSizePreferenceKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(VeilMotionSizePreferenceKey.self) { measuredSize = $0 }
            .scaleEffect(isPressed && !reduceMotion ? VeilMotionPolicy.pressScale : 1)
            .rotation3DEffect(
                .degrees(full && isPressed ? angle : 0),
                axis: (x: axisX, y: axisY, z: 0),
                anchor: .center,
                perspective: full ? 0.72 : 0
            )
            .overlay {
                if full && isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    highlightColor.opacity(0.24),
                                    highlightColor.opacity(0.06),
                                    Color.clear
                                ],
                                center: UnitPoint(x: normalizedX, y: normalizedY),
                                startRadius: 0,
                                endRadius: max(42, max(measuredSize.width, measuredSize.height) * 0.85)
                            )
                        )
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.black.opacity(full ? 0.30 : 0.15), lineWidth: 1.2)
                        .padding(1)
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: Color.black.opacity(full ? (isPressed ? 0.12 : 0.30) : 0),
                radius: full ? (isPressed ? 3 : 13) : 0,
                x: 0,
                y: full ? (isPressed ? 2 : 8) : 0
            )
            .animation(reduceMotion ? nil : VeilMotionPolicy.spring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .updating($press) { value, state, _ in state = value }
            )
    }

    private func normalized(_ value: CGFloat, dimension: CGFloat) -> CGFloat {
        guard dimension > 0 else { return 0.5 }
        return min(1, max(0, value / dimension))
    }
}

/// A physical rocker: one side appears depressed while the opposite side rises. The recess under
/// the rocker changes color so state remains obvious even if motion is reduced.
struct VeilRockerSwitch: View {
    @Binding var isOn: Bool
    var onLabel = "ON"
    var offLabel = "OFF"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : VeilMotionPolicy.spring) {
                isOn.toggle()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? VeilTheme.success.opacity(0.22) : VeilTheme.obsidian.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isOn ? VeilTheme.success.opacity(0.40) : VeilTheme.hairline, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.44), radius: 3, x: 0, y: 2)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: VeilAppearanceController.shared.isInstrument
                                ? [VeilAppearanceController.shared.palette.keycapTop, VeilAppearanceController.shared.palette.keycapBottom]
                                : [VeilTheme.panelSoft, VeilTheme.obsidian],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                    )
                    .padding(3)
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : (isOn ? -7.0 : 7.0)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: isOn ? .bottom : .top,
                        perspective: VeilMotionPolicy.allowsFullSpatialEffects ? 0.82 : 0.35
                    )
                    .shadow(
                        color: Color.black.opacity(0.42),
                        radius: isOn ? 5 : 4,
                        x: 0,
                        y: isOn ? 4 : -1
                    )

                HStack(spacing: 8) {
                    Text(offLabel)
                        .opacity(isOn ? 0.30 : 0.92)
                    Spacer(minLength: 0)
                    Text(onLabel)
                        .foregroundColor(isOn ? VeilTheme.success : VeilTheme.tertiaryText)
                        .opacity(isOn ? 1 : 0.35)
                }
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10)
            }
            .frame(width: 78, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "已开启" : "已关闭")
        .accessibilityAddTraits(.isButton)
    }
}

/// A water-drop-like capsule that expands in place instead of presenting a hard popup. Use this
/// for compact actions that reveal one or two controls without leaving the current visual context.
struct VeilFluidCapsule<Compact: View, Expanded: View>: View {
    @Binding var isExpanded: Bool
    var collapsedWidth: CGFloat
    var expandedWidth: CGFloat
    var height: CGFloat
    private let compact: () -> Compact
    private let expanded: () -> Expanded

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isExpanded: Binding<Bool>,
        collapsedWidth: CGFloat = 48,
        expandedWidth: CGFloat = 220,
        height: CGFloat = 46,
        @ViewBuilder compact: @escaping () -> Compact,
        @ViewBuilder expanded: @escaping () -> Expanded
    ) {
        _isExpanded = isExpanded
        self.collapsedWidth = collapsedWidth
        self.expandedWidth = expandedWidth
        self.height = height
        self.compact = compact
        self.expanded = expanded
    }

    var body: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [VeilTheme.panelSoft, VeilTheme.elevated, VeilTheme.obsidian],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Capsule().stroke(VeilTheme.gold.opacity(isExpanded ? 0.34 : 0.15), lineWidth: 1))
                .shadow(color: VeilTheme.gold.opacity(isExpanded ? 0.14 : 0.04), radius: isExpanded ? 12 : 4)

            if isExpanded {
                expanded()
                    .padding(.horizontal, 13)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                compact()
                    .transition(.opacity.combined(with: .scale(scale: 0.90)))
            }
        }
        .frame(width: isExpanded ? expandedWidth : collapsedWidth, height: height)
        .contentShape(Capsule())
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.34, dampingFraction: 0.76, blendDuration: 0.08)) {
                isExpanded.toggle()
            }
        }
        .animation(reduceMotion ? nil : .interactiveSpring(response: 0.34, dampingFraction: 0.76, blendDuration: 0.08), value: isExpanded)
    }
}

/// Rotating gradient edge plus a diffused back-glow. Continuous rotation is disabled on the
/// legacy compositor; it keeps a static, brightened edge there instead.
struct VeilDynamicGlowBorder: View {
    var active = true
    var emphasized = true
    @State private var rotates = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            baseStroke

            if active {
                Rectangle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Color.clear,
                                VeilTheme.goldDeep.opacity(0.25),
                                VeilTheme.goldBright.opacity(0.95),
                                Color.white.opacity(0.80),
                                VeilTheme.gold.opacity(0.68),
                                Color.clear
                            ],
                            center: .center
                        )
                    )
                    .scaleEffect(1.55)
                    .rotationEffect(.degrees(rotates ? 360 : 0))
                    .mask(glowMask)
                    .opacity(VeilMotionPolicy.allowsContinuousDecorativeMotion && !reduceMotion ? 0.82 : 0.54)
                    .shadow(
                        color: VeilTheme.gold.opacity(VeilMotionPolicy.allowsFullSpatialEffects ? 0.25 : 0.10),
                        radius: VeilMotionPolicy.allowsFullSpatialEffects ? 10 : 4
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { updateRotation() }
        .onDisappear { stopRotation() }
        .onChange(of: active) { _ in updateRotation() }
        .onChange(of: reduceMotion) { _ in updateRotation() }
    }

    @ViewBuilder
    private var baseStroke: some View {
        if VeilAppearanceController.shared.isInstrument {
            RoundedRectangle(cornerRadius: emphasized ? 22 : 18, style: .continuous)
                .stroke(active ? VeilTheme.gold.opacity(0.24) : VeilTheme.hairline, lineWidth: 1)
        } else {
            VeilPanelShape(cut: emphasized ? 18 : 14, radius: 8)
                .stroke(active ? VeilTheme.gold.opacity(0.24) : VeilTheme.hairline, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var glowMask: some View {
        if VeilAppearanceController.shared.isInstrument {
            RoundedRectangle(cornerRadius: emphasized ? 22 : 18, style: .continuous)
                .stroke(lineWidth: emphasized ? 1.7 : 1.2)
        } else {
            VeilPanelShape(cut: emphasized ? 18 : 14, radius: 8)
                .stroke(lineWidth: emphasized ? 1.7 : 1.2)
        }
    }

    private func updateRotation() {
        stopRotation()
        guard active, !reduceMotion, VeilMotionPolicy.allowsContinuousDecorativeMotion else { return }
        DispatchQueue.main.async {
            guard active, !reduceMotion, VeilMotionPolicy.allowsContinuousDecorativeMotion else { return }
            withAnimation(.linear(duration: 5.5).repeatForever(autoreverses: false)) {
                rotates = true
            }
        }
    }

    private func stopRotation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { rotates = false }
    }
}

struct VeilStaggeredEntranceModifier: ViewModifier {
    let index: Int
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 16)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.985, anchor: .bottom)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    let delay = Double(min(max(index, 0), 10)) * VeilMotionPolicy.staggerStep
                    withAnimation(VeilMotionPolicy.spring.delay(delay)) { appeared = true }
                }
            }
    }
}

/// A single mechanical digit. New values enter from below while the old digit rolls upward.
private struct VeilRollingDigit: View {
    let digit: Int
    @State private var previous = 0
    @State private var current = 0
    @State private var phase: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Text(String(previous))
                .offset(y: -phase * 18)
                .opacity(Double(max(0, 1 - phase)))
            Text(String(current))
                .offset(y: (1 - phase) * 18)
                .opacity(Double(min(1, phase)))
        }
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .frame(width: 9, height: 18)
        .clipped()
        .onAppear {
            previous = digit
            current = digit
            phase = 1
        }
        .onChange(of: digit) { value in
            previous = current
            current = value
            phase = reduceMotion ? 1 : 0
            guard !reduceMotion else { return }
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) { phase = 1 }
        }
    }
}

struct VeilOdometerNumber: View {
    let value: Int
    var prefix = ""
    var suffix = ""

    var body: some View {
        HStack(spacing: 0) {
            if !prefix.isEmpty { Text(prefix) }
            let characters = Array(String(value))
            ForEach(characters.indices, id: \.self) { index in
                let character = characters[index]
                if let digit = Int(String(character)) {
                    VeilRollingDigit(digit: digit)
                } else {
                    Text(String(character))
                }
            }
            if !suffix.isEmpty { Text(suffix) }
        }
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .foregroundColor(VeilTheme.text)
    }
}

/// Magnetic data scrubber primitive. Dragging chooses the nearest sample; the cursor springs to the
/// sample instead of following the finger pixel-for-pixel.
struct VeilMagneticScrubber: View {
    let values: [Double]
    @Binding var selectedIndex: Int

    var body: some View {
        GeometryReader { proxy in
            let count = max(values.count, 1)
            let usableWidth = max(proxy.size.width - 18, 1)
            let clampedIndex = min(max(selectedIndex, 0), max(values.count - 1, 0))
            let step = count > 1 ? usableWidth / CGFloat(count - 1) : 0
            let x = 9 + CGFloat(clampedIndex) * step

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 2)
                    .padding(.horizontal, 9)

                if !values.isEmpty {
                    Circle()
                        .fill(VeilTheme.goldBright)
                        .frame(width: 10, height: 10)
                        .shadow(color: VeilTheme.gold.opacity(0.70), radius: 6)
                        .position(x: x, y: proxy.size.height * 0.5)
                        .animation(VeilMotionPolicy.spring, value: clampedIndex)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard values.count > 1 else { return }
                        let raw = (value.location.x - 9) / max(step, 1)
                        let nearest = min(max(Int(raw.rounded()), 0), values.count - 1)
                        if nearest != selectedIndex {
                            selectedIndex = nearest
                        }
                    }
            )
        }
        .frame(height: 30)
    }
}

/// Minimal native equivalent of the path interpolation idea used by morphing icon libraries.
/// Both vector sets must contain the same number of strokes and points.
struct VeilMorphVectorData {
    let strokes: [[CGPoint]]

    static let menu = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.18, y: 0.28), CGPoint(x: 0.82, y: 0.28)],
        [CGPoint(x: 0.18, y: 0.50), CGPoint(x: 0.82, y: 0.50)],
        [CGPoint(x: 0.18, y: 0.72), CGPoint(x: 0.82, y: 0.72)]
    ])

    static let close = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.75)],
        [CGPoint(x: 0.50, y: 0.50), CGPoint(x: 0.50, y: 0.50)],
        [CGPoint(x: 0.75, y: 0.25), CGPoint(x: 0.25, y: 0.75)]
    ])

    static let chevronRight = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.32, y: 0.20), CGPoint(x: 0.68, y: 0.50), CGPoint(x: 0.32, y: 0.80)]
    ])

    static let chevronDown = VeilMorphVectorData(strokes: [
        [CGPoint(x: 0.20, y: 0.34), CGPoint(x: 0.50, y: 0.68), CGPoint(x: 0.80, y: 0.34)]
    ])
}

private struct VeilMorphVectorShape: Shape {
    let from: VeilMorphVectorData
    let to: VeilMorphVectorData
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let strokeCount = min(from.strokes.count, to.strokes.count)

        for strokeIndex in 0..<strokeCount {
            let startStroke = from.strokes[strokeIndex]
            let endStroke = to.strokes[strokeIndex]
            let pointCount = min(startStroke.count, endStroke.count)
            guard pointCount > 0 else { continue }

            let first = interpolate(startStroke[0], endStroke[0], in: rect)
            path.move(to: first)
            if pointCount > 1 {
                for pointIndex in 1..<pointCount {
                    path.addLine(to: interpolate(startStroke[pointIndex], endStroke[pointIndex], in: rect))
                }
            }
        }
        return path
    }

    private func interpolate(_ a: CGPoint, _ b: CGPoint, in rect: CGRect) -> CGPoint {
        let p = min(max(progress, 0), 1)
        let x = a.x + (b.x - a.x) * p
        let y = a.y + (b.y - a.y) * p
        return CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
    }
}

struct VeilMorphIcon: View {
    let from: VeilMorphVectorData
    let to: VeilMorphVectorData
    let toggled: Bool
    var size: CGFloat = 22
    var color: Color = VeilTheme.goldBright
    var lineWidth: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VeilMorphVectorShape(from: from, to: to, progress: toggled ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .animation(reduceMotion ? nil : VeilMotionPolicy.spring, value: toggled)
            .accessibilityHidden(true)
    }
}

/// Compact/expanded states occupy the same hierarchy and share one geometry identity, preventing
/// the white-flash / push-screen feeling of a hard modal for small detail reveals.
struct VeilSharedExpansionContainer<Compact: View, Expanded: View>: View {
    @Binding var isExpanded: Bool
    private let compact: () -> Compact
    private let expanded: () -> Expanded
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isExpanded: Binding<Bool>,
        @ViewBuilder compact: @escaping () -> Compact,
        @ViewBuilder expanded: @escaping () -> Expanded
    ) {
        _isExpanded = isExpanded
        self.compact = compact
        self.expanded = expanded
    }

    var body: some View {
        ZStack {
            if isExpanded {
                expanded()
                    .matchedGeometryEffect(id: "veil.shared.surface", in: namespace)
                    .transition(.opacity)
            } else {
                compact()
                    .matchedGeometryEffect(id: "veil.shared.surface", in: namespace)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .interactiveSpring(response: 0.40, dampingFraction: 0.82, blendDuration: 0.10), value: isExpanded)
    }
}

/// Bottom drawer with rubber-band overscroll and velocity-aware snapping. It is intentionally a
/// standalone primitive so screens can migrate away from hard sheets without rewriting content.
struct VeilElasticDrawer<Content: View>: View {
    @Binding var isPresented: Bool
    let snapFractions: [CGFloat]
    private let content: () -> Content

    @State private var settledFraction: CGFloat
    @GestureState private var dragTranslation: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isPresented: Binding<Bool>,
        snapFractions: [CGFloat] = [0.42, 0.78],
        initialFraction: CGFloat = 0.42,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _isPresented = isPresented
        self.snapFractions = snapFractions.sorted()
        _settledFraction = State(initialValue: initialFraction)
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let minimum = snapFractions.first ?? 0.42
            let maximum = snapFractions.last ?? 0.78
            let baseVisible = proxy.size.height * settledFraction
            let proposedVisible = baseVisible - dragTranslation
            let clampedVisible = rubberBand(
                proposedVisible,
                lower: proxy.size.height * minimum,
                upper: proxy.size.height * maximum
            )
            let offset = isPresented ? max(0, proxy.size.height - clampedVisible) : proxy.size.height + 24

            VStack(spacing: 0) {
                Capsule()
                    .fill(VeilTheme.secondaryText.opacity(0.55))
                    .frame(width: 42, height: 5)
                    .padding(.top, 9)
                    .padding(.bottom, 10)
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: proxy.size.width, height: proxy.size.height * maximum, alignment: .top)
            .background(VeilTheme.panel.opacity(0.985))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(VeilTheme.hairline, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.42), radius: 24, x: 0, y: -6)
            .offset(y: offset)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($dragTranslation) { value, state, _ in state = value.translation.height }
                    .onEnded { value in
                        let projectedVisible = baseVisible - value.predictedEndTranslation.height
                        let target = nearestFraction(to: projectedVisible / max(proxy.size.height, 1))
                        if value.predictedEndTranslation.height > proxy.size.height * 0.28, settledFraction <= minimum + 0.02 {
                            withAnimation(reduceMotion ? nil : VeilMotionPolicy.spring) { isPresented = false }
                        } else {
                            withAnimation(reduceMotion ? nil : VeilMotionPolicy.spring) { settledFraction = target }
                        }
                    }
            )
            .animation(reduceMotion ? nil : VeilMotionPolicy.spring, value: isPresented)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func nearestFraction(to value: CGFloat) -> CGFloat {
        guard let first = snapFractions.first else { return 0.42 }
        return snapFractions.min(by: { abs($0 - value) < abs($1 - value) }) ?? first
    }

    private func rubberBand(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        if value < lower { return lower - (lower - value) * 0.22 }
        if value > upper { return upper + (value - upper) * 0.22 }
        return value
    }
}

extension View {
    func veilSpatialPress(
        maximumTilt: Double = VeilMotionPolicy.maxTiltDegrees,
        cornerRadius: CGFloat = 16,
        highlightColor: Color = .white
    ) -> some View {
        modifier(VeilSpatialPressModifier(maximumTilt: maximumTilt, cornerRadius: cornerRadius, highlightColor: highlightColor))
    }

    func veilStaggeredEntrance(index: Int) -> some View {
        modifier(VeilStaggeredEntranceModifier(index: index))
    }

    func veilDynamicGlow(active: Bool = true, emphasized: Bool = true) -> some View {
        overlay(VeilDynamicGlowBorder(active: active, emphasized: emphasized))
    }
}
