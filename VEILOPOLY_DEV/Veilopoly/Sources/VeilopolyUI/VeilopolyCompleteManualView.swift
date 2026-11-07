#if os(iOS) && canImport(SwiftUI)
import SwiftUI
import VeilopolyEngine

/// Child screen of the existing City Player Handbook; never modifies game.
struct VeilopolyCompleteManualView: View {
 let game: GameState
 @State private var query = ""
 @State private var chapter = "all"
 @Environment(\.veilopolyInterfaceTheme) private var theme

 private var results: [VeilopolyCompleteManualEntry] {
  VeilopolyCompleteManual.search(query, in: chapter == "all" ? nil : chapter)
 }
 var body: some View {
  ScrollView {
   LazyVStack(alignment: .leading, spacing: 14) {
    VStack(alignment: .leading, spacing: 5) {
     Text("城市玩家完整说明书")
      .font(.system(size: 23, weight: .semibold, design: .serif))
     Text(VeilopolyCompleteManual.edition)
      .font(.caption.monospaced())
     Text(VeilopolyCompleteManual.currentProfile(game.banking?.financeRuleVersion))
      .font(.subheadline.weight(.medium))
     Text(VeilopolyCompleteManual.deploymentStatus)
      .font(.caption).foregroundStyle(.secondary)
    }.frame(maxWidth: .infinity, alignment: .leading)

    TextField("搜索：贷款、免费建房、VTL、债权、木板路……", text: $query)
     .textFieldStyle(.roundedBorder)
     .accessibilityLabel("搜索完整规则说明书")
    Picker("阅读章节", selection: $chapter) {
     Text("全部章节").tag("all")
     ForEach(VeilopolyCompleteManual.chapters) { part in
      Text(part.title).tag(part.id)
     }
    }.pickerStyle(.menu)
    Text("本次筛选 \(results.count) 条 · 只读手册")
     .font(.caption).foregroundStyle(.secondary)
    if results.isEmpty {
     Text("没有找到相关条目，请简化搜索词或选择全部章节。")
      .font(.footnote).padding(.vertical, 12)
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
        .font(.caption2).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }.padding(.top, 8)
     } label: {
      VStack(alignment: .leading, spacing: 3) {
       Text(entry.title)
        .font(.system(size: 16, weight: .semibold, design: .serif))
       Text(entry.subtitle)
        .font(.caption).foregroundStyle(.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading)
     }
     .tint(Color(red: 0.69, green: 0.52, blue: 0.29))
     .padding(12)
     .background(theme.paper.color, in: RoundedRectangle(cornerRadius: 12))
    }
   }.padding(16)
    .frame(maxWidth: 820)
    .frame(maxWidth: .infinity)
  }
  .background(theme.paperSurround.color.ignoresSafeArea())
  .navigationBarTitle("完整规则说明书", displayMode: .inline)
 }
}
#endif
