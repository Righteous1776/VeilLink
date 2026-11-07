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
 private let ink = Color(red: 0.11, green: 0.27, blue: 0.28)
 private let gold = Color(red: 0.72, green: 0.56, blue: 0.32)
 private let ivory = Color(red: 0.969, green: 0.946, blue: 0.895)

 private var results: [VeilopolyGuideTopic] {
  VeilopolyGuideLibrary.filtered(search)
 }

 var body: some View {
  NavigationView {
   ScrollView {
    VStack(alignment: .leading, spacing: 14) {
     VStack(alignment: .leading, spacing: 6) {
      Label("城市玩家手册", systemImage: "book.closed")
       .font(.system(size: 22, weight: .semibold, design: .serif))
       .foregroundColor(ink)
      Text(VeilopolyGuideLibrary.status(game))
       .font(.caption)
       .foregroundColor(ink.opacity(0.8))
      Text(saveSummary)
       .font(.caption2)
       .foregroundColor(ink.opacity(0.72))
       .fixedSize(horizontal: false, vertical: true)
     }
     .frame(maxWidth: .infinity, alignment: .leading)
     TextField("搜索：拍卖、股票、存档……", text: $search)
      .textFieldStyle(.roundedBorder)
      .accessibilityLabel("搜索玩法辞典")
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
           .foregroundColor(ink.opacity(0.72))
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
     Text("文本版本：" + VeilopolyGuideLibrary.edition + " · 基于当前研发规则")
      .font(.system(size: 10))
      .foregroundColor(ink.opacity(0.64))
    }
    .padding(16)
    .frame(maxWidth: 740)
    .frame(maxWidth: .infinity)
   }
   .background(Color(red: 0.92, green: 0.89, blue: 0.82).ignoresSafeArea())
   .navigationBarTitle("玩法辞典", displayMode: .inline)
   .toolbar {
    ToolbarItem(placement: .confirmationAction) {
     Button("完成") { isPresented = false }
      .accessibilityHint("关闭辞典，返回当前对局")
    }
   }
  }
  .navigationViewStyle(.stack)
  .preferredColorScheme(.light)
 }
}
#endif
