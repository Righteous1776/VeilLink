import SwiftUI

/// Recovery landing page only. Never describes a missing third-party engine
/// as installed or attempts to execute unverified bundled HTML / JS.
struct VeilGalgameRecoveryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Galgame · 游戏引擎恢复", systemImage: "book.closed.fill")
                    .font(.title3.bold())
                Text("入口已经恢复。完整的 Monogatari 2.8.0 引擎资源与经过验证的 R5 宿主集成尚未包含在当前 Build 62。")
                    .font(.subheadline)
                Label("Monogatari R5 二进制未安装 · 暂不可启动", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.footnote.weight(.semibold))
                Text("恢复需要：官方引擎发行包的逐字节校验、R5 原生宿主与资源拼装、iOS 15 Xcode 构建、存档重进测试、iPhone 7 真机触控验证。不能仅靠一个网页按钮宣称可玩。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                NavigationLink(destination: VeilStoryLabView()) {
                    Label("使用当前已安装的分支故事实验室", systemImage: "arrow.right.circle")
                }
                .buttonStyle(.borderedProminent)
                Text("构建来源：Game Agent PR #80 / #85，Monogatari 2.8.0。此入口不会下载或执行第三方资源。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
        .navigationTitle("Galgame")
        .navigationBarTitleDisplayMode(.inline)
    }
}
