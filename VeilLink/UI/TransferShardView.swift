import Foundation
import SwiftUI
import UIKit

enum TransferShardMode: Equatable {
    case sending
    case receiving
}

enum TransferShardPhase: Equatable {
    case active
    case failed
}

enum TransferShardImageFactory {
    static let columns = 5
    static let rows = 6

    static func makeShards(from image: UIImage) -> [UIImage] {
        guard image.imageOrientation == .up, let cgImage = image.cgImage else { return [] }
        let width = cgImage.width
        let height = cgImage.height
        guard width >= columns, height >= rows else { return [] }

        var result: [UIImage] = []
        result.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let x0 = column * width / columns
                let x1 = (column + 1) * width / columns
                let y0 = row * height / rows
                let y1 = (row + 1) * height / rows
                let rect = CGRect(
                    x: CGFloat(x0),
                    y: CGFloat(y0),
                    width: CGFloat(max(1, x1 - x0)),
                    height: CGFloat(max(1, y1 - y0))
                )
                guard let cropped = cgImage.cropping(to: rect) else { return [] }
                result.append(UIImage(cgImage: cropped, scale: image.scale, orientation: .up))
            }
        }
        return result
    }
}

struct TransferShardView: View {
    let image: UIImage?
    let shardImages: [UIImage]?
    let progress: Double
    let mode: TransferShardMode
    let phase: TransferShardPhase

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = TransferShardImageFactory.columns
    private let rows = TransferShardImageFactory.rows

    init(
        image: UIImage?,
        shardImages: [UIImage]? = nil,
        progress: Double,
        mode: TransferShardMode,
        phase: TransferShardPhase = .active
    ) {
        self.image = image
        self.shardImages = shardImages
        self.progress = progress
        self.mode = mode
        self.phase = phase
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var visualProgress: Double {
        if phase == .failed, mode == .sending { return 0 }
        return clampedProgress
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                VeilPanelShape(cut: 16, radius: 8)
                    .fill(VeilTheme.panel)

                LinearGradient(
                    colors: mode == .sending
                        ? [Color.clear, VeilTheme.gold.opacity(0.075)]
                        : [VeilTheme.gold.opacity(0.075), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                if !reduceMotion && phase == .active {
                    ForEach(Array(stride(from: 0, to: columns * rows, by: 4)), id: \.self) { index in
                        shardTrail(index: index, in: size)
                    }
                }

                ForEach(0..<(columns * rows), id: \.self) { index in
                    shard(index: index, in: size)
                }

                transferOverlay
            }
            .clipShape(VeilPanelShape(cut: 16, radius: 8))
            .overlay(alignment: .bottom) {
                GeometryReader { barGeometry in
                    Group {
                        if phase == .failed {
                            Capsule().fill(VeilTheme.danger)
                        } else {
                            Capsule().fill(VeilTheme.goldGradient)
                        }
                    }
                        .frame(width: max(8, barGeometry.size.width * CGFloat(clampedProgress)), height: 2)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .opacity(clampedProgress < 1 || phase == .failed ? 0.92 : 0)
                }
                .frame(height: 2)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .overlay(
                VeilPanelShape(cut: 16, radius: 8)
                    .stroke(borderColor, lineWidth: phase == .failed ? 1.4 : 1)
            )
            .overlay(alignment: .topLeading) {
                HStack(spacing: 7) {
                    Text(mode == .sending ? "TX" : "RX")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(VeilTheme.mutedGold)
                    VeilLinkTrace(active: phase == .active && clampedProgress < 1, width: 42)
                }
                .padding(.leading, 11)
                .padding(.top, 8)
                .opacity(clampedProgress < 1 || phase == .failed ? 0.92 : 0)
            }
            .shadow(color: phase == .failed ? VeilTheme.danger.opacity(0.10) : VeilTheme.gold.opacity(clampedProgress < 1 ? 0.10 : 0), radius: 12, x: 0, y: 6)
            .animation(reduceMotion ? nil : .interactiveSpring(response: 0.40, dampingFraction: phase == .failed ? 0.70 : 0.82), value: progressBucket)
            .animation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.68), value: phase)
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(phase == .failed ? "传输已中断" : "\(Int(clampedProgress * 100))%")
    }

    @ViewBuilder
    private func shard(index: Int, in size: CGSize) -> some View {
        let rect = shardRect(index: index, in: size)
        let threshold = shardAmount(index: index)
        let visible = visibleFraction(for: threshold)
        let vector = shardVector(index: index, amount: visible)

        shardContent(index: index, fullSize: size, shardRect: rect)
            .frame(width: rect.width + 0.8, height: rect.height + 0.8)
            .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
            .position(x: rect.midX, y: rect.midY)
            .opacity(shardOpacity(visible: visible))
            .scaleEffect(reduceMotion ? 1 : shardScale(visible: visible))
            .rotationEffect(reduceMotion ? .zero : .degrees(vector.rotation))
            .offset(x: reduceMotion ? 0 : vector.x, y: reduceMotion ? 0 : vector.y)
            .shadow(color: VeilTheme.gold.opacity(trailIntensity(visible: visible) * 0.28), radius: 3)
    }

    @ViewBuilder
    private func shardContent(index: Int, fullSize: CGSize, shardRect: CGRect) -> some View {
        if let shardImages, shardImages.count == columns * rows {
            Image(uiImage: shardImages[index])
                .resizable()
                .scaledToFill()
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: fullSize.width, height: fullSize.height)
                .offset(x: fullSize.width / 2 - shardRect.midX,
                        y: fullSize.height / 2 - shardRect.midY)
        } else {
            LinearGradient(
                colors: [
                    VeilTheme.gold.opacity(0.86),
                    VeilTheme.mutedGold.opacity(0.62),
                    Color.white.opacity(0.12)
                ],
                startPoint: index.isMultiple(of: 2) ? .topLeading : .bottomTrailing,
                endPoint: index.isMultiple(of: 2) ? .bottomTrailing : .topLeading
            )
            .overlay(Color.black.opacity(Double(index % 5) * 0.035))
        }
    }

    @ViewBuilder
    private func shardTrail(index: Int, in size: CGSize) -> some View {
        let rect = shardRect(index: index, in: size)
        let threshold = shardAmount(index: index)
        let visible = visibleFraction(for: threshold)
        let intensity = trailIntensity(visible: visible)
        let vector = shardVector(index: index, amount: visible)
        let length = max(14, min(58, abs(vector.x) * 0.75 + abs(vector.y) * 0.25))
        let angle = Angle(radians: atan2(Double(vector.y), Double(vector.x)))

        Capsule()
            .fill(
                LinearGradient(
                    colors: [VeilTheme.gold.opacity(0), VeilTheme.gold.opacity(0.74), Color.white.opacity(0.52)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: length, height: 1.35)
            .rotationEffect(angle)
            .position(x: rect.midX + vector.x * 0.42, y: rect.midY + vector.y * 0.42)
            .opacity(intensity * 0.78)
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private var transferOverlay: some View {
        Group {
            if phase == .failed {
                Label("传输中断", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundColor(VeilTheme.danger)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: mode == .sending ? "arrow.up.right" : "arrow.down.left")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(Int(clampedProgress * 100))%")
                        .font(.system(.caption2, design: .monospaced).weight(.semibold))
                }
                .foregroundColor(VeilTheme.gold)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.54))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
        .opacity(clampedProgress < 1 || phase == .failed ? 1 : 0)
        .allowsHitTesting(false)
    }

    private var borderColor: Color {
        if phase == .failed { return VeilTheme.danger.opacity(0.72) }
        return VeilTheme.gold.opacity(clampedProgress < 1 ? 0.26 : 0)
    }

    private var accessibilityLabel: String {
        if phase == .failed { return "图片安全传输已中断" }
        return mode == .sending ? "图片正在安全发送" : "图片正在安全接收"
    }

    private var progressBucket: Int {
        let bucket = Int(visualProgress * Double(columns * rows))
        return phase == .failed ? -1 : bucket
    }

    private func shardRect(index: Int, in size: CGSize) -> CGRect {
        let column = index % columns
        let row = index / columns
        let width = size.width / CGFloat(columns)
        let height = size.height / CGFloat(rows)
        return CGRect(x: CGFloat(column) * width,
                      y: CGFloat(row) * height,
                      width: width,
                      height: height)
    }

    private func shardAmount(index: Int) -> Double {
        let count = columns * rows
        let mixed = (index * 17 + 11) % count
        let normalized = count > 1 ? Double(mixed) / Double(count - 1) : 0.5
        return 0.05 + normalized * 0.90
    }

    private func visibleFraction(for threshold: Double) -> Double {
        let feather = 0.10
        switch mode {
        case .sending:
            return min(max((threshold - visualProgress) / feather + 0.5, 0), 1)
        case .receiving:
            return min(max((visualProgress - threshold) / feather + 0.5, 0), 1)
        }
    }

    private func trailIntensity(visible: Double) -> Double {
        guard phase == .active else { return 0 }
        return max(0, 1 - abs(visible - 0.5) * 2)
    }

    private func shardOpacity(visible: Double) -> Double {
        if reduceMotion { return visible > 0.15 ? 1 : 0 }
        return min(max(visible, 0), 1)
    }

    private func shardScale(visible: Double) -> CGFloat {
        switch mode {
        case .sending:
            return 0.72 + CGFloat(visible) * 0.28
        case .receiving:
            return 0.82 + CGFloat(visible) * 0.18
        }
    }

    private func shardVector(index: Int, amount: Double) -> (x: CGFloat, y: CGFloat, rotation: Double) {
        let escaped = 1 - amount
        let lane = CGFloat((index * 13 + 5) % 11) - 5
        let vertical = lane * 4.2 * CGFloat(escaped)
        let horizontalBase: CGFloat = 44 + CGFloat((index * 7) % 5) * 7
        let sign: CGFloat = mode == .sending ? 1 : -1
        let horizontal = sign * horizontalBase * CGFloat(escaped)
        let rotationSign: Double = index.isMultiple(of: 2) ? 1 : -1
        let rotation = rotationSign * Double(escaped) * Double(8 + (index % 4) * 3)
        return (horizontal, vertical, rotation)
    }
}
