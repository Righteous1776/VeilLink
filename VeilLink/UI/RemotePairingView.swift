import CoreImage
import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct VeilRemotePairingView: View {
    @ObservedObject var pairing: VeilRemotePairingCoordinator
    @ObservedObject var model: AppModel
    @State private var showsPhotoPicker = false
    @State private var shareItem: ShareablePairImage?
    @State private var saveStatus: String?

    var body: some View {
        VeilStableScrollView {
            VStack(spacing: 14) {
                introCard
                if let candidate = pairing.candidate {
                    candidateCard(candidate)
                } else {
                    offerCard
                    importCard
                }
                statusCard
            }
        }
        .background(VeilAmbientBackground())
        .navigationTitle("远程二维码配对")
        .sheet(isPresented: $showsPhotoPicker) {
            RemotePairQRPhotoPicker { image in
                showsPhotoPicker = false
                do {
                    let text = try VeilPairQRRenderer.detectText(in: image)
                    pairing.consumeQRCode(text)
                    model.haptics.resolved()
                } catch {
                    model.alertMessage = error.localizedDescription
                    model.haptics.error()
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("60 秒一次性远程配对", systemImage: "qrcode.viewfinder")
                .font(.headline)
                .foregroundColor(VeilTheme.goldBright)
            Text("二维码本身不包含用户名、VeilLink Identity ID、长期 Relay Secret 或聊天密钥。对方可以把二维码图片通过微信等方式发送，再从相册导入。首次身份资料只在一次性 X25519 握手后解密。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            Text("安全边界：二维码在 60 秒内仍是一次性 bearer capability。若图片被截获，第三方可以尝试抢占请求，但双方六码确认和身份摘要仍会阻止静默永久配对。")
                .font(.caption2)
                .foregroundColor(VeilTheme.tertiaryText)
        }
        .veilCard(emphasized: true)
    }

    @ViewBuilder
    private var offerCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("我的一次性配对码").font(.headline)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(countdown(at: context.date))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(VeilTheme.gold)
                }
            }

            if let text = pairing.qrText, let image = VeilPairQRRenderer.render(text: text) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityLabel("VeilLink 远程配对二维码")

                HStack(spacing: 10) {
                    Button {
                        shareItem = ShareablePairImage(image: image)
                        model.haptics.selection()
                    } label: { Label("分享图片", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderedProminent)
                        .tint(VeilTheme.gold)

                    Button {
                        save(image)
                    } label: { Label("保存相册", systemImage: "square.and.arrow.down") }
                        .buttonStyle(.bordered)
                }
                if let saveStatus {
                    Text(saveStatus).font(.caption2).foregroundColor(VeilTheme.secondaryText)
                }
            } else {
                Button {
                    pairing.startOffering()
                    model.haptics.selection()
                } label: {
                    Label("生成 60 秒配对二维码", systemImage: "qrcode")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(VeilPressStyle())
            }

            if pairing.qrText != nil {
                Button {
                    pairing.refreshOfferNow()
                    model.haptics.selection()
                } label: { Label("立即作废并刷新", systemImage: "arrow.clockwise") }
                    .buttonStyle(VeilPressStyle())
            }
        }
        .veilCard(emphasized: pairing.isOffering)
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("导入朋友发来的二维码", systemImage: "photo.on.rectangle")
                .font(.headline)
                .foregroundColor(VeilTheme.goldBright)
            Text("从微信保存图片后，在这里直接选择。PHPicker 不需要 VeilLink 获取整个照片图库读取权限。")
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
            Button {
                showsPhotoPicker = true
                model.haptics.selection()
            } label: {
                Label("从照片选择二维码", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(VeilPressStyle())
        }
        .veilCard()
    }

    private func candidateCard(_ candidate: VeilRemotePairCandidate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("等待双方确认", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
                .foregroundColor(VeilTheme.goldBright)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.peerDisplayName)
                        .font(.title3.weight(.semibold))
                    Text(candidate.fingerprint)
                        .font(.caption.monospaced())
                        .foregroundColor(VeilTheme.secondaryText)
                }
                Spacer()
                Text(candidate.role == .initiator ? "REQUEST" : "OFFER")
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .foregroundColor(VeilTheme.mutedGold)
            }
            Divider().background(Color.white.opacity(0.07))
            VStack(spacing: 4) {
                Text("双方应显示完全相同的六码")
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
                Text(candidate.sas)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .tracking(6)
                    .foregroundColor(VeilTheme.goldBright)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    pairing.rejectCandidate()
                    model.haptics.error()
                } label: { Text("拒绝").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)

                Button {
                    pairing.confirmCandidate()
                    model.haptics.resolved()
                } label: {
                    Text(candidate.localConfirmed ? "已确认" : "六码一致，确认配对")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(VeilTheme.gold)
                .disabled(candidate.localConfirmed)
            }
            Text(candidate.remoteConfirmed ? "对方已确认" : "等待对方确认")
                .font(.caption2.monospaced())
                .foregroundColor(candidate.remoteConfirmed ? VeilTheme.success : VeilTheme.tertiaryText)
        }
        .veilCard(emphasized: true)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(pairing.lastError == nil ? VeilTheme.success : Color.red).frame(width: 7, height: 7)
                Text(pairing.statusText).font(.caption.weight(.semibold))
            }
            if let error = pairing.lastError {
                Text(error).font(.caption2).foregroundColor(.red.opacity(0.85))
            }
            if let peer = pairing.lastPairedPeerName {
                Text("最近完成：\(peer)").font(.caption2).foregroundColor(VeilTheme.secondaryText)
            }
        }
        .veilCard()
    }

    private func countdown(at date: Date) -> String {
        guard let expiry = pairing.qrExpiresAt else { return "--" }
        return "\(max(0, Int(ceil(expiry.timeIntervalSince(date)))))s"
    }

    private func save(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                saveStatus = success ? "已保存到相册" : (error?.localizedDescription ?? "保存失败")
                success ? model.haptics.resolved() : model.haptics.error()
            }
        }
    }
}

private struct ShareablePairImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct RemotePairQRPhotoPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: RemotePairQRPhotoPicker
        init(parent: RemotePairQRPhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                picker.dismiss(animated: true); return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self.parent.onPicked(image)
                    picker.dismiss(animated: true)
                }
            }
        }
    }
}

enum VeilPairQRRenderer {
    private static let moduleScale: CGFloat = 9
    private static let quietZoneModules: CGFloat = 5

    static func render(text: String) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")
        guard let base = filter.outputImage else { return nil }
        let scaled = base.transformed(by: CGAffineTransform(scaleX: moduleScale, y: moduleScale))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let qrCG = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        // Bake a true QR quiet zone into the shared bitmap. A SwiftUI-only padding is lost when
        // the UIImage is exported through WeChat/Photos, and recompression is much less forgiving
        // when the finder pattern touches the image edge.
        let quiet = Int(quietZoneModules * moduleScale)
        let size = CGSize(width: qrCG.width + quiet * 2, height: qrCG.height + quiet * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            UIColor.white.setFill()
            renderer.fill(CGRect(origin: .zero, size: size))
            renderer.cgContext.interpolationQuality = .none
            UIImage(cgImage: qrCG).draw(in: CGRect(x: quiet, y: quiet, width: qrCG.width, height: qrCG.height))
        }
    }

    static func detectText(in image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else { throw VeilRemotePairError.invalidQRCode }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.QR]
        try VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(image.imageOrientation)).perform([request])
        guard let value = request.results?.compactMap({ $0.payloadStringValue }).first(where: { $0.hasPrefix("veillink://pair?") }) else {
            throw VeilRemotePairError.invalidQRCode
        }
        return value
    }

    private static func cgOrientation(_ orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
