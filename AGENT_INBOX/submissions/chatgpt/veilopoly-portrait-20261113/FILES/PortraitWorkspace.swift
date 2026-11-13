#if os(iOS) && canImport(SwiftUI)
import Foundation
import SwiftUI
import VeilopolyEngine

private enum VeilopolyPortraitWidget: String, CaseIterable, Identifiable {
 case cash = "我的现金"
 case market = "模拟股票"
 case bank = "银行利息"
 case estate = "地产"
 case loan = "贷款"
 case link = "连接状态"

 var id: String { rawValue }
 var symbol: String {
  switch self {
  case .cash: return "yensign.circle"
  case .market: return "chart.xyaxis.line"
  case .bank: return "building.columns"
  case .estate: return "house"
  case .loan: return "creditcard"
  case .link: return "antenna.radiowaves.left.and.right"
  }
 }
}

/// Portrait's top half is the board. The lower half is either a scrolling
/// control drawer or a configurable READ-ONLY dashboard plus a long-press die.
/// The same GameSessionModel/GameBoardScene stays mounted in both layouts.
@MainActor
struct VeilopolyPortraitWorkspace<BoardContent: View, DrawerContent: View>: View {
 @ObservedObject private var model: GameSessionModel
 @Binding private var workspace: VeilopolyPanelWorkspace
 private let reduceMotion: Bool
 private let board: BoardContent
 private let drawer: DrawerContent
 private let onOpenAssets: (VeilopolyManagementSection) -> Void
 private let onExit: () -> Void
 @AppStorage("veilopoly.portrait.cards.v1") private var visibleWidgetCodes = "我的现金,模拟股票,银行利息,地产"
 private var visibleWidgets: Set<VeilopolyPortraitWidget> {
  Set(visibleWidgetCodes.split(separator: ",").compactMap {
   VeilopolyPortraitWidget(rawValue: String($0))
  })
 }
 private func toggleWidget(_ item: VeilopolyPortraitWidget) {
  var next = visibleWidgets
  if next.contains(item) { next.remove(item) } else { next.insert(item) }
  visibleWidgetCodes = VeilopolyPortraitWidget.allCases
   .filter { next.contains($0) }.map(\.rawValue).joined(separator: ",")
 }

 init(model: GameSessionModel, workspace: Binding<VeilopolyPanelWorkspace>,
      reduceMotion: Bool, board: BoardContent, drawer: DrawerContent,
      onOpenAssets: @escaping (VeilopolyManagementSection) -> Void,
      onExit: @escaping () -> Void) {
  _model = ObservedObject(wrappedValue: model)
  _workspace = workspace
  self.reduceMotion = reduceMotion
  self.board = board
  self.drawer = drawer
  self.onOpenAssets = onOpenAssets
  self.onExit = onExit
 }

 var body: some View {
  GeometryReader { size in
   let split = VeilopolyPortraitLayout.allocate(
    availableWidth: Double(size.size.width), availableHeight: Double(size.size.height))
   VStack(spacing: 0) {
    board
     .frame(width: size.size.width, height: CGFloat(split.boardHeight))
    Rectangle()
     .fill(Color(red: 0.73, green: 0.57, blue: 0.34))
     .frame(height: 1).allowsHitTesting(false)
    ZStack {
     compactDashboard
      .opacity(workspace.isExpanded ? 0 : 1)
      .allowsHitTesting(!workspace.isExpanded)
      .accessibilityHidden(workspace.isExpanded)
     drawer
      .opacity(workspace.isExpanded ? 1 : 0)
      .allowsHitTesting(workspace.isExpanded)
      .accessibilityHidden(!workspace.isExpanded)
    }
    .frame(width: size.size.width, height: max(0, CGFloat(split.workspaceHeight) - 1))
   }
   .frame(width: size.size.width, height: size.size.height)
  }
  .onAppear {
   // Start expanded in portrait. Subsequent collapses don't reconstruct
   // the drawer, so scrolling and draft input remain intact.
   if !workspace.isExpanded { workspace.open() }
  }
 }

 private var compactDashboard: some View {
  VStack(spacing: 4) {
   HStack(spacing: 8) {
    Text("我的城市仪表盘")
     .font(.subheadline.weight(.semibold))
    Spacer(minLength: 1)
    Menu {
     ForEach(VeilopolyPortraitWidget.allCases) { item in
      Button {
       toggleWidget(item)
      } label: {
       Label(item.rawValue, systemImage: visibleWidgets.contains(item)
             ? "checkmark.circle.fill" : "circle")
      }
     }
    } label: {
     Label("组件", systemImage: "slider.horizontal.3")
      .font(.caption.weight(.medium)).frame(minWidth: 70, minHeight: 44)
    }
    .accessibilityLabel("选择仪表盘组件")
    Menu {
     Button("资产资料", action: { onOpenAssets(.property) })
     Button("退出游戏", role: .destructive, action: onExit)
    } label: {
     Image(systemName: "ellipsis").frame(width: 44, height: 44)
    }
    .accessibilityLabel("更多与退出")
   }
   .padding(.horizontal, 10)
   ScrollView {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
              spacing: 8) {
     ForEach(VeilopolyPortraitWidget.allCases) { item in
      if visibleWidgets.contains(item) {
       widgetCard(item)
      }
     }
    }
    .padding(.horizontal, 10)
    HStack(spacing: 8) {
     Button { onOpenAssets(.market) } label: {
      Label("股票行情", systemImage: "chart.line.uptrend.xyaxis")
       .frame(maxWidth: .infinity, minHeight: 44)
     }
     Button { onOpenAssets(.bank) } label: {
      Label("银行账户", systemImage: "building.columns")
       .frame(maxWidth: .infinity, minHeight: 44)
     }
    }
    .font(.caption.weight(.medium))
    .buttonStyle(.bordered)
    .padding(.horizontal, 10)
    .padding(.top, 8)
   }
   .frame(maxHeight: .infinity)
   // No roll-on-tap: a long press only expands the panel. This avoids
   // accidental real financial or turn actions while inspecting widgets.
   Image(systemName: "die.face.5.fill")
    .font(.system(size: 34, weight: .semibold))
    .foregroundColor(Color(red: 0.95, green: 0.82, blue: 0.58))
    .frame(width: 64, height: 64)
    .background(Color(red: 0.10, green: 0.30, blue: 0.30),
                in: RoundedRectangle(cornerRadius: 18))
    .contentShape(Rectangle())
    .onLongPressGesture(minimumDuration: 0.55) {
     withAnimation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.88)) {
      workspace.open()
     }
    }
    .accessibilityAddTraits(.isButton)
    .accessibilityLabel("骰子入口，长按展开操作面板")
    .accessibilityAction(named: Text("展开操作面板")) { workspace.open() }
    .padding(.bottom, 4)
  }
  .foregroundColor(.white)
  .background(Color(red: 0.10, green: 0.22, blue: 0.23))
 }

 private func widgetCard(_ widget: VeilopolyPortraitWidget) -> some View {
  let viewer = model.viewingSeat
  let summary = VeilopolyAssetSummary(game: model.game, player: viewer)
  let bank = model.game.banking
  let account = bank.flatMap { ledger in
   ledger.accounts.indices.contains(viewer) ? ledger.accounts[viewer] : nil
  }
  let quote = bank?.market?.quotes.first

  let value: String
  let detail: String
  switch widget {
  case .cash:
   value = "¥\(summary.cash)"
   detail = "我的游戏现金 · 实时"
  case .market:
   value = quote.map {
    String(format: "¥%.2f", Double($0.currentPriceCents) / 100.0)
   } ?? "暂无报价"
   detail = quote.map { "\($0.symbol) · T+\(bank?.market?.tick ?? 0)" } ?? "虚构行情 · 只读"
  case .bank:
   value = bank?.terms.demandYieldBasisPoints.map {
    String(format: "%.2f%%", Double($0) / 100.0)
   } ?? "未设定"
   detail = "本局活期利率 · 存款 ¥\(summary.savings)"
  case .estate:
   value = "¥\(summary.property)"
   detail = "名下 \(model.game.board.filter { $0.owner == viewer }.count) 个地块"
  case .loan:
   value = "¥\(summary.liabilities)"
   detail = "未结清贷款 \(account?.loans.count ?? 0) 笔"
  case .link:
   value = model.isMultiplayer
    ? (model.networkReady ? "已同步" : "等待恢复")
    : "本地离线"
   detail = model.isMultiplayer ? "查看对局面板了解详情" : "单机可用"
  }
  return VStack(alignment: .leading, spacing: 5) {
   Label(widget.rawValue, systemImage: widget.symbol)
    .font(.system(size: 11, weight: .semibold))
    .foregroundColor(Color(red: 0.88, green: 0.73, blue: 0.50))
   Text(value)
    .font(.system(size: 16, weight: .bold, design: .rounded))
    .monospacedDigit()
    .lineLimit(1)
    .minimumScaleFactor(0.72)
   Text(detail)
    .font(.system(size: 10))
    .foregroundStyle(.white.opacity(0.78))
    .lineLimit(2)
    .fixedSize(horizontal: false, vertical: true)
  }
  .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
  .padding(9)
  .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11))
  .accessibilityElement(children: .combine)
 }
}
#endif
