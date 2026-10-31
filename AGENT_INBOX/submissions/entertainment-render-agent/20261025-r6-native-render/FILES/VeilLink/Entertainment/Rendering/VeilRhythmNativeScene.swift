#if canImport(UIKit) && canImport(SpriteKit)
import UIKit
import SpriteKit
import SwiftUI

/// R6 rendering-only scene, intentionally touch transparent.
/// SpriteKit paints with a FIXED 390x600 coordinate system and aspectFit scaling.
/// Logic and judgement are owned by VeilRhythmLiveConductor, not render frames.
@MainActor
final class VeilRhythmNativeScene: SKScene {
    struct Snapshot {
        let seed: UInt64
        let district: Int
        let nextBeat: Int
        let secondsToNextBeat: Double?
        let sampledUptime: Double
        let running: Bool
    }
    private let maxNotePool = VeilRenderBudget(tier: .legacy).visibleNotes
    private var notes: [SKShapeNode] = []
    private var latest: Snapshot?
    private let noteColor = UIColor(red: 0.27, green: 0.89, blue: 1, alpha: 1)
    private let rail = UIColor(red: 0.21, green: 0.30, blue: 0.39, alpha: 1)

    override init(size: CGSize) {
        super.init(size: size)
        self.scaleMode = .aspectFit  // DO NOT replace with .fill or .resizeFill.
        self.anchorPoint = .zero
        self.backgroundColor = UIColor(red: 0.025, green: 0.036, blue: 0.08, alpha: 1)
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("Use init(size:)") }
    override func didMove(to view: SKView) {
        if !notes.isEmpty { return }
        // All geometry measured in virtual points; no physical pixel sizes.
        for lane in 0..<4 {
            let cx = CGFloat(Double(lane) + 0.5) * (size.width / 4)
            let railNode = SKShapeNode(rectOf: CGSize(width: size.width / 4 - 12, height: 460), cornerRadius: 13)
            railNode.fillColor = rail.withAlphaComponent(0.18)
            railNode.strokeColor = rail.withAlphaComponent(0.52)
            railNode.lineWidth = 1
            railNode.position = CGPoint(x: cx, y: size.height - 300)
            railNode.zPosition = 0
            addChild(railNode)
        }
        let strike = SKShapeNode(rectOf: CGSize(width: size.width - 30, height: 3))
        strike.position = CGPoint(x: size.width * 0.5, y: size.height - CGFloat(VeilRhythmVisualTimeline.strikeY))
        strike.fillColor = UIColor(red: 1, green: 0.7, blue: 0.4, alpha: 0.94)
        strike.strokeColor = .clear
        strike.zPosition = 3
        addChild(strike)
        for _ in 0..<maxNotePool {
            let n = SKShapeNode(rectOf: CGSize(width: 64, height: 20), cornerRadius: 9)
            n.fillColor = noteColor
            n.strokeColor = .white.withAlphaComponent(0.55)
            n.lineWidth = 1.5
            n.zPosition = 5
            n.isHidden = true
            addChild(n)
            notes.append(n)
        }
    }
    func apply(_ snapshot: Snapshot) { latest = snapshot }
    override func update(_ currentTime: TimeInterval) {
        guard let latest = latest,
              let seconds = latest.secondsToNextBeat,
              seconds.isFinite else { notes.forEach { $0.isHidden = true }; return }
        // Use uptime, never SpriteKit's independent animation epoch as music time.
        let uptime = ProcessInfo.processInfo.systemUptime
        let elapsed = latest.running ? max(0, min(uptime - latest.sampledUptime, 0.35)) : 0
        let relative = seconds - elapsed
        let visible = VeilRhythmVisualTimeline.notes(
            seed: latest.seed, district: latest.district,
            nextBeat: latest.nextBeat, secondsToNextBeat: relative,
            capacity: maxNotePool)
        for (index, node) in notes.enumerated() {
            guard index < visible.count else { node.isHidden = true; continue }
            let item = visible[index]
            node.position = CGPoint(x: item.x, y: size.height - item.y)
            node.isHidden = false
        }
    }
}

/// No gestures or buttons live INSIDE SKView. SwiftUI owns accessible input below.
/// Coordinator retains one scene, preventing scene recreation during View updates.
struct VeilRhythmNativeStage: UIViewRepresentable {
    let snapshot: VeilRhythmNativeScene.Snapshot
    func makeCoordinator() -> Coordinator { Coordinator() }
    @MainActor final class Coordinator {
        let scene = VeilRhythmNativeScene(size: CGSize(width: 390, height: 600))
    }
    func makeUIView(context: Context) -> SKView {
        let sk = SKView(frame: .zero)
        sk.backgroundColor = .black
        sk.isUserInteractionEnabled = false
        sk.isMultipleTouchEnabled = false
        sk.preferredFramesPerSecond = 30 // conservative older-device baseline
        sk.ignoresSiblingOrder = true // every node has explicit zPosition
        sk.shouldCullNonVisibleNodes = true
        sk.showsFPS = false
        sk.showsNodeCount = false
        sk.presentScene(context.coordinator.scene)
        return sk
    }
    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.scene.apply(snapshot)
    }
    static func dismantleUIView(_ uiView: SKView, coordinator: Coordinator) {
        uiView.isPaused = true
        uiView.presentScene(nil)
    }
}
#endif
