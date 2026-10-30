import SwiftUI

/// Candidate standalone screen: NOT wired into GameLobbyView until P0 touch fixes are accepted.
struct VeilStoryLabView: View {
    @State private var selectedBook: VeilStoryBook?
    @State private var run: VeilStoryRun?
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("VEIL TALES · 离线互动剧场")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("三部原创短篇 · 分支决策 · 道具与线索 · 多结局 · 可重玩")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let book = selectedBook, let currentRun = run,
                   let scene = book.scene(id: currentRun.sceneID) {
                    sessionSection(book: book, run: currentRun, scene: scene)
                } else {
                    ForEach(VeilStoryLibrary.books) { book in
                        Button {
                            do {
                                let newRun = try VeilStoryRun(book: book)
                                selectedBook = book
                                run = newRun
                                errorText = nil
                            } catch { errorText = "剧本校验失败，无法开始。" }
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                Text(book.title).font(.headline)
                                Text(book.description).font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.secondary.opacity(0.10))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let errorText = errorText {
                    Text(errorText).foregroundColor(.red).font(.footnote)
                }
            }
            .padding(16)
        }
        .navigationTitle("互动剧场")
    }

    private func sessionSection(book: VeilStoryBook, run currentRun: VeilStoryRun,
                                scene: VeilStoryScene) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(book.title).font(.headline)
                Spacer()
                Text("探索分 \(currentRun.score)")
                    .font(.caption.monospacedDigit())
            }
            Text(scene.title).font(.title3.bold())
            Text(scene.narrative).font(.body).fixedSize(horizontal: false, vertical: true)
            if !currentRun.items.isEmpty {
                Text("线索：\(currentRun.items.sorted().joined(separator: " · "))")
                    .font(.caption).foregroundColor(.secondary)
            }
            if let ending = scene.ending {
                Text(ending).font(.headline)
                Button("再玩一次") {
                    self.run = try? VeilStoryRun(book: book)
                }
                .buttonStyle(.borderedProminent)
            } else {
                ForEach(currentRun.availableChoices(in: book)) { choice in
                    Button(choice.label) {
                        guard var snapshot = self.run else { return }
                        do {
                            try snapshot.choose(choice.id, in: book)
                            self.run = snapshot
                        } catch {
                            errorText = "当前选项不可用，请重新选择。"
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack {
                Button("返回剧本列表") { selectedBook = nil; self.run = nil }
                Spacer()
                Text("第 \(currentRun.history.count) 步")
                    .foregroundColor(.secondary).font(.caption)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(16)
    }
}
