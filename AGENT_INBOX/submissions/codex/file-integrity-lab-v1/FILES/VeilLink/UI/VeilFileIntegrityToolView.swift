import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct VeilFileIntegrityToolView: View {
    private enum Slot: Equatable {
        case first
        case second
    }

    @State private var first: VeilFileIntegrityResult?
    @State private var second: VeilFileIntegrityResult?
    @State private var importingSlot: Slot?
    @State private var busySlot: Slot?
    @State private var showsImporter = false
    @State private var copiedReport = false
    @State private var errorText: String?
    @State private var inspectionTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                introCard
                fileCard(title: "文件 A", slot: .first, result: first)
                fileCard(title: "文件 B · 可选", slot: .second, result: second)

                if let first, let second {
                    comparisonCard(first: first, second: second)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(VeilTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    copyReport()
                } label: {
                    Label(
                        copiedReport ? "校验报告已复制" : "复制校验报告",
                        systemImage: copiedReport ? "checkmark.circle.fill" : "doc.on.doc"
                    )
                }
                .buttonStyle(VeilGamePrimaryButtonStyle())
                .disabled(first == nil || busySlot != nil)

                Label(
                    "文件只会在本机以 512 KiB 分块读取；不会上传、修改或长期保存。复制的报告不含文件路径，并在 5 分钟后从本机剪贴板过期。",
                    systemImage: "lock.shield.fill"
                )
                .font(.caption)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .animation(
                VeilMotionPolicy.animation(.transit, reduceMotionRequested: reduceMotion),
                value: comparisonKey
            )
        }
        .background(VeilAmbientBackground())
        .navigationTitle("文件完整性")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            guard let slot = importingSlot else { return }
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                inspect(url: url, into: slot)
            case .failure(let error):
                errorText = error.localizedDescription
            }
        }
        .onDisappear {
            inspectionTask?.cancel()
            inspectionTask = nil
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("确认文件有没有变化", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundColor(VeilTheme.goldBright)
            Text("选择一份文件生成 SHA-256 指纹；再选第二份即可判断两次传输、备份或下载得到的文件是否逐字节一致。")
                .font(.subheadline)
                .foregroundColor(VeilTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .veilCard(emphasized: true)
    }

    private func fileCard(
        title: String,
        slot: Slot,
        result: VeilFileIntegrityResult?
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(VeilTheme.text)
                Spacer()
                if busySlot == slot {
                    ProgressView()
                        .tint(VeilTheme.gold)
                        .accessibilityLabel("正在读取文件")
                } else if result != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(VeilTheme.success)
                }
            }

            if let result {
                Text(result.fileName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(VeilTheme.text)
                    .lineLimit(2)
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: result.byteCount, countStyle: .file))
                    Spacer()
                    Text("\(result.byteCount) bytes")
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(VeilTheme.secondaryText)
                Text(result.sha256)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(VeilTheme.goldBright)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(busySlot == slot ? "正在分块计算 SHA-256…" : "尚未选择文件")
                    .font(.subheadline)
                    .foregroundColor(VeilTheme.secondaryText)
            }

            HStack(spacing: 9) {
                Button(result == nil ? "选择文件" : "替换文件") {
                    importingSlot = slot
                    showsImporter = true
                }
                .buttonStyle(VeilGameSecondaryButtonStyle())
                .disabled(busySlot != nil)

                if result != nil {
                    Button("清除") { clear(slot) }
                        .buttonStyle(VeilGameSecondaryButtonStyle())
                        .disabled(busySlot != nil)
                }
            }
        }
        .veilCard()
    }

    private func comparisonCard(
        first: VeilFileIntegrityResult,
        second: VeilFileIntegrityResult
    ) -> some View {
        let identical = VeilFileIntegrityEngine.compare(first, second) == .identical
        return HStack(spacing: 12) {
            Image(systemName: identical ? "equal.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(identical ? VeilTheme.success : VeilTheme.danger)
            VStack(alignment: .leading, spacing: 4) {
                Text(identical ? "两份文件完全一致" : "两份文件不一致")
                    .font(.headline)
                    .foregroundColor(VeilTheme.text)
                Text(identical
                     ? "字节数和 SHA-256 均相同。"
                     : differenceSummary(first: first, second: second))
                    .font(.caption)
                    .foregroundColor(VeilTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .veilCard(emphasized: identical)
        .accessibilityElement(children: .combine)
    }

    private var comparisonKey: String {
        [first?.sha256, second?.sha256].compactMap { $0 }.joined(separator: ":")
    }

    private func differenceSummary(
        first: VeilFileIntegrityResult,
        second: VeilFileIntegrityResult
    ) -> String {
        if first.byteCount != second.byteCount {
            return "文件大小相差 \(abs(first.byteCount - second.byteCount)) 字节。"
        }
        return "文件大小相同，但内容指纹不同。"
    }

    private func inspect(url: URL, into slot: Slot) {
        inspectionTask?.cancel()
        errorText = nil
        copiedReport = false
        busySlot = slot

        inspectionTask = Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try VeilFileIntegrityEngine.inspect(url: url)
                }.value
                try Task.checkCancellation()
                if slot == .first {
                    first = result
                } else {
                    second = result
                }
            } catch is CancellationError {
                return
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? "文件校验失败。"
            }
            if !Task.isCancelled { busySlot = nil }
        }
    }

    private func clear(_ slot: Slot) {
        copiedReport = false
        errorText = nil
        if slot == .first {
            first = nil
        } else {
            second = nil
        }
    }

    private func copyReport() {
        guard let first else { return }
        let report = VeilFileIntegrityEngine.report(first: first, second: second)
        VeilFileIntegrityClipboard.copy(report)
        copiedReport = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedReport = false
        }
    }
}

private enum VeilFileIntegrityClipboard {
    static func copy(_ text: String) {
        guard !text.isEmpty else { return }
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: text]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(5 * 60)
            ]
        )
    }
}
