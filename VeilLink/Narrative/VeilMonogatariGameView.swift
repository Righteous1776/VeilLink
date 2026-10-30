import SwiftUI
import WebKit

// VeilLink game host: isolated from AppModel, BLE, SQLite and Keychain.
// The upstream browser runtime in VisualNovelBundle/engine is not modified.
struct VeilMonogatariGameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var generation = UUID()
    @State private var useFileMode = false
    @State private var error: String?
    @State private var warning: String?

    var body: some View {
        ZStack {
            VeilMonogatariWebView(useFileMode: useFileMode) { event in
                switch event {
                case .ready: error = nil
                case .warning(let value): warning = value
                case .failed(let value): error = value
                }
            }
            .id(generation)
            .background(Color(red: 0.03, green: 0.05, blue: 0.11))
            .ignoresSafeArea(edges: .bottom)

            if let error = error {
                Color.black.opacity(0.94).ignoresSafeArea()
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                    Text("视觉小说暂时无法启动").font(.headline)
                    Text(error).font(.subheadline).multilineTextAlignment(.center)
                    Button("重新加载") { reload() }.buttonStyle(.borderedProminent)
                    Button(useFileMode ? "切换到标准模式" : "尝试文件兼容模式") {
                        useFileMode.toggle()
                        reload()
                        warning = "两种模式的存档位置可能不同，切换模式不会迁移或删除存档。"
                    }.buttonStyle(.bordered)
                    Button("返回游戏大厅") { dismiss() }.buttonStyle(.bordered)
                }
                .foregroundColor(.white)
                .padding(24)
            } else if let warning = warning {
                VStack {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(warning).font(.caption)
                        Spacer(minLength: 2)
                        Button { self.warning = nil } label: { Image(systemName: "xmark.circle.fill") }
                    }
                    .padding(12)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }.padding(12)
            }
        }
        .navigationTitle("雨幕之后 · Monogatari")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("退出") { dismiss() }
            }
        }
    }

    private func reload() {
        error = nil
        warning = nil
        generation = UUID()
    }
}

private enum VeilNovelWebEvent {
    case ready
    case warning(String)
    case failed(String)
}

private struct VeilMonogatariWebView: UIViewRepresentable {
    let useFileMode: Bool
    let onEvent: (VeilNovelWebEvent) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(useFileMode: useFileMode, onEvent: onEvent) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.setURLSchemeHandler(VeilMonogatariSchemeHandler(), forURLScheme: VeilMonogatariSchemeHandler.scheme)
        config.userContentController.add(context.coordinator, name: "veilNovel")
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.03, green: 0.05, blue: 0.11, alpha: 1)
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.scrollView.bounces = false
        web.allowsBackForwardNavigationGestures = false

        guard let root = Bundle.main.resourceURL?.appendingPathComponent("VisualNovelBundle", isDirectory: true) else {
            DispatchQueue.main.async { onEvent(.failed("应用资源目录不可用。")) }
            return web
        }
        let required = ["index.html","engine/core/monogatari.js","engine/core/monogatari.css",
                        "js/main.js","js/script.js","js/veillink-native.js","js/veillink-ios15-compat.js"]
        guard required.allSatisfy({ FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }) else {
            DispatchQueue.main.async { onEvent(.failed("缺少必要的游戏资源。请检查 XcodeGen 文件夹引用。")) }
            return web
        }

        if useFileMode {
            web.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
        } else if let url = URL(string: "veilnovel://game/index.html") {
            web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData))
        }
        context.coordinator.armDeadline()
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        coordinator.invalidate()
        web.stopLoading()
        web.navigationDelegate = nil
        web.configuration.userContentController.removeScriptMessageHandler(forName: "veilNovel")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let useFileMode: Bool
        private let onEvent: (VeilNovelWebEvent) -> Void
        private var invalidated = false
        private var ready = false

        init(useFileMode: Bool, onEvent: @escaping (VeilNovelWebEvent) -> Void) {
            self.useFileMode = useFileMode
            self.onEvent = onEvent
        }
        func invalidate() { invalidated = true }
        private func emit(_ e: VeilNovelWebEvent) {
            guard !invalidated else { return }
            if Thread.isMainThread { onEvent(e) }
            else { DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.invalidated else { return }
                self.onEvent(e)
            } }
        }
        func armDeadline() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                guard let self = self, !self.invalidated, !self.ready else { return }
                self.emit(.failed("20 秒内未收到引擎就绪信号。请尝试重新加载或兼容模式。"))
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard !invalidated, let url = action.request.url else { decisionHandler(.cancel); return }
            let permitted: Bool
            if useFileMode {
                let root = Bundle.main.resourceURL?.appendingPathComponent("VisualNovelBundle", isDirectory: true)
                    .standardizedFileURL.resolvingSymlinksInPath().path ?? ""
                let resolved = url.standardizedFileURL.resolvingSymlinksInPath().path
                permitted = url.isFileURL && !root.isEmpty && resolved.hasPrefix(root + "/")
            } else {
                permitted = url.scheme == VeilMonogatariSchemeHandler.scheme &&
                    url.host == VeilMonogatariSchemeHandler.host && url.user == nil &&
                    url.password == nil
            }
            decisionHandler(permitted ? .allow : .cancel)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError failure: Error) {
            if (failure as NSError).code != NSURLErrorCancelled { emit(.failed("游戏资源加载失败。")) }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError failure: Error) {
            if (failure as NSError).code != NSURLErrorCancelled { emit(.failed("游戏页面加载中断。")) }
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            emit(.failed("WebKit 页面进程已退出。请手动重新加载。"))
        }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !invalidated, message.name == "veilNovel", message.frameInfo.isMainFrame,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            let origin = message.frameInfo.securityOrigin
            if useFileMode {
                guard origin.protocol == "file" else { return }
            } else {
                guard origin.protocol == VeilMonogatariSchemeHandler.scheme,
                      origin.host == VeilMonogatariSchemeHandler.host else { return }
            }
            let marker = "veilnovel.r5.storage.expected." + (useFileMode ? "file" : "scheme")
            switch type {
            case "ready":
                ready = true; emit(.ready)
            case "storage-probe-created":
                if UserDefaults.standard.bool(forKey: marker) {
                    emit(.warning("检测到本模式的本地存储标记丢失，请核查游戏存档。"))
                }
                UserDefaults.standard.set(true, forKey: marker)
            case "storage-probe-retained":
                UserDefaults.standard.set(true, forKey: marker)
            case "storage-unavailable":
                emit(.warning("WebKit 本地存储不可用，暂勿依赖游戏存档。"))
            case "error":
                emit(.warning("游戏脚本发生异常；如无法继续请重新加载。"))
            case "init-failed":
                emit(.failed("Monogatari 初始化失败，请尝试兼容模式。"))
            default:
                break
            }
        }
    }
}
