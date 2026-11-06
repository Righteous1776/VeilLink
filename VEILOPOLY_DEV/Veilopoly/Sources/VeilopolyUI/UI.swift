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
 @Published public private(set) var lastFeedback: String = "准备开始 · 轮到第一位玩家"
 private var cardGate = CardRevealGate()
 @Published public var selectedTile: Int = 1 {
  didSet { scene.highlightTile(selectedTile) }
 }
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
  scene.highlightTile(selectedTile)
  scene.onBoardTap = { [weak self] tile in
   guard let self else { return }
   if self.animating { self.fastForward() }
   else if let tile { self.selectedTile = tile }
  }
  if humanCount == 0 { Task { @MainActor [weak self] in self?.drive() } }
 }
 public var actor: Int { game.auction?.turn ?? game.trade?.to ?? game.pendingDebt?.player ?? game.turn.player }
 public var waitingForHuman: Bool { !game.players[actor].bankrupt && game.players[actor].kind == .human }
 public var currentContext: GameContext { VeilopolyEngine.context(game) }
 public var pending: Bool { animating }

 public func perform(_ kind: MoveKind, tile: Int? = nil, amount: Int? = nil,
                     to: Int? = nil, offer: TradeTransfer? = nil, request: TradeTransfer? = nil,
                     deck: DeckKind? = nil, financeProduct: FinancialFeature? = nil,
                     financePeriods: Int? = nil, financeID: Int? = nil) {
  guard !animating && !cardGate.isPresented else { return }
  let move = Move(kind, player: actor, seq: game.nextSeq, tile: tile, amount: amount,
                  to: to, offer: offer, request: request, deck: deck,
                  financeProduct: financeProduct, financePeriods: financePeriods, financeID: financeID)
  applyMove(move)
  drive()
 }
 private func applyMove(_ move: Move) {
  let result = VeilopolyEngine.apply(game, currentContext, move)
  switch result {
  case .failure(let err): errorMessage = err.rawValue
  case .success((let newState, let effects)):
   errorMessage = nil
   if let feedback = VeilopolyEventFeedback.summary(effects) { lastFeedback = feedback }
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
  if case .cardShow(_,let message) = command {
   // Only a human player's card requires a tap to proceed. AI-only games
   // must continue after the visual/audio timeline without blocking on UI.
   if game.players[game.turn.player].kind == .human {
    cardGate.present()
    shownCard = message
   } else {
    lastFeedback = "AI 卡牌 · " + message
   }
  }
  scene.play(command) { [weak self] in
   guard let self else { return }
   if self.cardGate.animationDidComplete() { self.presentNext() }
  }
 }
 public func fastForward() {
  // Card reading is a deliberate decision, not a skippable scene effect.
  if animating && !cardGate.isPresented { scene.fastForward() }
 }
 public func dismissCard() {
  guard shownCard != nil else { return }
  shownCard = nil
  switch cardGate.dismiss() {
  case .advanceQueue: presentNext()
  case .finishAnimation: scene.fastForward()
  case .none: break
  }
 }
 public func reset(seed: UInt64) {
  guard !animating else { return }
  let newState = GameFactory.make(seed: seed, humanCount: configuredHumanCount)
  game = newState; shownCard = nil; cardGate.reset(); queue = []; errorMessage = nil
  lastFeedback = "新的一局已经准备好"
  scene.display(newState)
  selectedTile = 1
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
 @State private var bankAmount = "200"
 @State private var bankPeriods = "3"
 @State private var tradeTarget = 1
 @State private var chosenOffer: Set<Int> = []
 @State private var chosenRequest: Set<Int> = []
 @State private var showRestart = false
 @State private var showMore = false
 @State private var showExitConfirmation = false
 @State private var showGameInfo = false
 @Environment(\.dismiss) private var dismiss
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
  .onAppear { model.scene.reduceMotion = reduceMotion }
  .onChange(of: reduceMotion) { model.scene.reduceMotion = $0 }
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
    ZStack {
     // Modal screen blocks the underlying board and financial action controls.
     Color.black.opacity(0.70).ignoresSafeArea()
     VStack(spacing: 12) {
      Image("cardChance", bundle: .module)
       .resizable().scaledToFit().frame(width: 66, height: 72)
       .accessibilityHidden(true)
      Label("命运卡片", systemImage: "rectangle.on.rectangle.angled")
       .font(.headline).foregroundColor(Color(red: 0.19, green: 0.30, blue: 0.34))
      ScrollView {
       Text(card).font(.system(size: 16, weight: .semibold))
        .foregroundColor(Color(red: 0.19, green: 0.30, blue: 0.34))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
      }
      .frame(maxHeight: 116)
      Button("确认并继续") { model.dismissCard() }
       .buttonStyle(AstraB01ButtonStyle())
       .frame(minWidth: 160, minHeight: 44)
       .accessibilityHint("阅读完毕后继续播放游戏事件")
     }
     .frame(maxWidth: 300).padding(22)
     .background {
      AstraB01Artwork.image(AstraB01AssetNames.cardFace)
       .resizable(capInsets: EdgeInsets(top: 88, leading: 26, bottom: 26, trailing: 26),
                  resizingMode: .stretch)
       .allowsHitTesting(false)
     }
     .padding(.horizontal, 16)
     .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
    .zIndex(100)
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
      HStack(alignment: .top, spacing: 7) {
       Image(systemName: "sparkles").foregroundStyle(.mint)
       Text(model.lastFeedback).font(.caption.weight(.medium))
        .fixedSize(horizontal: false, vertical: true).lineLimit(3)
       Spacer(minLength: 0)
      }
      .padding(9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AstraB01PanelSkin(.glass))
      .accessibilityLabel("最近事件：\(model.lastFeedback)")
      if let error = model.errorMessage {
       Label("操作未完成：\(error)", systemImage: "exclamationmark.triangle.fill")
        .labelStyle(.titleOnly)
        .foregroundColor(.white).font(.caption.weight(.medium))
        .padding(.leading, 48).padding(.trailing, 10).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AstraB01FeedbackSkin(error: true))
      }
      tileInspector
      actionPanel
       .padding(8)
       .background(AstraB01PanelSkin(.action))
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
     if model.pending && model.shownCard == nil {
      Button { model.fastForward() } label: {
       Label("跳过当前动画", systemImage: "forward.end.fill")
        .font(.caption2.weight(.semibold)).padding(.horizontal, 11)
        .padding(.vertical, 7)
      }
      .buttonStyle(.borderedProminent)
      .tint(.mint)
      .accessibilityHint("立即完成当前动画，进入下一个视觉事件")
      .padding(8)
     }
    }
    .contentShape(Rectangle())
    .position(x: box.size.width / 2, y: box.size.height / 2)
  }
  .accessibilityLabel("大富翁棋盘，40 格")
 }

 private var tileInspector: some View {
  let tile = model.game.board[model.selectedTile]
  let ownerName = tile.owner.map { model.game.players[$0].name } ?? "尚未购买"
  return HStack(spacing: 8) {
   Button { model.selectedTile = (model.selectedTile + 39) % 40 } label: {
    Image(systemName: "chevron.left").frame(width: 44, height: 44)
   }
   .buttonStyle(.plain)
   .accessibilityLabel("查看上一格")
   VStack(alignment: .leading, spacing: 2) {
    Text("#\(tile.i) · \(tile.name)")
     .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
    HStack(spacing: 6) {
     Text(tile.purchasable ? "¥\(tile.price)" : "特殊地块")
     Text(tile.mortgaged ? "已抵押" : ownerName)
    }
    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
   }
   .frame(maxWidth: .infinity, alignment: .leading)
   Button { model.selectedTile = (model.selectedTile + 1) % 40 } label: {
    Image(systemName: "chevron.right").frame(width: 44, height: 44)
   }
   .buttonStyle(.plain)
   .accessibilityLabel("查看下一格")
  }
  .padding(.horizontal, 5)
  .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
  .accessibilityElement(children: .contain)
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
  // Two columns preserve readable names and money values on a narrow
  // landscape phone sidebar; each player keeps a genuine state skin.
  LazyVGrid(columns: [GridItem(.flexible(minimum: 0), spacing: 6),
                      GridItem(.flexible(minimum: 0), spacing: 6)], spacing: 6) {
   ForEach(model.game.players, id: \.id) { p in
    VStack(alignment: .leading, spacing: 2) {
     Text(p.name)
      .font(.system(size: 10, weight: .semibold))
      .lineLimit(1).minimumScaleFactor(0.75)
     Text("¥\(p.cash)")
      .font(.system(size: 12, weight: .bold, design: .monospaced))
      .lineLimit(1).minimumScaleFactor(0.70)
     Text(p.bankrupt ? "已破产" : (p.jailTurns > 0 ? "监狱" : "#\(p.position)"))
      .font(.system(size: 9))
      .lineLimit(1)
    }
    .foregroundColor(.white)
    .padding(.leading, 43).padding(.trailing, 3)
    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
    .background {
     AstraB01PlayerSkin(AstraB01AssetNames.playerSkin(
      bankrupt: p.bankrupt, jailed: p.jailTurns > 0,
      current: p.id == model.actor))
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(p.name)，现金 ¥\(p.cash)，" +
      (p.bankrupt ? "已破产" : p.jailTurns > 0 ? "在监狱" : "位于第 \(p.position) 格") +
      (p.id == model.actor ? "，当前行动玩家" : ""))
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
      astraBuyHero(model.game.board[i])
      HStack {
       action("购买",symbol:"house") { model.perform(.buyProperty,tile:i) }
        .disabled(model.game.players[model.actor].cash < model.game.board[i].price)
       action("送入拍卖",symbol:"gavel",secondary:true) { model.perform(.startAuction,tile:i) }
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
 private func action(_ title: String, symbol: String,
                     secondary: Bool = false, pressed: @escaping () -> Void) -> some View {
  Button(action: pressed) {
   Text(title).frame(maxWidth: .infinity, minHeight: 44)
  }
  .buttonStyle(AstraB01ButtonStyle(secondary: secondary))
  .accessibilityLabel(title)
 }
 // Astra B01 runtime cards: backgrounds are decorative; all values below
 // come from the current authoritative GameState, never baked into PNGs.
 private func astraHeroField(_ value: String, x: CGFloat, y: CGFloat,
                             width: CGFloat, height: CGFloat = 24,
                             textColor: Color = Color(red: 0.19, green: 0.30, blue: 0.34)) -> some View {
  Text(value)
   .font(.system(size: 13, weight: .semibold, design: .rounded))
   .foregroundColor(textColor)
   .lineLimit(1).minimumScaleFactor(0.70)
   .frame(width: width, height: height)
   .position(x: x, y: y)
 }
 private func astraBuyHero(_ tile: Tile) -> some View {
  ZStack(alignment: .topLeading) {
   AstraB01Artwork.image(AstraB01AssetNames.buyHero).resizable()
    .frame(width: 256, height: 174).accessibilityHidden(true)
   astraHeroField(tile.name, x: 156, y: 56, width: 160)
   astraHeroField("¥\(tile.price)", x: 189, y: 94, width: 94)
   astraHeroField(model.game.players[model.actor].cash >= tile.price
                   ? "¥\(model.game.players[model.actor].cash - tile.price)" : "余额不足",
                  x: 189, y: 120, width: 94)
   astraHeroField("¥\(tile.rent.first ?? 0)", x: 189, y: 146, width: 94)
  }
  .frame(width: 256, height: 174)
  .accessibilityElement(children: .combine)
 }
 private var astraBankHero: some View {
  let account = model.game.banking.flatMap { ledger in
   ledger.accounts.indices.contains(model.actor) ? ledger.accounts[model.actor] : nil
  }
  let savings = account?.savings.reduce(0) { $0 + $1.principal } ?? 0
  let loans = account?.loans.reduce(0) { $0 + $1.totalDue } ?? 0
  return ZStack(alignment: .topLeading) {
   AstraB01Artwork.image(AstraB01AssetNames.bankHero).resizable()
    .frame(width: 256, height: 174).accessibilityHidden(true)
   astraHeroField("¥\(model.game.players[model.actor].cash)",
                  x: 146, y: 48, width: 116, height: 28)
   astraHeroField("¥\(savings)", x: 61, y: 155, width: 98,
                  textColor: .white)
   astraHeroField("¥\(loans)", x: 195, y: 155, width: 98,
                  textColor: .white)
  }
  .frame(width: 256, height: 174)
  .accessibilityElement(children: .combine)
 }
 private var astraSettlementHero: some View {
  let winner = model.game.players[model.game.winner ?? 0]
  let propertyCount = model.game.board.filter { $0.owner == winner.id }.count
  return ZStack(alignment: .topLeading) {
   AstraB01Artwork.image(AstraB01AssetNames.settlementHero).resizable()
    .frame(width: 256, height: 174).accessibilityHidden(true)
   astraHeroField(winner.name, x: 128, y: 75, width: 208, height: 22)
   astraHeroField("¥\(netWorth(winner))", x: 128, y: 123, width: 208, height: 29)
   astraHeroField("\(propertyCount)", x: 188, y: 156, width: 88)
  }
  .frame(width: 256, height: 174)
  .accessibilityElement(children: .combine)
 }

 private func adjustAuctionBid(by delta: Int) {
  guard let auction = model.game.auction else { return }
  let minimum = auction.currentBid + 1
  let cash = model.game.players[model.actor].cash
  guard cash >= minimum else { return }
  let bounded = max(minimum, min(cash, Int(bidderCash) ?? minimum))
  bidderCash = String(delta > 0 ? min(cash, bounded + 1)
                           : max(minimum, bounded - 1))
 }
 @ViewBuilder private var astraAuctionHero: some View {
  if let auction = model.game.auction {
   ZStack(alignment: .topLeading) {
    AstraB01Artwork.image(AstraB01AssetNames.auctionHero)
     .resizable().frame(width: 256, height: 174)
     .accessibilityHidden(true)
    astraHeroField(model.game.board[auction.tile].name,
                   x: 148, y: 36, width: 176, height: 28)
    astraHeroField("¥\(auction.currentBid)", x: 191, y: 74, width: 90)
    astraHeroField(auction.bidder.map { model.game.players[$0].name } ?? "暂无",
                   x: 191, y: 99, width: 90)
    // B01 art draws +/- controls. Provide real 44-point touch targets.
    Button { adjustAuctionBid(by: -1) } label: {
     Color.clear.frame(width: 44, height: 44).contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .position(x: AstraB01AuctionHitZones.minus.centerX,
              y: AstraB01AuctionHitZones.minus.centerY)
    .accessibilityLabel("降低竞价金额")
    .disabled(model.game.players[model.actor].cash <= auction.currentBid)
    TextField("竞价金额", text: $bidderCash)
     .keyboardType(.numberPad)
     .textFieldStyle(.plain)
     .font(.system(size: 15, weight: .semibold, design: .monospaced))
     .foregroundColor(Color(red: 0.19, green: 0.30, blue: 0.34))
     .multilineTextAlignment(.center)
     .frame(width: 132, height: 44)
     .position(x: AstraB01AuctionHitZones.input.centerX,
               y: AstraB01AuctionHitZones.input.centerY)
     .accessibilityLabel("竞价金额")
    Button { adjustAuctionBid(by: 1) } label: {
     Color.clear.frame(width: 44, height: 44).contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .position(x: AstraB01AuctionHitZones.plus.centerX,
              y: AstraB01AuctionHitZones.plus.centerY)
    .accessibilityLabel("提高竞价金额")
    .disabled(model.game.players[model.actor].cash <= auction.currentBid)
   }
   .frame(width: 256, height: 174)
   .accessibilityElement(children: .contain)
  }
 }
 private func astraTradeHero(_ trade: TradeState) -> some View {
  ZStack(alignment: .topLeading) {
   AstraB01Artwork.image(AstraB01AssetNames.tradeHero)
    .resizable().frame(width: 256, height: 174)
    .accessibilityHidden(true)
   astraHeroField("\(trade.offer.tiles.count) 项", x: 62, y: 97, width: 84)
   astraHeroField("\(trade.request.tiles.count) 项", x: 194, y: 97, width: 84)
   astraHeroField("¥\(trade.offer.cash)", x: 62, y: 142, width: 84, height: 32)
   astraHeroField("¥\(trade.request.cash)", x: 194, y: 142, width: 84, height: 32)
  }
  .frame(width: 256, height: 174)
  .accessibilityElement(children: .combine)
 }
 private var auctionPanel: some View {
  VStack(alignment: .leading,spacing: 9) {
   if let auction = model.game.auction {
    Text("拍卖 · \(model.game.board[auction.tile].name)").font(.headline)
    astraAuctionHero
    HStack {
     action("出价",symbol:"hand.raised") {
      model.perform(.bid, amount: Int(bidderCash) ?? 0)
     }
     .disabled((Int(bidderCash) ?? 0) <= auction.currentBid ||
               (Int(bidderCash) ?? 0) > model.game.players[model.actor].cash)
     action("弃权",symbol:"xmark.circle",secondary:true) {
      model.perform(.bid, amount: 0)
     }
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
    action("卖房",symbol:"minus.square",secondary:true) { model.perform(.sellHouse,tile:model.selectedTile) }
   }
   HStack {
    action("抵押",symbol:"lock") { model.perform(.mortgage,tile:model.selectedTile) }
    action("赎回",symbol:"lock.open",secondary:true) { model.perform(.redeem,tile:model.selectedTile) }
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
   bankPanel
   action("结束回合",symbol:"checkmark.circle") { model.perform(.endTurn) }
  }
 }
 // Pure Swift bank moves are routed through the same authoritative GameState reducer.
 // Kimi owns the final animated skin; this is the functional accessibility fallback.
 private var bankPanel: some View {
  VStack(alignment: .leading, spacing: 8) {
   Divider()
   Text("银行与金融").font(.subheadline.weight(.semibold))
   astraBankHero
   HStack(spacing: 8) {
    TextField("金额", text: $bankAmount)
     .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
     .accessibilityLabel("银行操作金额")
    TextField("期数", text: $bankPeriods)
     .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
     .accessibilityLabel("贷款期数")
   }
   HStack(spacing: 8) {
    action("存入活期", symbol: "building.columns") {
     model.perform(.bankDeposit, amount: Int(bankAmount), financeProduct: .demandDeposit)
    }
    action("申请贷款", symbol: "creditcard") {
     model.perform(.bankBorrow, amount: Int(bankAmount), financePeriods: Int(bankPeriods))
    }
   }
   if let ledger = model.game.banking, ledger.accounts.indices.contains(model.actor) {
    let account = ledger.accounts[model.actor]
    ForEach(account.savings, id: \.id) { deposit in
     action("取回存款 ¥\(deposit.principal)", symbol: "arrow.down.left") {
      model.perform(.bankWithdraw, financeID: deposit.id)
     }
    }
    ForEach(account.loans, id: \.id) { loan in
     action("偿还贷款 ¥\(loan.totalDue)", symbol: "arrow.up.right") {
      model.perform(.bankRepay, financeID: loan.id)
     }
    }
    ForEach(account.positions, id: \.id) { item in
     action("结算投资 #\(item.id)", symbol: "chart.line.uptrend.xyaxis") {
      model.perform(.bankSettle, financeID: item.id)
     }
    }
    Text("金融期数：\(ledger.completedTurns)")
     .font(.caption2).foregroundStyle(.secondary)
   }
   Text("定期收益、股票和风险投资的正式回报表待规格裁决；仅使用游戏内虚拟货币。")
    .font(.caption2).foregroundStyle(.secondary)
  }
 }
 private var tradeResponsePanel: some View {
  VStack(spacing: 12) {
   Text("交易确认").font(.headline)
   if let trade = model.game.trade {
    astraTradeHero(trade)
    Text("\(model.game.players[trade.from].name) 提议交易 · 现金 ¥\(trade.offer.cash) / ¥\(trade.request.cash)")
     .font(.caption)
    Text("地产：\(trade.offer.tiles.map(String.init).joined(separator:",")) ⇄ \(trade.request.tiles.map(String.init).joined(separator:","))")
     .font(.caption)
   }
   HStack {
    action("接受",symbol:"checkmark") { model.perform(.acceptTrade) }
    action("拒绝",symbol:"xmark",secondary:true) { model.perform(.rejectTrade) }
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
   astraSettlementHero
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
