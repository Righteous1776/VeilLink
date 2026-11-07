#if os(iOS) && canImport(SwiftUI)
import SwiftUI
import VeilopolyEngine

/// The existing city player handbook links to this full manual. No duplicate
/// store, no state mutations, and no interactions layered over the board.
struct VeilopolyCompleteManualView: View {
 let game: GameState
 @State private var query = ""
 @State private var selectedChapter = "all"
 @Environment(\.veilopolyInterfaceTheme) private var interfaceTheme
 private var results: [VeilopolyCompleteManualEntry] {
  VeilopolyCompleteManual.search(query, in: selectedChapter == "all" ? nil : selectedChapter)
 }
 var body: some View {
  ScrollView {
   LazyVStack(alignment: .leading, spacing: 15) {
    VStack(alignment: .leading, spacing: 6) {
     Text("城市玩家完整说明书")
      .font(.system(size: 24, weight: .semibold, design: .serif))
     Text(VeilopolyCompleteManual.edition)
      .font(.caption.monospaced())
     Text(VeilopolyCompleteManual.currentProfile(game.banking?.financeRuleVersion))
      .font(.footnote.weight(.semibold))
     Text(VeilopolyCompleteManual.deploymentStatus)
      .font(.caption)
      .fixedSize(horizontal: false, vertical: true)
    }
    TextField("搜索：免费建房、VTL、税费、银行债权……", text: $query)
     .textFieldStyle(.roundedBorder)
     .accessibilityLabel("搜索完整说明书")
    Picker("阅读章节", selection: $selectedChapter) {
     Text("全部章节").tag("all")
     ForEach(VeilopolyCompleteManual.chapters, id: \.id) { item in
      Text(item.title).tag(item.id)
     }
    }
    .pickerStyle(.menu)
    Text("共 \(results.count) 条 · 只读 · 仅供当前研发规则参考")
     .font(.caption2).foregroundStyle(.secondary)
    if results.isEmpty {
     Text("未找到对应条目。建议缩短关键词或选择“全部章节”。")
      .font(.callout).padding(.vertical, 12)
    }
    ForEach(results) { entry in
     DisclosureGroup {
      VStack(alignment: .leading, spacing: 9) {
       ForEach(entry.paragraphs.indices, id: \.self) { i in
        Text(entry.paragraphs[i])
         .font(.system(size: 14))
         .fixedSize(horizontal: false, vertical: true)
       }
       Divider()
       Text("条目 \(entry.id) · 依据：\(entry.evidence)")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.top, 8)
     } label: {
      VStack(alignment: .leading, spacing: 4) {
       Text(entry.title)
        .font(.system(size: 16, weight: .semibold, design: .serif))
       Text(entry.subtitle)
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
     }
     .tint(Color(red: 0.65, green: 0.48, blue: 0.24))
     .padding(13)
     .background(interfaceTheme.paper.color, in: RoundedRectangle(cornerRadius: 12))
    }
   }
   .padding(16)
   .frame(maxWidth: 820)
   .frame(maxWidth: .infinity)
  }
  .background(interfaceTheme.paperSurround.color.ignoresSafeArea())
  .navigationBarTitle("完整规则说明书", displayMode: .inline)
 }
}
#endif