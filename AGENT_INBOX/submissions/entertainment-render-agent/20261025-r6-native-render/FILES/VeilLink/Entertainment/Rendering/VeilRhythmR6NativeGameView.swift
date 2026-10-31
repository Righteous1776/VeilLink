#if canImport(UIKit) && canImport(SpriteKit)
import SwiftUI
import Foundation

/// R6 minimal iOS15 native-scene game prototype. Does not attach UIWindow recognizers,
/// alter existing GameLobby, or mutate transport/database/key material.
struct VeilRhythmR6NativeGameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var game = VeilRhythmLiveConductor(seed: 20261025)
    @State private var nowValue = 0.0
    @State private var status = "准备开始：请在音符到达金色判定线时按下对应轨道。"
    @State private var initiated = false
    private let titles = ["左一", "左二", "右二", "右一"]
    private func now() -> Double { ProcessInfo.processInfo.systemUptime }
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    Text("雨夜回声 · 原生渲染 R6").font(.headline)
                    Text("SpriteKit 画面 · Swift 游戏逻辑 · 不接入网络")
                        .font(.caption).foregroundColor(.secondary)
                    TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !game.isRunning)) { timeline in
                        VStack(spacing: 9) {
                            let frame = game.frame(at: nowValue)
                            Text("区域 \(frame.district + 1)/4 · 节拍 \(min(frame.beat+1,16))/16 · 分数 \(frame.score) · 能量 \(frame.focus)")
                                .font(.caption.monospacedDigit())
                            VeilRhythmNativeStage(snapshot: .init(
                                seed: game.session.seed,
                                district: frame.district, nextBeat: frame.beat,
                                secondsToNextBeat: frame.secondsToBeat,
                                sampledUptime: nowValue, running: frame.running))
                                .aspectRatio(390.0 / 600.0, contentMode: .fit)
                                .frame(height: min(470, max(260, geometry.size.height * 0.52)))
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("四轨节奏画面，底部有可操作的轨道按钮")
                                .accessibilityAddTraits(.isImage)
                            HStack(spacing: 6) {
                                ForEach(0..<4, id: \.self) { lane in
                                    Button(titles[lane]) { hit(lane) }
                                        .buttonStyle(.borderedProminent)
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .disabled(!game.isRunning)
                                        .accessibilityLabel("第 \(lane + 1) 轨，\(titles[lane])")
                                }
                            }
                        }
                        .onChange(of: timeline.date) { _ in tick() }
                    }
                    Text(status).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        if !initiated {
                            Button("开始演奏") { begin() }.buttonStyle(.borderedProminent)
                        } else if game.isPaused {
                            Button("恢复") { resume() }.buttonStyle(.borderedProminent)
                        } else if game.isRunning {
                            Button("暂停") { pause() }.buttonStyle(.bordered)
                        }
                        Button("重来") { game = .init(seed: 20261025); initiated = false; nowValue = now(); status = "重置完成" }
                            .buttonStyle(.bordered)
                    }
                    if game.session.districtCompleted && game.session.phase == .playing {
                        Button("进入下一幕") { travel() }.buttonStyle(.borderedProminent)
                    }
                    if game.session.phase != .playing { Text(game.session.phase == .cleared ? "通关" : "本局结束") }
                }
                .padding(12)
            }
        }
        .navigationTitle("节律远征")
        .onChange(of: scenePhase) { phase in if phase != .active { pause() } }
        .onDisappear { pause() }
    }
    private func begin() {
        let t = now(); do { try game.start(at:t); nowValue=t; initiated=true; status="已开始" }
        catch { status="无法开始：\(error)" }
    }
    private func hit(_ lane:Int) {
        let t=now()
        do {
            let quality=try game.tap(lane:lane,at:t)
            nowValue=t
            status="判定 \(quality)"
        } catch VeilRhythmLiveConductor.Failure.tooEarly { status="尚未到达判定线" }
          catch { status="操作未生效：\(error)" }
    }
    private func tick() {
        guard game.isRunning else { return }
        let t=now(); do { let skipped=try game.advance(to:t); nowValue=t; if skipped>0 { status="漏击 \(skipped) 音" } }
        catch { status="计时异常：\(error)" }
    }
    private func pause() {
        guard game.isRunning else { return }
        do { try game.pause(at:now()); status="已暂停" } catch { status="暂停错误：\(error)" }
    }
    private func resume() {
        let t=now(); do { try game.resume(at:t); nowValue=t; status="继续" } catch { status="恢复错误：\(error)" }
    }
    private func travel() {
        let t=now(); do { try game.travel(at:t); try game.start(at:t); nowValue=t; status="新章节开始" }
        catch { status="切换失败：\(error)" }
    }
}
#endif
