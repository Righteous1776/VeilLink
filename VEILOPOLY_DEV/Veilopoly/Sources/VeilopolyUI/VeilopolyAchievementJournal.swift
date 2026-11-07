#if os(iOS) && canImport(SwiftUI)
import SwiftUI
import VeilopolyEngine

/// Presentable from the independent, phase-agnostic asset browser.
struct VeilopolyAchievementJournal: View {
 let game: GameState
 let player: Int
 @Environment(\.dismiss) private var dismiss

 private var entries: [VeilopolyAchievement] {
  VeilopolyAchievements.entries(in: game, player: player)
 }
 private var playerName: String {
  game.players.indices.contains(player) ? game.players[player].name : "未知席位"
 }

 var body: some View {
  NavigationView {
   List {
    Section {
     Text("\(playerName) · 已达成 \(entries.filter(\.unlocked).count) / \(entries.count)")
      .font(.headline)
     Text("由本局有效行动记录及当前资产实时推导。历史里程碑永久计入本局；资产类目标在出售、交易或破产后可能重新锁定。没有奖励货币，也不修改对局。")
      .font(.caption).foregroundColor(.secondary)
    }
    milestoneSection("行动里程碑", items: entries.filter(\.historical))
    milestoneSection("当前资产目标", items: entries.filter { !$0.historical })
   }
   .navigationTitle("成就档案")
   .navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement: .confirmationAction) {
     Button("返回资产") { dismiss() }
      .frame(minHeight: 44)
    }
   }
  }
  .navigationViewStyle(.stack)
 }

 @ViewBuilder
 private func milestoneSection(_ title: String, items: [VeilopolyAchievement]) -> some View {
  Section(header: Text(title)) {
   ForEach(items) { item in
    VStack(alignment: .leading, spacing: 5) {
     HStack {
      Image(systemName: item.unlocked ? "checkmark.seal.fill" : "circle.dotted")
       .foregroundColor(item.unlocked ? .green : .secondary)
      Text(item.title).font(.subheadline.weight(.semibold))
      Spacer(minLength: 4)
      Text("\(item.displayedProgress)/\(item.requirement)")
       .font(.caption.monospacedDigit()).foregroundColor(.secondary)
     }
     Text(item.detail).font(.caption).foregroundColor(.secondary)
     ProgressView(value: Double(item.displayedProgress), total: Double(item.requirement))
      .accessibilityLabel(item.title + "进度")
      .accessibilityValue("\(item.displayedProgress) / \(item.requirement)")
    }
    .padding(.vertical, 3)
    .accessibilityElement(children: .contain)
   }
  }
 }
}
#endif
