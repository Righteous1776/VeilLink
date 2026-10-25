import CodeScanner
import SwiftUI

/// Opt-in, device-local QR reader. No automatic URL loading or network access.
struct VeilOfflineQRReaderView: View {
    @State private var showsCamera = false
    @State private var scanResolved = false
    @State private var capturedText = ""
    @State private var failureText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("本地二维码阅读器", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                Text("使用后置摄像头读取短文本。二维码不会自动执行任何操作，也不会自动打开网址。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    scanResolved = false
                    failureText = nil
                    showsCamera = true
                } label: {
                    Label("打开摄像头扫描", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if let failureText {
                    Label(failureText, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundColor(.red)
                }

                if !capturedText.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("扫描内容").font(.subheadline.weight(.semibold))
                        Text(capturedText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Button {
                            VeilToolClipboard.copy(capturedText)
                        } label: {
                            Label("主动复制到剪贴板", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        Button("清除本次内容") {
                            capturedText = ""
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Text("隐私：扫描文本只保存在当前界面的内存中；不写入聊天数据库，不上传，不记录原始图像。复制是用户主动操作，系统剪贴板由 iOS 管理。单次内容最多 4 KiB。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(16)
        }
        .navigationTitle("二维码阅读器")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsCamera) {
            NavigationView {
                CodeScannerView(
                    codeTypes: [.qr],
                    scanMode: .once,
                    showViewfinder: true,
                    requiresPhotoOutput: false,
                    shouldVibrateOnSuccess: false
                ) { response in
                    switch response {
                    case .success(let scanned):
                        let text = scanned.string
                        DispatchQueue.main.async {
                            guard !scanResolved else { return }
                            scanResolved = true
                            showsCamera = false
                            guard !text.isEmpty, text.utf8.count <= 4_096 else {
                                failureText = "二维码内容为空或超过 4 KiB，已拒绝读取。"
                                return
                            }
                            capturedText = text
                            failureText = nil
                        }
                    case .failure(let error):
                        let description = error.localizedDescription
                        DispatchQueue.main.async {
                            guard !scanResolved else { return }
                            scanResolved = true
                            showsCamera = false
                            failureText = "扫码失败：\(description)"
                        }
                    }
                }
                .navigationTitle("扫描二维码")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("取消") { showsCamera = false }
                    }
                }
            }
        }
    }
}
