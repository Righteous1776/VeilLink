import SpriteKit
import SwiftUI

@MainActor
struct RhythmNeonView: View {
    @State private var scene = RhythmNeonScene()
    @State private var pausedByLifecycle = false
    @State private var isPaused = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: ArcadeRenderPolicy.preferredFramesPerSecond,
            options: [.ignoresSiblingOrder]
        )
            .ignoresSafeArea()
            .accessibilityLabel("霓虹节拍实时街机场景")
            .background(Color.black)
            .navigationTitle("霓虹节拍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPaused = scene.toggleGamePaused()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    }
                    .accessibilityLabel(isPaused ? "继续游戏" : "暂停游戏")
                }
            }
            .onAppear {
                if pausedByLifecycle {
                    pausedByLifecycle = false
                    isPaused = false
                    scene.setGamePaused(false)
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    if pausedByLifecycle {
                        pausedByLifecycle = false
                        isPaused = false
                        scene.setGamePaused(false)
                    }
                } else if !isPaused {
                    pausedByLifecycle = true
                    scene.setGamePaused(true)
                }
            }
            .onDisappear {
                if !isPaused { pausedByLifecycle = true }
                scene.setGamePaused(true)
            }
    }
}
