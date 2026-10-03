import Combine
import CoreGraphics
import Foundation

enum PlatformerGamePhase: Equatable, Sendable {
    case ready
    case playing
    case paused
    case levelComplete
    case campaignComplete
    case gameOver
}

/// SwiftUI-facing state and control surface for the SpriteKit game.
@MainActor
final class PlatformerGameSession: ObservableObject {
    @Published private(set) var phase: PlatformerGamePhase = .ready
    @Published private(set) var levelIndex = 0
    @Published private(set) var score = 0
    @Published private(set) var collectedCrystals = 0
    @Published private(set) var requiredCrystals = 0
    @Published private(set) var lives = 3
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var dashReady = true
    @Published private(set) var message = "准备进入星隙"

    let levels: [PlatformerLevel]
    lazy var scene: PlatformerScene = PlatformerScene(session: self)

    init(levels: [PlatformerLevel] = PlatformerLevel.campaign) {
        precondition(!levels.isEmpty, "A platformer campaign needs at least one level")
        precondition(levels.allSatisfy(\.isValid), "Platformer campaign contains invalid level geometry")
        self.levels = levels
        requiredCrystals = levels[0].requiredCrystalCount
    }

    var currentLevel: PlatformerLevel { levels[levelIndex] }
    var isPlaying: Bool { phase == .playing }
    var progress: Double {
        guard requiredCrystals > 0 else { return 1 }
        return min(1, Double(collectedCrystals) / Double(requiredCrystals))
    }

    func start() {
        switch phase {
        case .ready, .gameOver, .campaignComplete:
            if phase != .ready { resetCampaign() }
            phase = .playing
            message = currentLevel.subtitle
            scene.start(level: currentLevel)
        case .paused:
            resume()
        case .playing, .levelComplete:
            break
        }
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
        message = "信号已暂停"
        scene.isPaused = true
        scene.setHorizontalInput(0)
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .playing
        message = currentLevel.subtitle
        scene.isPaused = false
    }

    func restartLevel() {
        guard phase != .campaignComplete else { return }
        collectedCrystals = 0
        requiredCrystals = currentLevel.requiredCrystalCount
        elapsedTime = 0
        dashReady = true
        phase = .playing
        message = "重新建立传送坐标"
        scene.isPaused = false
        scene.start(level: currentLevel)
    }

    func move(horizontal direction: CGFloat) {
        guard phase == .playing else { return }
        scene.setHorizontalInput(direction)
    }

    func jump() {
        guard phase == .playing else { return }
        scene.requestJump()
    }

    func releaseJump() {
        scene.releaseJump()
    }

    func dash() {
        guard phase == .playing else { return }
        scene.requestDash()
    }

    func setElapsedTime(_ time: TimeInterval) {
        elapsedTime = time
    }

    func setDashReady(_ ready: Bool) {
        guard dashReady != ready else { return }
        dashReady = ready
    }

    func collectCrystal() {
        collectedCrystals += 1
        score += 150
        if collectedCrystals == requiredCrystals {
            message = "星核齐全，出口信标已解锁"
        }
    }

    func registerHazardHit() {
        lives -= 1
        if lives <= 0 {
            phase = .gameOver
            message = "连接中断 · 点击重试"
        } else {
            message = "护盾受损 · 剩余 \(lives) 格"
        }
    }

    func reachLockedExit() {
        message = "还差 \(max(0, requiredCrystals - collectedCrystals)) 个星核"
    }

    func completeLevel() {
        guard phase == .playing else { return }
        score += max(300, 1_200 - Int(elapsedTime * 8))
        if levelIndex == levels.count - 1 {
            phase = .campaignComplete
            message = "极光信标已点亮"
            scene.celebrateCampaign()
        } else {
            phase = .levelComplete
            message = "路线稳定 · 正在前往下一站"
            scene.finishLevel()
        }
    }

    func advanceToNextLevel() {
        guard phase == .levelComplete, levelIndex + 1 < levels.count else { return }
        levelIndex += 1
        collectedCrystals = 0
        requiredCrystals = currentLevel.requiredCrystalCount
        elapsedTime = 0
        dashReady = true
        phase = .playing
        message = currentLevel.subtitle
        scene.start(level: currentLevel)
    }

    private func resetCampaign() {
        levelIndex = 0
        score = 0
        collectedCrystals = 0
        requiredCrystals = levels[0].requiredCrystalCount
        lives = 3
        elapsedTime = 0
        dashReady = true
    }
}
