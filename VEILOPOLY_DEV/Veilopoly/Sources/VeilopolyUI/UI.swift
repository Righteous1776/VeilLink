#if os(iOS) && canImport(SwiftUI) && canImport(SpriteKit)
import SwiftUI
import SpriteKit
import VeilopolyEngine
import VeilopolyAI

@MainActor
public final class GameSessionModel: ObservableObject {
 @Published public private(set) var game: GameState
 @Published public private(set) var errorMessage: String?
 @Published public private(set) var shownCard: String?
 @Published public var selectedTile: Int = 1
 let scene: GameBoardScene
 private var queue: [ViewCommand] = []
 @Published private var animating = false
 private var driving = false
 private let configuredHumanCount: Int

 public init(seed: UInt64 = 1729123, humanCount: Int = 1) {
  configuredHumanCount = humanCount
  let initial = GameFactory.make(seed: seed, humanCount: humanCount)
  game = initial
  scene = GameBoardScene(size: CGSize(width: 1024, height: 940))
  scene.display(initial)
  if humanCount == 0 { Task { @MainActor [weak self] in self?.drive() } }
 }
 public var actor: Int { game.auction?.turn ?? game.trade?.to ?? game.pendingDebt?.player ?? game.turn.player }
 public var waitingForHuman: Bool { !game.players[actor].bankrupt && game.players[actor].kind == .human }
 public var currentContext: GameContext { VeilopolyEngine.context(game) }
 public var pending: Bool { animating }

 public func perform(_ kind: MoveKind, tile: Int? = nil, amount: Int? = nil,
                     to: Int? = nil, offer: TradeTransfer? = nil, request: TradeTransfer? = nil,
                     deck: DeckKind? = nil) {
  guard !animating else { return }
  let move = Move(kind, player: actor, seq: game.nextSeq, tile: tile, amount: amount,
                  to: to, offer: offer, request: request, deck: deck)
  applyMove(move)
  drive()
 }
 private func applyMove(_ move: Move) {
  let result = VeilopolyEngine.apply(game, currentContext, move)
  switch result {
  case .failure(let err): errorMessage = err.rawValue
  case .success((let newState, let effects)):
   errorMessage = nil
   let commands = CommandTranslator.translate(effects)
   game = newState
   scene.display(newState, snapTokens: !effects.contains(where: { $0.kind == .playerMoved }))
   queue.append(contentsOf: commands)
   if !animating { presentNext() }
  }
 }
 private func presentNext() {
  guard !queue.isEmpty else {
   animating = false
   drive()
   return
  }
  animating = true
  let command = queue.removeFirst()
  if case .cardShow(_,let message) = command { shownCard = message }
  scene.play(command) { [weak self] in
   guard let self else { return }
   self.presentNext()
  }
 }
 public func fastForward() { if animating { scene.fastForward() } }
 public func dismissCard() { shownCard = nil }
 public func reset(seed: UInt64) {
  guard !animating else { return }
  let newState = GameFactory.make(seed: seed, humanCount: configuredHumanCount)
  game = newState; shownCard = nil; queue = []; errorMessage = nil
  scene.display(newState)
  if configuredHumanCount == 0 { drive() }
 }
 private func drive() {
  guard !animating && !driving else { return }
  driving = true
  defer { driving = false }
  // All internal and AI moves use the same public pure reducer as human input.
  for _ in 0..<200 {
   if animating || game.winner != nil { return }
   let context = currentContext
   let automatic: Move?
   switch context.phase {
   case .moveAnim: automatic = Move(.applyMovement, player: actor, seq: game.nextSeq)
   case .tileResolve where game.turn.pendingPurchase == nil:
    automatic = Move(.resolveTile, player: actor, seq: game.nextSeq)
   default:
    if !waitingForHuman {
     automatic = VeilopolyAI.decide(game, context, me: actor, level: game.players[actor].aiLevel)
    } else { automatic = nil }
   }
   guard let move = automatic else { return }
   let oldSeq = game.nextSeq
   applyMove(move)
   if game.nextSeq == oldSeq { return }
  }
  errorMessage = "自动回合超过安全步数上限"
 }
}

@MainActor
public struct VeilopolyGameView: View {
 @StateObject private var model: GameSessionModel
 @State private var offerCash = "0"
 @State private var requestCash = "0"
 @State private var bidderCash = "10"
 @State private var tradeTarget = 1
 @State private var chosenOffer: Set<Int> = []
 @State private var chosenRequest: Set<Int> = []
 @State private var showRestart = false
 @State private var showMore = false
 @State private var showExitConfirmation = false
 @State private var showGameInfo = false
 @Environment(\.dismiss) private var dismiss
 private let onExit: (() -> Void)?
 public init(seed: UInt64 = 1729123, humanCount: Int = 1, onExit: (() -> Void)? = nil) {
  _model = StateObject(wrappedValue: GameSessionModel(seed: seed, humanCount: humanCount))
  self.onExit = onExit
 }
 public var body: some View {
  GeometryReader { geometry in
   ZStack {
    LinearGradient(colors: [Color(red: 0.05,green: 0.08,blue: 0.13),
                            Color(red: 0.09,green: 0.14,blue: 0.20)],
                   startPoint: .topLeading, endPoint: .bottomTrailing)
     .ignoresSafeArea()
    if VeilopolyLandscapeLayout.isLandscape(width: Double(geometry.size.width), height: Double(geometry.size.height)) {
     landscapeContent(availableWidth: geometry.size.width)
    } else {
     portraitFallback
    }
   }
   .frame(width: geometry.size.width, height: geometry.size.height)
  }
  .preferredColorScheme(.dark)
  .statusBarHidden()
  .confirmationDialog("更多", isPresented: $showMore) {
   Button("重新开局") { showRestart = true }
   Button("本局信息") { showGameInfo = true }
   Button("取消", role: .cancel) {}
  }
  .confirmationDialog("重新开始本局？", isPresented: $showRestart) {
   Button("重开", role: .destructive) { model.reset(seed: model.game.seed &+ 1) }
   Button("取消", role: .cancel) {}
  }
  .confirmationDialog("退出 Veilopoly？", isPresented: $showExitConfirmation) {
   Button("退出游戏", role: .destructive) { exitGame() }
   Button("继续游戏", role: .cancel) {}
  } message: {
   Text("退出后返回上一级界面；当前单机对局暂不自动保存。")
  }
  .alert("本局信息", isPresented: $showGameInfo) {
   Button("知道了", role: .cancel) {}
  } message: {
   Text("随机种子：\(model.game.seed)\n本地单机 · 4 名玩家\nP5 联机尚未集成。")
  }
  .overlay {
   if let card = model.shownCard {
    VStack(spacing: 14) {
     Image("cardChance", bundle: .module).resizable().scaledToFit().frame(width: 80,height: 90)
     Text("命运之牌").font(.headline)
     Text(card).font(.title3).multilineTextAlignment(.center)
     Button("收起卡牌") { model.dismissCard() }.buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: 320).padding(24)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    .transition(.opacity.combined(with:.scale))
   }
  }
 }

 // A true landscape composition. No ScrollView around the chessboard: the entire
 // SpriteKit scene remains visible, with independently scrollable controls at right.
 private func landscapeContent(availableWidth: CGFloat) -> some View {
  let sideWidth = CGFloat(VeilopolyLandscapeLayout.sidebarWidth(for: Double(availableWidth)))
  return HStack(spacing: 12) {
   boardViewport
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .layoutPriority(1)
   VStack(spacing: 8) {
    HStack(spacing: 8) {
     VStack(alignment: .leading, spacing: 2) {
      Text("VEILOPOLY")
       .font(.system(size: 19, weight: .black, design: .rounded)).tracking(1.5)
      Text("单机 · 四人策略棋盘")
       .font(.system(size: 10)).foregroundStyle(.secondary)
     }
     Spacer(minLength: 0)
     capsuleControls
    }
    .frame(minHeight: 44)
    playerStrip
    ScrollView(.vertical) {
     VStack(alignment: .leading, spacing: 10) {
      Text("当前：\(model.game.players[model.actor].name) · \(phaseLabel(model.game.turn.phase))")
       .font(.subheadline.weight(.semibold))
      if let error = model.errorMessage {
       Text("操作失败：\(error)").foregroundStyle(.orange).font(.caption)
      }
      actionPanel
      Text("独立单机开发版 · VeilLink 入口留待 P5 集成")
       .font(.caption2).foregroundStyle(.secondary)
     }
     .frame(maxWidth: .infinity, alignment: .leading)
     .padding(.horizontal, 2)
    }
    .scrollIndicators(.hidden)
   }
   .frame(width: sideWidth)
   .frame(maxHeight: .infinity, alignment: .top)
  }
  .padding(.horizontal, 10)
  .padding(.vertical, 6)
 }

 private var boardViewport: some View {
  GeometryReader { box in
   let measured = VeilopolyLandscapeLayout.boardSize(availableWidth: Double(box.size.width),
                                                      availableHeight: Double(box.size.height))
   let width = CGFloat(measured.width)
   let height = CGFloat(measured.height)
   SpriteView(scene: model.scene, options: [.ignoresSiblingOrder])
    .frame(width: width, height: height)
    .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    .overlay(alignment: .bottom) {
     if model.pending {
      Text("轻触棋盘快进").font(.caption2).padding(6)
       .background(.thinMaterial, in: Capsule()).padding(6)
     }
    }
    .contentShape(Rectangle())
    .onTapGesture { model.fastForward() }
    .position(x: box.size.width / 2, y: box.size.height / 2)
  }
  .accessibilityLabel("大富翁棋盘，40 格")
 }

 private var portraitFallback: some View {
  VStack(spacing: 16) {
   Image(systemName: "iphone.gen3.radiowaves.left.and.right")
    .font(.system(size: 42)).symbolRenderingMode(.hierarchical)
   Text("请横向握持设备").font(.title3.bold())
   Text("Veilopoly 使用真正的横向全屏棋盘。若设备无法旋转，请确认 VeilLink 宿主已允许横屏方向。")
    .font(.caption).multilineTextAlignment(.center)
    .foregroundStyle(.secondary)
    .frame(maxWidth: 340)
   capsuleControls
  }
  .padding(24)
 }

 // Two-part control matching WeChat mini-program's upper-right capsule:
 // left ellipsis = More; right target = Exit. Both touch areas >= 44 pt.
 private var capsuleControls: some View {
  HStack(spacing: 0) {
   Button { showMore = true } label: {
    Image(systemName: "ellipsis")
     .font(.system(size: 20, weight: .bold))
     .frame(width: 46, height: 44)
   }
   .accessibilityLabel("更多")
   .accessibilityHint("打开重新开局和本局信息")
   Rectangle().fill(.black.opacity(0.14))
    .frame(width: 1, height: 24)
   Button { showExitConfirmation = true } label: {
    ZStack {
     Circle().strokeBorder(.black, lineWidth: 2.5)
      .frame(width: 22, height: 22)
     Circle().fill(.black).frame(width: 9, height: 9)
    }
    .frame(width: 46, height: 44)
   }
   .accessibilityLabel("退出游戏")
   .accessibilityHint("询问是否退出 Veilopoly")
  }
  .foregroundStyle(.black)
  .background(.white.opacity(0.95), in: Capsule())
  .overlay { Capsule().strokeBorder(.black.opacity(0.10), lineWidth: 1) }
  .fixedSize()
 }

 private func exitGame() {
  if let onExit { onExit() }
  else { dismiss() }
 }
 private var playerStrip: some View {
  HStack(spacing: 6) {
   ForEach(model.game.players, id: \.id) { p in
    VStack(spacing: 4) {
     Circle().fill([Color.blue,.red,.green,.yellow][p.id]).frame(width: 9,height: 9)
     Text(p.name).font(.caption2).lineLimit(1)
     Text("¥\(p.cash)").font(.system(size: 12,weight:.bold,design:.monospaced))
     Text(p.bankrupt ? "已破产" : (p.jailTurns > 0 ? "监狱" : "#\(p.position)"))
      .font(.system(size: 10)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical,8)
    .background(p.id == model.actor ? Color.white.opacity(0.15) : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 11))
   }
  }
 }
 private func phaseLabel(_ phase: Phase) -> String {
  return switch phase {
  case .roll: "掷骰"
  case .moveAnim: "移动中"
  case .tileResolve: "地块结算"
  case .auction: "拍卖"
  case .manage: "资产管理"
  case .trade: "交易谈判"
  case .debt: "破产清算"
  case .finished: "结算结束"
  }
 }
 @ViewBuilder private var actionPanel: some View {
  if model.game.winner != nil { settlementPanel }
  else if model.pending { ProgressView("动画播放中") }
  else if !model.waitingForHuman { Text("AI 正在行动……").foregroundStyle(.secondary) }
  else {
   switch model.game.turn.phase {
   case .roll:
    HStack {
     action("掷骰子", symbol: "die.face.5") { model.perform(.rollDice) }
     if model.game.players[model.actor].jailTurns > 0 {
      action("支付 ¥50",symbol:"lock.open") { model.perform(.payBail) }
      if model.game.players[model.actor].chanceJailCards + model.game.players[model.actor].chestJailCards > 0 {
       action("出狱卡",symbol:"rectangle.on.rectangle") { model.perform(.useJailCard) }
      }
     }
    }
   case .tileResolve:
    if let i = model.game.turn.pendingPurchase {
     VStack(alignment: .leading,spacing:10) {
      Text("\(model.game.board[i].name) · ¥\(model.game.board[i].price)").font(.headline)
      HStack {
       action("购买",symbol:"house") { model.perform(.buyProperty,tile:i) }
       action("送入拍卖",symbol:"gavel") { model.perform(.startAuction,tile:i) }
      }
     }
    }
   case .auction: auctionPanel
   case .manage: managePanel
   case .trade: tradeResponsePanel
   case .debt: action("确认破产",symbol:"exclamationmark.triangle") { model.perform(.declareBankruptcy) }
   default: EmptyView()
   }
  }
 }
 private func action(_ title: String, symbol: String, pressed: @escaping () -> Void) -> some View {
  Button(action: pressed) { Label(title, systemImage: symbol).lineLimit(1).minimumScaleFactor(0.8)
   .frame(maxWidth:.infinity,minHeight: 37) }
   .buttonStyle(.borderedProminent)
 }
 private var auctionPanel: some View {
  VStack(alignment: .leading,spacing: 9) {
   if let auction = model.game.auction {
    Text("拍卖 · \(model.game.board[auction.tile].name)").font(.headline)
    Text("当前出价 ¥\(auction.currentBid) · 领先者 \(auction.bidder.map { model.game.players[$0].name } ?? "无")")
     .font(.caption)
    HStack {
     TextField("竞价金额",text:$bidderCash).keyboardType(.numberPad)
      .textFieldStyle(.roundedBorder)
     action("出价",symbol:"hand.raised") { model.perform(.bid,amount:Int(bidderCash) ?? 0) }
     action("弃权",symbol:"xmark.circle") { model.perform(.bid,amount:0) }
    }
   }
  }
 }
 private var managePanel: some View {
  VStack(alignment: .leading,spacing: 12) {
   Text("资产管理").font(.headline)
   Menu {
    ForEach(model.game.board.filter { $0.owner == model.actor }, id: \.i) { t in
     Button("#\(t.i) \(t.name)") { model.selectedTile = t.i }
    }
   } label: {
    Label("地块 #\(model.selectedTile) · \(model.game.board[model.selectedTile].name)",systemImage:"square.grid.3x3")
     .frame(maxWidth:.infinity,alignment:.leading)
   }
   HStack {
    action("建造",symbol:"hammer") { model.perform(.buildHouse,tile:model.selectedTile) }
    action("卖房",symbol:"minus.square") { model.perform(.sellHouse,tile:model.selectedTile) }
   }
   HStack {
    action("抵押",symbol:"lock") { model.perform(.mortgage,tile:model.selectedTile) }
    action("赎回",symbol:"lock.open") { model.perform(.redeem,tile:model.selectedTile) }
   }
   Divider()
   Text("交易提案").font(.subheadline.weight(.semibold))
   Picker("交易对象", selection: $tradeTarget) {
    ForEach(model.game.players.filter { $0.id != model.actor && !$0.bankrupt }, id:\.id) { p in
     Text(p.name).tag(p.id)
    }
   }.pickerStyle(.menu)
   HStack {
    TextField("我方现金",text:$offerCash).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
    TextField("对方现金",text:$requestCash).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
   }
   HStack(alignment:.top) {
    VStack(alignment: .leading) {
     Text("我方地产").font(.caption)
     ForEach(model.game.board.filter { $0.owner == model.actor }, id:\.i) { tile in
      Toggle("#\(tile.i)", isOn: Binding(get:{ chosenOffer.contains(tile.i) },
       set:{ if $0 { chosenOffer.insert(tile.i) } else { chosenOffer.remove(tile.i) } }))
       .font(.caption)
     }
    }
    VStack(alignment:.leading) {
     Text("对方地产").font(.caption)
     ForEach(model.game.board.filter { $0.owner == tradeTarget }, id:\.i) { tile in
      Toggle("#\(tile.i)", isOn: Binding(get:{ chosenRequest.contains(tile.i) },
       set:{ if $0 { chosenRequest.insert(tile.i) } else { chosenRequest.remove(tile.i) } }))
       .font(.caption)
     }
    }
   }
   action("发起交易",symbol:"arrow.left.arrow.right") {
    model.perform(.proposeTrade,to:tradeTarget,
     offer: TradeTransfer(cash:max(0,Int(offerCash) ?? 0),tiles:chosenOffer.sorted()),
     request: TradeTransfer(cash:max(0,Int(requestCash) ?? 0),tiles:chosenRequest.sorted()))
   }
   action("结束回合",symbol:"checkmark.circle") { model.perform(.endTurn) }
  }
 }
 private var tradeResponsePanel: some View {
  VStack(spacing: 12) {
   Text("交易确认").font(.headline)
   if let trade = model.game.trade {
    Text("\(model.game.players[trade.from].name) 提议交易 · 现金 ¥\(trade.offer.cash) / ¥\(trade.request.cash)")
     .font(.caption)
    Text("地产：\(trade.offer.tiles.map(String.init).joined(separator:",")) ⇄ \(trade.request.tiles.map(String.init).joined(separator:","))")
     .font(.caption)
   }
   HStack {
    action("接受",symbol:"checkmark") { model.perform(.acceptTrade) }
    action("拒绝",symbol:"xmark") { model.perform(.rejectTrade) }
   }
   action("还价（交换现金条件）",symbol:"arrow.triangle.2.circlepath") {
    guard let trade = model.game.trade else { return }
    model.perform(.counterTrade,offer:TradeTransfer(cash:trade.request.cash),
                  request:TradeTransfer(cash:trade.offer.cash))
   }
  }
 }
 private var settlementPanel: some View {
  VStack(spacing: 12) {
   Image(systemName:"trophy.fill").font(.system(size:44)).foregroundStyle(.yellow)
   Text("本局胜者：\(model.game.players[model.game.winner ?? 0].name)").font(.title2.bold())
   ForEach(model.game.players.sorted(by:{ a,b in netWorth(a) > netWorth(b) }),id:\.id) { p in
    HStack {
     Text(p.name); Spacer()
     Text("总资产 ¥\(netWorth(p))")
    }.font(.subheadline)
   }
   action("再来一局",symbol:"arrow.clockwise") { model.reset(seed: model.game.seed &+ 1) }
   Text("返回聊天需 P5 集成提供入口").font(.caption).foregroundStyle(.secondary)
  }
 }
 private func netWorth(_ p: Player) -> Int {
  p.cash + model.game.board.filter { $0.owner == p.id }
   .reduce(0) { $0 + ($1.mortgaged ? $1.price / 2 : $1.price) + $1.houses * $1.houseCost + ($1.hotel ? 5 * $1.houseCost : 0) }
 }
}
#else
// SwiftUI + SpriteKit require the iOS/macOS Apple SDK; Engine/AI/Net remain portable.
import VeilopolyEngine
#endif
