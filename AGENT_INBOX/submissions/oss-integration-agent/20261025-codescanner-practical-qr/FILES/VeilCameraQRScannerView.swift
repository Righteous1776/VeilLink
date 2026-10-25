import SwiftUI
import CodeScanner

/// iOS 15 single-shot camera scanner shared by offline text and Relay pairing.
/// No continuous capture, background camera mode, logging or URL auto-opening.
struct VeilCameraQRScannerView: View {
    let purpose: VeilQRScanPurpose
    let onScanned: (String) -> Void
    let onFailure: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var finished = false

    private var heading: String {
        purpose == .temporaryText ? "扫描本地文本二维码" : "扫描一次性配对二维码"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CodeScannerView(
                    codeTypes: [.qr],
                    scanMode: .once,
                    showViewfinder: true,
                    requiresPhotoOutput: false,
                    shouldVibrateOnSuccess: false
                ) { response in
                    DispatchQueue.main.async {
                        guard !finished else { return }
                        finished = true
                        switch response {
                        case .success(let scanned):
                            do {
                                let value = try VeilQRScanPolicy.validatedText(scanned.string, purpose: purpose)
                                onScanned(value)
                            } catch {
                                onFailure((error as? LocalizedError)?.errorDescription ?? "二维码内容无效。")
                            }
                        case .failure:
                            onFailure("相机扫码不可用。请检查相机权限，或改用相册导入。")
                        }
                        dismiss()
                    }
                }
                Text(purpose == .temporaryText
                     ? "本机解析文本，不访问网络；不会自动打开二维码中的链接。"
                     : "仅导入配对文本；远程配对仍需要 Relay 网络与双方六码确认。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(12)
            }
            .navigationTitle(heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
