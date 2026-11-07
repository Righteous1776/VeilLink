#if os(iOS) && canImport(SwiftUI)
import SwiftUI
import VeilopolyEngine

/// Integrated, searchable ivory book. A native iOS 15 sheet, not a detached
/// floating board overlay. Does not mutate game state or create another store.
struct VeilopolyGuideSheet: View {
 @Binding var isPresented: Bool
 let game: GameState
 let saveSummary: String
 @State private var search: String = ""
 @State private var fullManual = true
 @Environment(\.veilopolyInterfaceTheme) private var interfaceTheme
 private var ink: Color { interfaceTheme.ink.color }
 private var secondaryInk: Color { interfaceTheme.secondaryInk.color }
 private var gold: Color { interfaceTheme.goldInk.color }
 private var ivory: Color { interfaceTheme.paper.color }

 private var results: [VeilopolyGuideTopic] {
  VeilopolyGuideLibrary.filtered(search)
 }
 private var completeSections: [VeilopolyManualSection] {
  VeilopolyCompleteManual.filtered(search)
 }

 var body: some View {
  NavigationView {
   ScrollView {
    LazyVStack(alignment: .leading, spacing: 14) {
     VStack(alignment: .leading, spacing: 6) {
      Label("城市玩家手册", systemImage: "book.closed")
       .font(.system(size: 22, weight: .semibold, design: .serif))
       .foregroundColor(ink)
      Text(VeilopolyGuideLibrary.status(game))
       .font(.caption)
       .foregroundColor(secondaryInk)
      Text(saveSummary)
       .font(.caption2)
       .foregroundColor(secondaryInk)
       .fixedSize(horizontal: false, vertical: true)
     }
     .frame(maxWidth: .infinity, alignment: .leading)
     NavigationLink(destination: VeilopolyCompleteManualView(game: game)) {
      VStack(alignment: .leading, spacing: 5) {
       Label("完整规则说明书", systemImage: "books.vertical.fill")
        .font(.system(size: 17, weight: .semibold, design: .serif))
        .foregroundColor(ink)
       Text("13 章 · 162 条完整说明 · 40 格地块 · 32 张事件卡")
        .font(.caption)
        .foregroundColor(secondaryInk)
       Text("支持中文关键词搜索与章节筛选；只读，不会改变本局资产。")
        .font(.caption2).foregroundColor(secondaryInk)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(ivory, in: RoundedRectangle(cornerRadius: 12))
      .overlay {
       RoundedRectangle(cornerRadius: 12)
        .strokeBorder(gold.opacity(0.65), lineWidth: 1)
        .allowsHitTesting(false)
      }
     }
     .buttonStyle(.plain)
     .accessibilityHint("打开完整规则说明书，查看并搜索所有规则条目")
     Picker("说明书阅读模式", selection: $fullManual) {
      Text("完整说明书").tag(true)
      Text("玩法辞典").tag(false)
     }
     .pickerStyle(.segmented)
     .accessibilityLabel("切换完整说明书与玩法辞典")
     TextField("搜索：银行、破产、股票、卡牌……", text: $search)
      .textFieldStyle(.roundedBorder)
      .accessibilityLabel("搜索玩法辞典")
     if fullManual {
      Text("规则依据 " + VeilopolyCompleteManual.edition + " · 新旧模式金额以当前对局为准")
       .font(.caption2)
       .foregroundColor(secondaryInk)
      if completeSections.isEmpty {
       Text("完整说明书没有匹配的章节，请改用「货币」「贷款」「租金」「债权」等关键词。")
        .font(.callout)
        .foregroundColor(ink)
        .padding(.vertical, 10)
      }
      ForEach(completeSections) { section in
       VStack(alignment: .leading, spacing: 10) {
        Text(section.heading)
         .font(.system(size: 16, weight: .semibold, design: .serif))
         .foregroundColor(ink)
         .fixedSize(horizontal: false, vertical: true)
        Divider().overlay(gold.opacity(0.5))
        Text((try? AttributedString(markdown: section.body)) ?? AttributedString(section.body))
         .font(.system(size: 12))
         .foregroundColor(ink)
         .textSelection(.enabled)
         .fixedSize(horizontal: false, vertical: true)
       }
       .frame(maxWidth: .infinity, alignment: .leading)
       .padding(12)
       .background(ivory, in: RoundedRectangle(cornerRadius: 12))
       .overlay {
        RoundedRectangle(cornerRadius: 12)
         .strokeBorder(gold.opacity(0.65), lineWidth: 1)
         .allowsHitTesting(false)
       }
       .accessibilityElement(children: .contain)
      }
     } else {
     if results.isEmpty {
      Text("没有找到相关条目。可尝试「地契」「出狱」「银行」或「续局」。")
       .font(.callout)
       .foregroundColor(ink)
       .padding(.vertical, 12)
     }
     ForEach(VeilopolyGuideChapter.allCases, id: \.self) { chapter in
      let chapterTopics = results.filter { $0.chapter == chapter }
      if !chapterTopics.isEmpty {
       VStack(alignment: .leading, spacing: 9) {
        Text(chapter.title)
         .font(.system(size: 17, weight: .semibold, design: .serif))
         .foregroundColor(ink)
         .padding(.top, 6)
        ForEach(chapterTopics) { topic in
         VStack(alignment: .leading, spacing: 6) {
          Text(topic.title)
           .font(.system(size: 15, weight: .semibold, design: .serif))
           .foregroundColor(ink)
          Text(topic.subtitle)
           .font(.system(size: 12, weight: .medium))
           .foregroundColor(gold)
          Text(topic.detail)
           .font(.system(size: 13))
           .foregroundColor(ink)
           .fixedSize(horizontal: false, vertical: true)
          Text(topic.footnote)
           .font(.system(size: 11))
           .foregroundColor(secondaryInk)
           .fixedSize(horizontal: false, vertical: true)
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(12)
         .background(ivory, in: RoundedRectangle(cornerRadius: 12))
         .overlay {
          RoundedRectangle(cornerRadius: 12)
           .strokeBorder(gold.opacity(0.75), lineWidth: 1)
           .allowsHitTesting(false)
         }
         .accessibilityElement(children: .combine)
        }
       }
      }
     }
     }
     Text("文本版本：" + (fullManual ? VeilopolyCompleteManual.edition : VeilopolyGuideLibrary.edition) + " · 只读，不改动对局数据")
      .font(.system(size: 10))
      .foregroundColor(secondaryInk)
    }
    .padding(16)
    .frame(maxWidth: 740)
    .frame(maxWidth: .infinity)
   }
   .background(interfaceTheme.paperSurround.color.ignoresSafeArea())
   .navigationBarTitle("玩法辞典", displayMode: .inline)
   .toolbar {
    ToolbarItem(placement: .confirmationAction) {
     Button("完成") { isPresented = false }
      .accessibilityHint("关闭辞典，返回当前对局")
    }
   }
  }
  .navigationViewStyle(.stack)
  .preferredColorScheme(interfaceTheme.colorScheme)
 }
}
#endif
