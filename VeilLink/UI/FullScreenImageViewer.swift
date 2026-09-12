import SwiftUI
import UIKit

/// In-app large-image viewer. Source bytes stay local and encrypted at rest; only the requested
/// display-sized image is decrypted/decoded into memory while this full-screen view is presented.
struct FullScreenImageViewer: View {
    let attachmentID: String
    let database: DatabaseStore
    let initialImage: UIImage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var image: UIImage
    @State private var isLoadingLargeImage = false
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var dismissDrag: CGFloat = 0
    @State private var controlsVisible = true

    init(attachmentID: String, database: DatabaseStore, initialImage: UIImage) {
        self.attachmentID = attachmentID
        self.database = database
        self.initialImage = initialImage
        _image = State(initialValue: initialImage)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height + dismissDrag)
                    .opacity(dismissOpacity)
                    .contentShape(Rectangle())
                    .gesture(magnificationGesture)
                    .simultaneousGesture(dragGesture)
                    .onTapGesture(count: 2, perform: toggleZoom)
                    .onTapGesture { toggleControls() }
            }
            .ignoresSafeArea()

            if controlsVisible {
                viewerChrome
                    .transition(.opacity)
            }
        }
        .statusBar(hidden: true)
        .onAppear(perform: loadLargeImage)
        .accessibilityAction(named: "关闭大图") { dismiss() }
    }

    private var dismissOpacity: Double {
        guard scale <= 1.01 else { return 1 }
        return Double(max(0.55, 1 - min(dismissDrag, 260) / 520))
    }

    private var viewerChrome: some View {
        VStack {
            HStack {
                if isLoadingLargeImage {
                    HStack(spacing: 7) {
                        ProgressView().tint(.white)
                        Text("正在载入高清大图")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.white.opacity(0.78))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.black.opacity(0.56), in: Capsule())
                } else {
                    Text(scale > 1.01 ? String(format: "%.1f×", scale) : "大图")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.80))
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(Color.black.opacity(0.56), in: Capsule())
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 38, height: 38)
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.62), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭大图")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            Spacer()

            if scale <= 1.01 {
                Text("双指缩放 · 双击放大 · 下滑关闭")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white.opacity(0.62))
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .background(Color.black.opacity(0.48), in: Capsule())
                    .padding(.bottom, 14)
            }
        }
        .padding(.top, 2)
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposed = committedScale * value
                scale = min(5, max(1, proposed))
                if scale > 1.01 { dismissDrag = 0 }
            }
            .onEnded { _ in
                committedScale = scale
                if scale <= 1.01 { resetTransform(animated: true) }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if scale > 1.01 {
                    offset = CGSize(
                        width: committedOffset.width + value.translation.width,
                        height: committedOffset.height + value.translation.height
                    )
                } else {
                    let primarilyVertical = abs(value.translation.height) > abs(value.translation.width)
                    dismissDrag = primarilyVertical ? max(0, value.translation.height) : 0
                }
            }
            .onEnded { value in
                if scale > 1.01 {
                    committedOffset = offset
                    return
                }

                let primarilyVertical = abs(value.translation.height) > abs(value.translation.width)
                if primarilyVertical && value.translation.height > 120 {
                    dismiss()
                } else {
                    if reduceMotion {
                        dismissDrag = 0
                    } else {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { dismissDrag = 0 }
                    }
                }
            }
    }

    private func toggleZoom() {
        if scale > 1.01 {
            resetTransform(animated: true)
        } else {
            let change = {
                scale = 2.5
                committedScale = 2.5
                offset = .zero
                committedOffset = .zero
                dismissDrag = 0
            }
            if reduceMotion { change() } else { withAnimation(.easeOut(duration: 0.20), change) }
        }
    }

    private func resetTransform(animated: Bool) {
        let change = {
            scale = 1
            committedScale = 1
            offset = .zero
            committedOffset = .zero
            dismissDrag = 0
        }
        if animated && !reduceMotion {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88), change)
        } else {
            change()
        }
    }

    private func toggleControls() {
        let change = { controlsVisible.toggle() }
        if reduceMotion { change() } else { withAnimation(.easeOut(duration: 0.16), change) }
    }

    private func loadLargeImage() {
        guard !isLoadingLargeImage else { return }
        isLoadingLargeImage = true
        let store = database
        let id = attachmentID
        let targetPixels = ImageViewerPolicy.currentMaxPixelSize

        DispatchQueue.global(qos: .userInitiated).async {
            let decoded: UIImage? = autoreleasepool {
                guard let data = store.loadAttachment(id: id) else { return nil }
                return ImagePreviewCache.downsample(data: data, maxPixelSize: targetPixels)
            }
            DispatchQueue.main.async {
                if let decoded { image = decoded }
                isLoadingLargeImage = false
            }
        }
    }
}
