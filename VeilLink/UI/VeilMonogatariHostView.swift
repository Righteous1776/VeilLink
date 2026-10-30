import SwiftUI
import WebKit

/// Sandboxed, local-only host for the bundled MIT Monogatari 2.8.0 runtime.
/// No script message handler, native database, transport or identity bridge.
struct VeilMonogatariHostView: View {
    var body: some View {
        Group {
            if let root = VeilMonogatariBundle.resourceRoot() {
                VeilMonogatariWebView(resourceRoot: root)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                    Text("剧情引擎资源未安装完整").font(.headline)
                    Text("未找到 MonogatariHost/index.html 或官方 v2.8.0 引擎。请使用完整安装包，当前无法离线游玩。")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
            }
        }
        .background(VeilTheme.background)
        .navigationTitle("VeilLink × Monogatari")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum VeilMonogatariBundle {
    static let requiredFiles = [
        "index.html",
        "engine/monogatari.js",
        "engine/monogatari.css",
        "options.js",
        "storage.js",
        "script.js",
        "main.js",
        "LICENSE.txt"
    ]

    static func resourceRoot(in bundle: Bundle = .main) -> URL? {
        guard let root = bundle.resourceURL?.appendingPathComponent(
            "MonogatariHost", isDirectory: true
        ) else { return nil }
        let fm = FileManager.default
        guard requiredFiles.allSatisfy({
            fm.isReadableFile(atPath: root.appendingPathComponent($0).path)
        }) else { return nil }
        return root
    }
}

private struct VeilMonogatariWebView: UIViewRepresentable {
    let resourceRoot: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        // Local save slots need persistence, but the web view has no native bridge.
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 16/255, green: 26/255, blue: 46/255, alpha: 1)
        view.scrollView.bounces = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        let index = resourceRoot.appendingPathComponent("index.html")
        view.loadFileURL(index, allowingReadAccessTo: resourceRoot)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            // Prevent web content from opening network destinations.
            // Browser subresource requests are also constrained by index.html CSP.
            let safeSchemes = ["file", "about", "blob"]
            decisionHandler(safeSchemes.contains(url.scheme?.lowercased() ?? "") ? .allow : .cancel)
        }
    }
}
