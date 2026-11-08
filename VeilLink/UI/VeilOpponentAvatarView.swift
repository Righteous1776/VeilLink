import Foundation
import SwiftUI
import ImageIO
import UIKit
import AVFoundation

/// Original VeilLink liquid-form character. Developed independently from
/// concepts such as organic contours, eye expressions and spring motion.
/// No extracted vectors, source modules, tables or binary art are embedded.
enum VeilOpponentAvatarMood: Equatable {
    case idle, thinking, won, lost, draw

    var label: String {
        switch self {
        case .idle: return "等待落子"
        case .thinking: return "正在思考"
        case .won: return "电脑获胜"
        case .lost: return "电脑落败"
        case .draw: return "和局"
        }
    }
}

enum VeilOpponentAvatarPolicy {
    static let preferenceKey = "owner.grokbot.original.enabled.v1"

    static func shouldRender(enabled: Bool, hasComputerOpponent: Bool) -> Bool {
        enabled && hasComputerOpponent
    }

    static func frameInterval(lowPower: Bool) -> TimeInterval {
        lowPower ? 1.0 / 15.0 : 1.0 / 30.0
    }

    /// Adaptive continuous corners for the square Owner-supplied MP4.
    /// 76pt avatar = 22.8pt corner; iPhone 7 smaller cards scale down.
    static func videoCornerRadius(for side: CGFloat) -> CGFloat {
        min(26, max(0, side * 0.30))
    }

    static func shouldAnimate(reduceMotion: Bool, sceneIsActive: Bool) -> Bool {
        !reduceMotion && sceneIsActive
    }

    /// Bounded damped response; avoids non-finite transform values.
    static func rebound(elapsed: Double) -> Double {
        let t = max(0, min(3, elapsed))
        return exp(-3.7 * t) * sin(t * 16)
    }
}

/// A mathematically authored closed blob. The radial harmonics evolve at
/// different frequencies rather than interpolating any proprietary vertex
/// table. 32 smooth quadratic segments keep it cheap on older iPhones.
private struct VeilLiquidContour: Shape {
    let time: Double
    let mood: VeilOpponentAvatarMood
    let motionAllowed: Bool

    func path(in rect: CGRect) -> Path {
        let count = 32
        let phase = motionAllowed ? time : 0
        let wave = mood == .thinking ? 0.062 : 0.027
        let halfW = rect.width * 0.48
        let halfH = rect.height * 0.47
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var points: [CGPoint] = []
        points.reserveCapacity(count)

        for i in 0..<count {
            let angle = Double(i) * 2 * Double.pi / Double(count)
            let triple = sin(angle * 3.0 + phase * 1.7) * wave
            let quint = cos(angle * 5.0 - phase * 0.92) * 0.023
            let uneven = sin(angle * 2.0 + 0.8) * 0.028
            let radius = 0.90 + triple + quint + uneven
            let floating = motionAllowed ? sin(phase * 1.8) * 1.3 : 0
            points.append(CGPoint(
                x: center.x + cos(angle) * halfW * radius,
                y: center.y + sin(angle) * halfH * radius + floating
            ))
        }

        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
        }

        var outline = Path()
        outline.move(to: midpoint(points[count - 1], points[0]))
        for i in 0..<count {
            outline.addQuadCurve(
                to: midpoint(points[i], points[(i + 1) % count]),
                control: points[i]
            )
        }
        outline.closeSubpath()
        return outline
    }
}

/// Native SwiftUI Canvas + TimelineView. It is not a WebView or a downloaded
/// animation, and cannot intercept any touch on the actual board.
struct VeilOpponentAvatarView: View {
    let mood: VeilOpponentAvatarMood
    let size: CGFloat
    /// Prevents video/GIF decoding and timer-driven animation on legacy devices.
    /// Other Grok Bot avatar consumers keep their original animation defaults.
    let staticOnly: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var changedAt = Date()

    init(mood: VeilOpponentAvatarMood, size: CGFloat = 76, staticOnly: Bool = false) {
        self.mood = mood
        self.size = size
        self.staticOnly = staticOnly
    }

    var body: some View {
        let animated = !staticOnly && VeilOpponentAvatarPolicy.shouldAnimate(
            reduceMotion: reduceMotion, sceneIsActive: scenePhase == .active
        )
        Group {
            if !staticOnly && Bundle.main.url(forResource: "GrokBotFull", withExtension: "mp4") != nil {
                VeilGrokBotFullVideoPlayer(
                    running: animated,
                    cornerRadius: VeilOpponentAvatarPolicy.videoCornerRadius(for: size)
                )
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(
                    cornerRadius: VeilOpponentAvatarPolicy.videoCornerRadius(for: size),
                    style: .continuous
                ))
                .overlay(
                    RoundedRectangle(
                        cornerRadius: VeilOpponentAvatarPolicy.videoCornerRadius(for: size),
                        style: .continuous
                    )
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                )
                .accessibilityIdentifier("game.grok_bot.rounded_video")
            } else if !staticOnly && Bundle.main.url(forResource: "GrokBotLoop", withExtension: "gif") != nil {
                VeilGrokBotGIFPlayer(running: animated)
            } else {
                TimelineView(.animation(
                    minimumInterval: VeilOpponentAvatarPolicy.frameInterval(
                        lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled
                    ),
                    paused: !animated
                )) { timeline in
                    Canvas(opaque: false, rendersAsynchronously: false) { context, bounds in
                        render(
                            in: context, size: bounds,
                            time: timeline.date.timeIntervalSinceReferenceDate,
                            reactionAge: max(0, timeline.date.timeIntervalSince(changedAt)),
                            animated: animated
                        )
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .onChange(of: mood) { _ in changedAt = Date() }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grok bot 对手形象：\(mood.label)")
    }

    private func render(
        in source: GraphicsContext, size: CGSize, time: Double,
        reactionAge: Double, animated: Bool
    ) {
        var ctx = source
        let width = size.width
        let height = size.height
        let unit = min(width, height)
        let rebound = animated ? VeilOpponentAvatarPolicy.rebound(elapsed: reactionAge) : 0
        let hover = animated ? sin(time * 1.9) * 0.018 : 0
        let turn = animated && mood == .thinking ? sin(time * 2.6) * 0.055 : 0
        let leap = animated && mood == .won ? abs(sin(time * 3.6)) * 0.055 : 0
        let stretch = hover + rebound * 0.065 + leap
        let outlineRect = CGRect(
            x: unit * 0.085, y: unit * 0.095,
            width: unit * 0.83, height: unit * 0.83
        )
        ctx.translateBy(x: width * 0.5, y: height * 0.5)
        ctx.rotate(by: .radians(turn + rebound * 0.12))
        ctx.scaleBy(x: 1 - stretch * 0.4, y: 1 + stretch)
        ctx.translateBy(x: -width * 0.5, y: -height * 0.5)

        let contour = VeilLiquidContour(
            time: time, mood: mood, motionAllowed: animated
        ).path(in: outlineRect)

        // Original near-black liquid with a soft cold-metal edge.
        ctx.fill(
            contour,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.14, green: 0.18, blue: 0.26),
                    Color(red: 0.035, green: 0.045, blue: 0.075),
                    Color(red: 0.10, green: 0.12, blue: 0.20)
                ]),
                startPoint: CGPoint(x: width * 0.16, y: height * 0.1),
                endPoint: CGPoint(x: width * 0.80, y: height * 0.86)
            )
        )
        ctx.stroke(
            contour,
            with: .color(Color.cyan.opacity(mood == .thinking ? 0.58 : 0.23)),
            lineWidth: max(0.7, unit * 0.018)
        )

        // A minimal specular band, built from scratch.
        var highlight = Path()
        highlight.move(to: CGPoint(x: width * 0.23, y: height * 0.35))
        highlight.addQuadCurve(
            to: CGPoint(x: width * 0.47, y: height * 0.19),
            control: CGPoint(x: width * 0.29, y: height * 0.21)
        )
        ctx.stroke(highlight, with: .color(.white.opacity(0.16)), lineWidth: unit * 0.020)

        let pupilOffset: CGFloat = animated && mood == .thinking
            ? CGFloat(sin(time * 2.25)) * unit * 0.045 : 0
        let blink: CGFloat = !animated ? 1
            : cos(time * 2.25) > 0.994 ? 0.12 : 1

        for eyeIndex in 0..<2 {
            let centerX = width * (eyeIndex == 0 ? 0.375 : 0.625) + pupilOffset
            let centerY = height * 0.48
            let w = unit * 0.105
            let h = unit * 0.17 * blink
            let eyeCenter = CGPoint(x: centerX, y: centerY)
            switch mood {
            case .won:
                var arc = Path()
                arc.move(to: CGPoint(x: eyeCenter.x - w * 0.58, y: centerY + h * 0.18))
                arc.addQuadCurve(
                    to: CGPoint(x: eyeCenter.x + w * 0.58, y: centerY + h * 0.18),
                    control: CGPoint(x: centerX, y: centerY - h * 0.42)
                )
                ctx.stroke(
                    arc, with: .color(Color(red: 0.75, green: 1, blue: 0.83)),
                    style: StrokeStyle(lineWidth: unit * 0.046, lineCap: .round)
                )
            case .lost:
                var down = Path()
                down.move(to: CGPoint(x: centerX - w * 0.55, y: centerY - h * 0.15))
                down.addLine(to: CGPoint(x: centerX + w * 0.55, y: centerY + h * 0.24))
                ctx.stroke(
                    down, with: .color(.orange.opacity(0.95)),
                    style: StrokeStyle(lineWidth: unit * 0.044, lineCap: .round)
                )
            case .draw:
                var flat = Path()
                flat.move(to: CGPoint(x: centerX - w * 0.50, y: centerY))
                flat.addLine(to: CGPoint(x: centerX + w * 0.50, y: centerY))
                ctx.stroke(
                    flat, with: .color(.white.opacity(0.88)),
                    style: StrokeStyle(lineWidth: unit * 0.041, lineCap: .round)
                )
            case .idle, .thinking:
                let eyeFrame = CGRect(
                    x: centerX - w / 2, y: centerY - h / 2,
                    width: w, height: max(unit * 0.016, h)
                )
                ctx.fill(
                    Path(roundedRect: eyeFrame, cornerRadius: w * 0.46),
                    with: .color(.white.opacity(0.94))
                )
            }
        }

        if mood == .thinking {
            let arcAngle = animated ? time * 1.55 : 0
            var orbit = Path()
            orbit.addArc(
                center: CGPoint(x: width * 0.5, y: height * 0.52),
                radius: unit * 0.46,
                startAngle: .radians(arcAngle),
                endAngle: .radians(arcAngle + 1.0),
                clockwise: false
            )
            ctx.stroke(
                orbit,
                with: .color(.cyan.opacity(0.6)),
                style: StrokeStyle(lineWidth: unit * 0.018, lineCap: .round)
            )
        }
    }
}

// The GIF has 24 frames; only the compact 112px asset should be shipped on
// iPhone 7. One process-wide decoded copy is reused by all views.
@MainActor
private enum VeilGrokBotGIFAsset {
    static let animation: UIImage? = {
        guard let url = Bundle.main.url(forResource: "GrokBotLoop", withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let count = CGImageSourceGetCount(source)
        guard (2...64).contains(count) else { return nil }
        var images: [UIImage] = []
        images.reserveCapacity(count)
        var duration: TimeInterval = 0
        for index in 0..<count {
            guard let bitmap = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                return nil
            }
            images.append(UIImage(cgImage: bitmap))
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
                as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let unclamped = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
            let clamped = gif?[kCGImagePropertyGIFDelayTime] as? NSNumber
            duration += max(0.06, unclamped?.doubleValue ?? clamped?.doubleValue ?? 0.11)
        }
        return UIImage.animatedImage(with: images, duration: duration)
    }()
}

/// UIImageView is the native GIF player; it does not capture board gestures.
private struct VeilGrokBotGIFPlayer: UIViewRepresentable {
    let running: Bool

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView(image: VeilGrokBotGIFAsset.animation)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.clipsToBounds = true
        if running { imageView.startAnimating() }
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if running {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }
}

// Plays the complete Owner-supplied H.264 animation (921 frames, 30.7 seconds).
// No transcoding or frame extraction is required in the running app.
private final class VeilGrokBotVideoSurface: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }

    var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct VeilGrokBotFullVideoPlayer: UIViewRepresentable {
    let running: Bool
    let cornerRadius: CGFloat

    final class Coordinator {
        let player: AVQueuePlayer
        let looper: AVPlayerLooper?

        init() {
            let queue = AVQueuePlayer()
            queue.isMuted = true
            queue.actionAtItemEnd = .none
            player = queue
            if let url = Bundle.main.url(forResource: "GrokBotFull", withExtension: "mp4") {
                looper = AVPlayerLooper(
                    player: queue, templateItem: AVPlayerItem(url: url)
                )
            } else {
                looper = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> VeilGrokBotVideoSurface {
        let view = VeilGrokBotVideoSurface(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = cornerRadius
        view.layer.masksToBounds = true
        view.videoLayer.videoGravity = .resizeAspect
        view.videoLayer.player = context.coordinator.player
        if running { context.coordinator.player.play() }
        return view
    }

    func updateUIView(_ view: VeilGrokBotVideoSurface, context: Context) {
        view.layer.cornerRadius = cornerRadius
        view.layer.masksToBounds = true
        if running {
            context.coordinator.player.play()
        } else {
            context.coordinator.player.pause()
        }
    }

    static func dismantleUIView(_ view: VeilGrokBotVideoSurface, coordinator: Coordinator) {
        coordinator.player.pause()
        view.videoLayer.player = nil
        coordinator.looper?.disableLooping()
        coordinator.player.removeAllItems()
    }
}
