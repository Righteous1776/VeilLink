import SwiftUI
import UniformTypeIdentifiers

/// User-operated, offline-only HTML reading surface.
struct VeilOfflineHTMLReaderView: View {
    @State private var showingImporter = false
    @State private var document: VeilOfflineHTMLDocument?
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorDescription: String?
    @State private var importGeneration = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("离线 HTML 资料阅读", systemImage: "doc.richtext")
                        .font(.title3.bold())
                    Text("从“文件”导入已保存的 HTML。只抽取标题、正文和链接；不会执行脚本、访问网络或将文件写入聊天数据库。")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Button {
                    showingImporter = true
                } label: {
                    Label("选择 HTML 文件", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                if isLoading { ProgressView("正在本机解析…") }
                if let errorDescription {
                    Label(errorDescription, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundColor(.red)
                }
                if let document {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(document.title).font(.headline)
                            .accessibilityIdentifier("offlineHTML.title")
                        Text("\(document.sections.count) 段 · \(document.links.count) 条链接")
                            .font(.caption).foregroundColor(.secondary)
                        if document.truncated {
                            Text("为兼容较旧的 iPhone，超出安全长度的内容已截断。")
                                .font(.caption).foregroundColor(.orange)
                        }
                        TextField("在当前资料内搜索", text: $query)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("offlineHTML.search")
                        let visible = document.matchingSections(query: query)
                        if visible.isEmpty { Text("没有匹配的正文。").foregroundColor(.secondary) }
                        ForEach(Array(visible.enumerated()), id: \.offset) { _, section in
                            Text(section)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .font(.body)
                                .padding(10)
                                .background(Color.secondary.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        if !query.isEmpty, visible.count == VeilHTMLImportPolicy.maximumSearchResults {
                            Text("搜索结果最多显示 100 段，请进一步缩小关键词。")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Button("复制当前可见正文") {
                            let text = visible.joined(separator: "\n\n")
                            VeilToolClipboard.copy(VeilHTMLImportPolicy.bounded(text))
                        }
                        .buttonStyle(.bordered)
                        .disabled(visible.isEmpty)

                        if !document.links.isEmpty {
                            Text("文档中的外部网址（只读）").font(.headline)
                            Text("不会自动访问这些链接。需要时可选中文本，手动复制地址。")
                                .font(.caption).foregroundColor(.secondary)
                            ForEach(document.links) { link in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(link.label).font(.subheadline.weight(.semibold))
                                    Text(link.address)
                                        .font(.caption.monospaced())
                                        .textSelection(.enabled)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Button("清除已导入的临时内容") {
                            importGeneration = UUID()
                            self.document = nil
                            self.query = ""
                            self.errorDescription = nil
                        }.buttonStyle(.borderless)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("离线资料阅读器")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.html, UTType(filenameExtension: "htm") ?? .html],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .failure:
                errorDescription = "无法获取所选文件；请检查文件访问权限。"
            case .success(let urls):
                guard let url = urls.first else { return }
                let token = UUID()
                importGeneration = token
                isLoading = true
                document = nil
                query = ""
                errorDescription = nil
                Task {
                    do {
                        let parsed = try await Task.detached(priority: .userInitiated) {
                            try VeilOfflineHTMLImporter.load(fileURL: url)
                        }.value
                        guard importGeneration == token else { return }
                        document = parsed
                    } catch {
                        guard importGeneration == token else { return }
                        errorDescription = (error as? LocalizedError)?.errorDescription ?? "HTML 导入失败。"
                    }
                    if importGeneration == token { isLoading = false }
                }
            }
        }
        .onDisappear {
            importGeneration = UUID()
            document = nil
            query = ""
            isLoading = false
        }
    }
}
