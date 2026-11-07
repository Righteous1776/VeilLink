#if os(iOS) && canImport(SwiftUI) && canImport(SpriteKit)
import Foundation
import SwiftUI
import SpriteKit
import UIKit
import VeilopolyEngine
import VeilopolyAI
import VeilopolyPersistence

@MainActor
public final class GameSessionModel: ObservableObject {
 @Published public private(set) var game: GameState
 @Published public private(set) var errorMessage: String?
 @Published public private(set) var errorAdvice: String?
 @Published public private(set) var shownCard: String?
 @Published public private(set) var shownCardDeck: DeckKind = .chance
 @Published public private(set) var shownCardID: Int?
 @Published public private(set) var boardSelectionRevision = 0
 @Published public private(set) var stockExecutions: [StockExecution] = []
 @Published public private(set) var stockOrderError: String?
 @Published public private(set) var lastFeedback: String = "准备开始 · 轮到第一位玩家"
 @Published public private(set) var saveWarning: String?
 @Published public private(set) var bulletinFeed = VeilopolyBulletinFeed()
 @Published public var newsEnabled = true
 private var cardGate = CardRevealGate()
 @Published public var selectedTile: Int = 1 {
  didSet { scene.highlightTile(selectedTile) }
 }
 let scene: GameBoardScene
 private var queue: [ViewCommand] = []
 @Published private var animating = false
 private var driving = false
 private let configuredHumanCount: Int
 private let saveStore: VeilopolySaveStore?
 private let saveSessionID: String
 private var recoveryBlocked = false
 private var lastCheckpointAt = Date.distantPast

 public init(seed: UInt64? = nil, humanCount: Int = 1) {
  configuredHumanCount = humanCount
  let sessionID = "solo-\(humanCount)"
  saveSessionID = sessionID
  let store = try? VeilopolySaveStore()
  saveStore = store
  let recovered: VeilopolySavedGame?
  let unreadable: Bool
  do {
   recovered = try store?.load(gameID: sessionID, mode: .solo)
   unreadable = false
  } catch {
   // Preserve unreadable files; never silently overwrite a user's game.
   recovered = nil
   unreadable = true
  }
  recoveryBlocked = unreadable
  // Fresh OS entropy is sampled only at a NEW MATCH boundary; saved games
  // always resume their original seed and deterministic replay.
  let initial = recovered?.game ?? GameFactory.make(
   seed: seed ?? VeilopolyNewGameSeed.fresh(), humanCount: humanCount)
  game = initial
  scene = GameBoardScene(size: CGSize(width: 1024, height: 940))
  stockExecutions = (recovered?.stockReceipts ?? []).map(StockExecution.init(record:))
  scene.display(initial)
  scene.highlightTile(selectedTile)
  scene.onBoardTap = { [weak self] tile in
   guard let self else { return }
   if let tile {
    self.selectedTile = tile
    self.boardSelectionRevision += 1
   }
  }
  if unreadable {
   saveWarning = "本地存档无法读取，已保留原文件。可从「重新开局」明确重置。"
   lastFeedback = "上次存档异常 · 未覆盖旧数据"
  } else if let recovered {
   lastFeedback = "已恢复上次对局 · 进度 #\(recovered.game.nextSeq)"
  } else {
   checkpoint(force: true)
  }
  // A killed app can resume in .moveAnim/.tileResolve. Finish the pending
  // deterministic reducer step without replaying an already committed roll.
  if humanCount == 0 || recovered != nil {
   Task { @MainActor [weak self] in self?.drive() }
  }
 }
 public var actor: Int { game.auction?.turn ?? game.trade?.to ?? game.pendingDebt?.player ?? game.turn.player }
 public var waitingForHuman: Bool { !game.players[actor].bankrupt && game.players[actor].kind == .human }
 public var currentContext: GameContext { VeilopolyEngine.context(game) }
 public var pending: Bool { animating }
 /// Read-only editorial copy for the EXACT engine card currently in the queue.
 /// Persisted CardDefinition and gameplay effects remain authoritative.
 public var shownEditorial: VeilopolyCardEditorialEntry? {
  guard let id = shownCardID else { return nil }
  return VeilopolyCardEditorial.presentation(id: id, deck: shownCardDeck, among: game.cards)
 }
 public var saveSummary: String {
  saveWarning ?? "自动保存已启用 · 异常退出后可继续本局"
 }
 private func checkpoint(force: Bool) {
  if !force && Date().timeIntervalSince(lastCheckpointAt) < 30 { return }
  guard !recoveryBlocked else { return }
  guard let saveStore else {
   saveWarning = "自动保存不可用：无法访问本机存储目录"
   return
  }
  do {
   _ = try saveStore.save(game, gameID: saveSessionID, mode: .solo,
                          stockReceipts: stockExecutions.map(\.persisted))
   lastCheckpointAt = Date()
   saveWarning = nil
  } catch {
   saveWarning = "自动存档失败：请保留应用数据并反馈"
  }
 }
 public func flushSave() { checkpoint(force: true) }
 public func advanceBulletin() {
  guard newsEnabled else { bulletinFeed = VeilopolyBulletinFeed(); return }
  bulletinFeed.advance(by: 2, seed: game.seed)
 }

 public func perform(_ kind: MoveKind, tile: Int? = nil, amount: Int? = nil,
                     to: Int? = nil, offer: TradeTransfer? = nil, request: TradeTransfer? = nil,
                     deck: DeckKind? = nil, financeProduct: FinancialFeature? = nil,
                     financePeriods: Int? = nil, financeID: Int? = nil,
                     stockSymbol: String? = nil, stockShares: Int? = nil) {
  guard !animating && !cardGate.isPresented else { return }
  let move = Move(kind, player: actor, seq: game.nextSeq, tile: tile, amount: amount,
                  to: to, offer: offer, request: request, deck: deck,
                  financeProduct: financeProduct, financePeriods: financePeriods, financeID: financeID,
                  stockSymbol: stockSymbol, stockShares: stockShares)
  applyMove(move)
  drive()
 }
 public func advanceStockMarket() {
  guard !animating && !cardGate.isPresented && waitingForHuman && game.turn.phase == .manage else { return }
  applyMove(Move(.stockTick, player: actor, seq: game.nextSeq))
 }
 private func applyMove(_ move: Move) {
  let result = VeilopolyEngine.apply(game, currentContext, move)
  switch result {
  case .failure(let err):
   errorMessage = VeilopolyGamePresentation.message(err)
   errorAdvice = VeilopolyGamePresentation.advice(err)
   if move.type == .stockBuy || move.type == .stockSell {
    stockOrderError = StockTerminalState.rejection(
     market: IntegratedBanking.ledger(game).market ?? StockMarketEngine.initial(seed: game.seed),
     player: move.player, cash: game.players[move.player].cash,
     symbol: move.stockSymbol ?? "", shares: move.stockShares ?? 0,
     buying: move.type == .stockBuy) ?? "订单未成交，请重试"
    UINotificationFeedbackGenerator().notificationOccurred(.error)
   }
  case .success((let newState, let effects)):
   if newsEnabled {
    if let notice = VeilopolyBulletinCopy.event(effects, state: newState, sequence: move.seq) {
     bulletinFeed.enqueue(notice)
    }
    if let notice = VeilopolyBulletinCopy.market(before: game.banking?.market,
       after: newState.banking?.market, sequence: move.seq) {
     bulletinFeed.enqueue(notice)
    }
   }
   if move.type == .stockTick {
    // Market ticks occur every 2 seconds. Save a bounded checkpoint
    // periodically, and always flush on lifecycle departure or player action.
    game = newState
    checkpoint(force: false)
    return
   }
   errorMessage = nil
   errorAdvice = nil
   if move.type == .stockBuy || move.type == .stockSell {
    stockOrderError = nil
    for effect in effects {
     if let execution = StockExecution(sequence: move.seq, effect: effect) {
      stockExecutions.insert(execution, at: 0)
     }
    }
    stockExecutions = Array(stockExecutions.prefix(40))
   }
   if let feedback = VeilopolyEventFeedback.contextualSummary(effects, state: newState) { lastFeedback = feedback }
   let commands = CommandTranslator.translate(effects)
   game = newState
   // Persist the COMMITTED reducer state before starting presentation
   // animations, which are intentionally never replayed after a crash.
   checkpoint(force: true)
   scene.display(newState, snapTokens: !effects.contains(where: { $0.kind == .playerMoved }))
   queue.append(contentsOf: commands)
   if effects.contains(where: { $0.kind == .stockBought || $0.kind == .stockSold }) {
    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
   }
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
  if case .cardShow(let deck,let id,let message) = command {
   // Only a human player's card requires a tap to proceed. AI-only games
   // must continue after the visual/audio timeline without blocking on UI.
   if game.players[game.turn.player].kind == .human {
    cardGate.present()
    shownCardDeck = deck
    shownCardID = id
    shownCard = message
   } else {
    let editorial = id.flatMap {
     VeilopolyCardEditorial.presentation(id: $0, deck: deck, among: game.cards)
    }
    lastFeedback = "AI · " + VeilopolyCardEditorial.deckName(deck) + " · " +
      (editorial?.title ?? message)
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
  shownCardID = nil
  switch cardGate.dismiss() {
  case .advanceQueue: presentNext()
  case .finishAnimation: scene.fastForward()
  case .none: break
  }
 }
 public func reset(seed: UInt64) {
  guard !animating else { return }
  if recoveryBlocked {
   guard let saveStore else { return }
   do {
    _ = try saveStore.quarantineUnreadable(gameID: saveSessionID, mode: .solo)
    recoveryBlocked = false
   } catch {
    saveWarning = "无法隔离损坏存档，未清除原数据"
    return
   }
  }
  let newState = GameFactory.make(seed: seed, humanCount: configuredHumanCount)
  game = newState; shownCard = nil; shownCardID = nil; cardGate.reset(); queue = []
  errorMessage = nil; errorAdvice = nil
  stockExecutions = []; stockOrderError = nil
  bulletinFeed = VeilopolyBulletinFeed()
  lastFeedback = "新的一局已经准备好"
  checkpoint(force: true)
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

private enum VeilopolyAmountTarget: String, Identifiable {
 case bid, bankAmount, bankPeriods, offerCash, requestCash, stockShares
 var id: String { rawValue }
 var title: String {
  switch self {
  case .bid: return "拍卖竞价金额"
  case .bankAmount: return "银行操作金额"
  case .bankPeriods: return "贷款期数"
  case .offerCash: return "我方出资"
  case .requestCash: return "对方出资"
  case .stockShares: return "交易股数"
  }
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
 @State private var stockSymbol = "VTL"
 @State private var stockShares = "1"
 @State private var tradeTarget = 1
 @State private var chosenOffer: Set<Int> = []
 @State private var chosenRequest: Set<Int> = []
 @State private var showRestart = false
 @State private var showMore = false
 @State private var showExitConfirmation = false
 @State private var showGameInfo = false
 @State private var showGuide = false
 @State private var controlsExpanded = false
 @AppStorage("veilopoly.dayFelt.v1") private var dayFelt = false
 @AppStorage("veilopoly.slowSteps.v1") private var slowSteps = true
 @State private var showTileInformation = false
 @State private var showAssetExplorer = false
 @State private var showManagementWorkspace = false
 @State private var showProbabilityLab = false
 @State private var probabilityLastRoll: Int?
 @State private var probabilityAttempts = 0
 @State private var probabilityMatches = 0
 @State private var overviewTile = 1
 @State private var amountTarget: VeilopolyAmountTarget?
 @State private var showFinanceHUD = true
 @State private var showMarketHUD = true
 @State private var financeHUDOffset = CGSize.zero
 @State private var marketHUDOffset = CGSize.zero
 @GestureState private var financeHUDDrag = CGSize.zero
 @GestureState private var marketHUDDrag = CGSize.zero
 @State private var managementSection: VeilopolyManagementSection = .property
 @Environment(\.dismiss) private var dismiss
 @Environment(\.accessibilityReduceMotion) private var reduceMotion
 @Environment(\.scenePhase) private var scenePhase
 private let onExit: (() -> Void)?
 public init(seed: UInt64? = nil, humanCount: Int = 1, onExit: (() -> Void)? = nil) {
  _model = StateObject(wrappedValue: GameSessionModel(seed: seed, humanCount: humanCount))
  self.onExit = onExit
 }
 public var body: some View {
  GeometryReader { geometry in
   ZStack {
    // Ivory paper is the scene canvas; dark teal Astra controls sit as one
    // gold-rimmed functional overlay, not a separate blue-black application.
    LinearGradient(colors: dayFelt
                    ? [Color(red: 0.97,green: 0.95,blue: 0.90), Color(red: 0.87,green: 0.82,blue: 0.71)]
                    : [Color(red: 0.03,green: 0.07,blue: 0.09), Color(red: 0.08,green: 0.14,blue: 0.17)],
                   startPoint: .topLeading, endPoint: .bottomTrailing)
     .ignoresSafeArea()
    if VeilopolyLandscapeLayout.isLandscape(width: Double(geometry.size.width), height: Double(geometry.size.height)) {
     landscapeContent(availableWidth: geometry.size.width,
                      availableHeight: geometry.size.height)
    } else {
     portraitFallback
    }
   }
   .frame(width: geometry.size.width, height: geometry.size.height)
  }
  .preferredColorScheme(dayFelt ? .light : .dark)
   .statusBarHidden()
  .onAppear {
   model.scene.reduceMotion = reduceMotion
    model.scene.stepDuration = slowSteps ? 0.42 : 0.26
    if model.scene.supportsDayFelt { model.scene.setDayFelt(dayFelt) }
  }
  .onDisappear { model.flushSave() }
  .onChange(of: scenePhase) { phase in
   if phase != .active { model.flushSave() }
  }
  .onChange(of: reduceMotion) { model.scene.reduceMotion = $0 }
   .onChange(of: slowSteps) { model.scene.stepDuration = $0 ? 0.42 : 0.26 }
   .onChange(of: model.game.auction?.currentBid) { bid in
    guard let bid else { return }
    bidderCash = String(min(model.game.players[model.actor].cash, bid + 1))
   }
  .onChange(of: model.pending) { pending in
   if !pending { revealDecisionIfNeeded() }
  }
  .onChange(of: model.game.turn.phase) { phase in
    if phase != .manage { showManagementWorkspace = false }
    revealDecisionIfNeeded()
   }
  .onChange(of: model.actor) { _ in
   resetTradeDraft()
   if model.game.trade != nil { loadCounterCash() }
   managementSection = .property
   revealDecisionIfNeeded()
  }
  .onChange(of: tradeTarget) { _ in chosenRequest = [] }
  .onChange(of: model.boardSelectionRevision) { _ in
   showTileInformation = true
  }
  .onChange(of: model.game.seed) { _ in
   resetTradeDraft()
   managementSection = .property
   controlsExpanded = false
  }
  .task(id: scenePhase) {
   // Wall time only schedules explicit reducer moves. Price generation itself
   // remains seeded and replayable; leaving the view cancels this local ticker.
   guard scenePhase == .active else { return }
   while !Task.isCancelled {
    do { try await Task.sleep(nanoseconds: 2_000_000_000) }
    catch { return }
    guard !Task.isCancelled && scenePhase == .active else { return }
    model.advanceStockMarket()
    model.advanceBulletin()
   }
  }
  .confirmationDialog("更多", isPresented: $showMore) {
   Button(model.newsEnabled ? "暂停城市快讯" : "开启城市快讯") { model.newsEnabled.toggle() }
   Button(showFinanceHUD ? "隐藏资产悬浮窗" : "显示资产悬浮窗") { showFinanceHUD.toggle() }
   Button(showMarketHUD ? "隐藏股市悬浮窗" : "显示股市悬浮窗") { showMarketHUD.toggle() }
   Button("悬浮窗归位") {
    financeHUDOffset = .zero
    marketHUDOffset = .zero
   }
   Button("完整资产浏览（任何回合）") { showAssetExplorer = true }
   Button("概率小游戏 · 无下注") { showProbabilityLab = true }
   Button(slowSteps ? "移动节奏：舒缓（切标准）" : "移动节奏：标准（切舒缓）") {
    slowSteps.toggle()
   }
   Button(dayFelt ? "切换全局夜间主题" : "切换全局日间主题") {
    dayFelt.toggle()
    if model.scene.supportsDayFelt { model.scene.setDayFelt(dayFelt) }
   }
   Button("重新开局") { showRestart = true }
   Button("本局信息") { showGameInfo = true }
   Button("玩法辞典 · 23 篇") { showGuide = true }
   Button("取消", role: .cancel) {}
  }
  .confirmationDialog("重新开始本局？", isPresented: $showRestart) {
   Button("重开", role: .destructive) { model.reset(seed: VeilopolyNewGameSeed.fresh(excluding: model.game.seed)) }
   Button("取消", role: .cancel) {}
  }
  .confirmationDialog("退出 Veilopoly？", isPresented: $showExitConfirmation) {
   Button("退出游戏", role: .destructive) { exitGame() }
   Button("继续游戏", role: .cancel) {}
  } message: {
   Text("退出后返回上一级界面。当前本地对局会自动保存，下次打开继续。")
  }
  .sheet(isPresented: $showGuide) {
    VeilopolyGuideSheet(isPresented: $showGuide, game: model.game,
                        saveSummary: model.saveSummary)
   }
   .fullScreenCover(isPresented: $showTileInformation) { selectedTileDetailSheet }
    .fullScreenCover(isPresented: $showAssetExplorer) { assetExplorerSheet }
    .fullScreenCover(isPresented: $showManagementWorkspace) { managementWorkspaceSheet }
   .sheet(isPresented: $showProbabilityLab) { probabilityLabSheet }
  .alert("本局信息", isPresented: $showGameInfo) {
   Button("知道了", role: .cancel) {}
  } message: {
   Text("随机种子：\(model.game.seed)\n本局席位：\(model.game.players.count) 名玩家\n\(VeilopolyGuideLibrary.status(model.game))\n地产、银行与模拟股市共用本局现金。\n存档：\(model.saveSummary)")
  }
  .overlay {
    if let target = amountTarget { numberPadOverlay(for: target) }
   }
   .overlay {
    if let card = model.shownCard {
    let editorial = model.shownEditorial
    ZStack {
     // Same ivory / antique-gold / teal scheme as the single main board.
     // Keep the modal intercepting touches until CardRevealGate is dismissed.
     Color(red: 0.09, green: 0.18, blue: 0.18).opacity(0.66).ignoresSafeArea()
     VStack(spacing: 8) {
      // Artwork, event title and category form ONE bookplate-like card header.
      HStack(alignment: .center, spacing: 11) {
       Image(IvoryR1Artwork.preferredCardAlias(isChance: model.shownCardDeck == .chance), bundle: .module)
        .resizable().scaledToFit().frame(width: 66, height: 78)
        .accessibilityHidden(true)
       VStack(alignment: .leading, spacing: 5) {
        Text(VeilopolyCardEditorial.deckName(model.shownCardDeck))
         .font(.system(size: 11, weight: .bold, design: .serif))
         .tracking(2)
         .foregroundColor(Color(red: 0.50, green: 0.37, blue: 0.20))
        Text(editorial?.title ?? "城市来函")
         .font(.system(size: 18, weight: .semibold, design: .serif))
         .foregroundColor(Color(red: 0.12, green: 0.27, blue: 0.28))
         .fixedSize(horizontal: false, vertical: true)
        if let editorial {
         Text(editorial.category)
          .font(.system(size: 10, weight: .medium))
          .foregroundColor(Color(red: 0.45, green: 0.49, blue: 0.42))
        }
       }
       Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      ScrollView {
       if let editorial {
        VStack(spacing: 7) {
         Text(editorial.story)
           .font(.system(size: 16, weight: .regular, design: .serif))
          .foregroundColor(Color(red: 0.25, green: 0.33, blue: 0.32))
          .fixedSize(horizontal: false, vertical: true)
         Rectangle().fill(Color(red: 0.73, green: 0.58, blue: 0.33).opacity(0.65))
          .frame(height: 1).padding(.vertical, 2)
         Text("执行结果")
          .font(.system(size: 10, weight: .bold))
          .tracking(2)
          .foregroundColor(Color(red: 0.50, green: 0.37, blue: 0.18))
         Text(editorial.ruling)
           .font(.system(size: 16, weight: .semibold))
          .foregroundColor(Color(red: 0.12, green: 0.27, blue: 0.28))
          .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
       } else {
        Text(card)
         .font(.system(size: 15, weight: .semibold))
         .foregroundColor(Color(red: 0.14, green: 0.29, blue: 0.30))
         .multilineTextAlignment(.center)
         .frame(maxWidth: .infinity)
       }
      }
      .frame(maxHeight: 180)
      Button("确认并继续") { model.dismissCard() }
       .buttonStyle(AstraB01ButtonStyle())
       .frame(minWidth: 160, minHeight: 44)
       .accessibilityHint("阅读卡牌与执行结果，然后继续游戏")
     }
     .frame(maxWidth: 520).padding(18)
     .background {
      RoundedRectangle(cornerRadius: 19, style: .continuous)
       .fill(Color(red: 0.97, green: 0.94, blue: 0.87))
       .overlay {
        RoundedRectangle(cornerRadius: 19, style: .continuous)
         .strokeBorder(Color(red: 0.69, green: 0.53, blue: 0.30), lineWidth: 2)
       }
       .shadow(color: Color(red: 0.13, green: 0.23, blue: 0.23).opacity(0.27),
               radius: 14, y: 7)
       .allowsHitTesting(false)
     }
     .padding(.horizontal, 16)
     .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
    .zIndex(100)
   }
  }
 }

 private func revealDecisionIfNeeded() {
  guard !model.pending, model.waitingForHuman || model.game.winner != nil,
        VeilopolyGamePresentation.requiresDecision(model.game.turn.phase) else { return }
  withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { controlsExpanded = true }
 }

 private func resetTradeDraft() {
  chosenOffer = []; chosenRequest = []; offerCash = "0"; requestCash = "0"
  tradeTarget = model.game.players.first { $0.id != model.actor && !$0.bankrupt }?.id ?? model.actor
 }

 // The board always uses the largest aspect-fit size allowed by safe-area
 // geometry. A floating capsule/drawer never steals permanent board width.
 // This keeps all 40 cells visible rather than stretching or cropping the map.
 private func landscapeContent(availableWidth: CGFloat, availableHeight: CGFloat) -> some View {
  let measured = VeilopolyLandscapeLayout.maximizedBoardSize(
   availableWidth: Double(availableWidth),
   availableHeight: Double(availableHeight))
  let boardWidth = CGFloat(measured.width)
  let boardHeight = CGFloat(measured.height)
  let drawerWidth = CGFloat(VeilopolyLandscapeLayout.overlayDrawerWidth(for: Double(availableWidth)))
  let drawerHeight = CGFloat(VeilopolyLandscapeLayout.overlayDrawerHeight(for: Double(availableHeight)))
  let bulletinWidth = CGFloat(VeilopolyLandscapeLayout.bulletinWidth(
   availableWidth: Double(availableWidth), boardWidth: Double(boardWidth)))
  return ZStack(alignment: .topTrailing) {
   boardViewport
    .frame(width: boardWidth, height: boardHeight)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(.horizontal, CGFloat(VeilopolyLandscapeLayout.boardHorizontalInset))
    .padding(.vertical, CGFloat(VeilopolyLandscapeLayout.boardVerticalInset))
    .zIndex(0)

   if controlsExpanded {
    controlsDrawer
     .environment(\.colorScheme, .dark)
     .frame(width: drawerWidth, height: drawerHeight)
     .padding(.top, CGFloat(VeilopolyLandscapeLayout.drawerTopInset))
     .padding(.trailing, 6)
     .transition(.move(edge: .trailing).combined(with: .opacity))
     .zIndex(1)
   }

   // The top-right capsule is RESERVED for More / Exit only.
   // Do not put gameplay toggles next to Exit: an accidental tap is costly.
   VStack(alignment: .trailing, spacing: 8) {
    capsuleControls
    Spacer(minLength: 0)
    if !controlsExpanded {
     // Daily gameplay operations have their own bottom-right entry.
     collapsedStatusButton
      .transition(.opacity)
    }
   }
   .padding(.trailing, 6)
   .padding(.vertical, 5)
   .zIndex(2)
  }
  .overlay(alignment: .topLeading) {
   if model.newsEnabled, let notice = model.bulletinFeed.current, bulletinWidth >= 90 {
    VeilopolyNewsTicker(notice: notice)
     .id(notice.id)
     .frame(width: bulletinWidth)
     .padding(.leading, boardWidth + 16)
     .padding(.top, 10)
   }
  }
  .frame(width: availableWidth, height: availableHeight)
   .overlay(alignment: .topTrailing) {
    if !controlsExpanded {
     floatingHUDs(rightSpace: availableWidth - boardWidth, viewportHeight: availableHeight)
       .padding(.top, 62).padding(.trailing, 8)
    }
   }
  }

  /// Keep Astra's real actions and HUD. Only the panel's placement changes:
 /// on iPhone it floats over otherwise unused right-side space; on iPad it
 /// may temporarily cover the board edge until collapsed.
 private var controlsDrawer: some View {
  VStack(alignment: .leading, spacing: 8) {
   HStack(spacing: 8) {
    // Far-left inside the floating drawer; not near the top-right Exit.
    Button {
     withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
      controlsExpanded = false
     }
    } label: {
     Label("收起", systemImage: "chevron.right")
      .font(.caption.weight(.semibold))
      .frame(minWidth: CGFloat(VeilopolyLandscapeLayout.drawerCloseMinWidth),
             minHeight: CGFloat(VeilopolyLandscapeLayout.capsuleTouchHeight))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(.white.opacity(0.12), in: Capsule())
    .accessibilityLabel("收起操作面板")
    .accessibilityHint("返回最大化棋盘；与退出按钮分离")
    Button { showAssetExplorer = true } label: {
     Label("资产查看", systemImage: "square.grid.2x2")
      .font(.system(size: 13, weight: .semibold))
      .frame(minHeight: 44)
    }
    .buttonStyle(.plain)
    .accessibilityHint("不需要购买地产，也可以随时查看全部资产")
    Text("操作面板")
     .font(.system(size: 15, weight: .bold, design: .rounded))
     .lineLimit(1)
     .minimumScaleFactor(0.8)
    Spacer(minLength: 0)
    Text(phaseLabel(model.game.turn.phase))
     .font(.caption2.weight(.semibold))
     .foregroundStyle(.mint)
     .lineLimit(1)
   }
   .frame(minHeight: CGFloat(VeilopolyLandscapeLayout.capsuleTouchHeight))
   // Browsing is always allowed. Actual transactions remain phase-gated.
   managementNavigation
   if model.game.turn.phase == .tileResolve,
      let tileID = model.game.turn.pendingPurchase,
      model.waitingForHuman && !model.pending {
    purchaseDecisionBar(tileID: tileID)
   }
   ScrollView(.vertical) {
    VStack(alignment: .leading, spacing: 10) {
     HStack {
      Text(model.game.players[model.actor].name).font(.subheadline.weight(.semibold))
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
       Text("现金 ¥\(model.game.players[model.actor].cash)").font(.caption.monospacedDigit())
       Text("净资产 ¥\(netWorth(model.game.players[model.actor]))")
        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
      }
     }
     .accessibilityElement(children: .combine)
     // Immediate decisions come first; account details are available below.
     actionPanel
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AstraB01PanelSkin(.action))
     if model.game.turn.phase != .manage { readOnlyOverviewShortcut }
     tileInspector
     playerStrip
     HStack(alignment: .top, spacing: 7) {
      Image(systemName: "sparkles").foregroundStyle(.mint)
      Text(model.lastFeedback)
       .font(.caption.weight(.medium))
       .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
     }
     .padding(9)
     .frame(maxWidth: .infinity, alignment: .leading)
     .background(AstraB01PanelSkin(.glass))
     .accessibilityLabel("最近事件：\(model.lastFeedback)")
     if let error = model.errorMessage {
      VStack(alignment: .leading, spacing: 5) {
       Label("操作未完成：\(error)", systemImage: "exclamationmark.triangle.fill")
        .font(.caption.weight(.semibold))
       if let advice = model.errorAdvice {
        Text(advice)
         .font(.caption2)
         .fixedSize(horizontal: false, vertical: true)
        Button("查看玩法辞典") { showGuide = true }
         .font(.caption.weight(.semibold))
         .foregroundColor(Color(red: 0.98, green: 0.87, blue: 0.67))
         .frame(minHeight: 44, alignment: .leading)
         .accessibilityHint("打开规则说明，无需放弃当前对局")
       }
      }
      .foregroundColor(.white)
      .padding(.horizontal, 12).padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(AstraB01FeedbackSkin(error: true))
      .accessibilityElement(children: .combine)
     }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
   }
   // Preserve scrolling position across phase changes.
   // iOS 15: keep system scroll indicators; .scrollIndicators(_:) is a later API.
   if model.game.turn.phase == .manage && model.waitingForHuman {
    action(model.game.turn.rolledDouble ? "继续额外回合" : "结束回合", symbol: "checkmark.circle") {
     model.perform(.endTurn)
    }
    .disabled(model.pending)
   }
  }
  .padding(10)
  .background(AstraB01PanelSkin(.action))
  .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  .overlay {
   RoundedRectangle(cornerRadius: 18)
    .stroke(Color(red: 0.73, green: 0.59, blue: 0.34).opacity(0.78), lineWidth: 1.3)
    .allowsHitTesting(false)
  }
  .shadow(color: .black.opacity(0.42), radius: 14, x: -5, y: 7)
  .accessibilityElement(children: .contain)
 }

 private var managementNavigation: some View {
  HStack(spacing: 5) {
   ForEach(VeilopolyManagementSection.allCases) { section in
    Button {
     managementSection = section
     if model.game.turn.phase != .manage {
      showAssetExplorer = true
     } else if !showAssetExplorer && !showManagementWorkspace {
      showManagementWorkspace = true
     }
    } label: {
     VStack(spacing: 3) {
      Image(systemName: section.symbol)
      Text(section.rawValue)
     }
     .font(.system(size: 13, weight: .semibold))
     .frame(maxWidth: .infinity, minHeight: 50)
     .contentShape(Rectangle())
     .foregroundStyle(managementSection == section ? Color.mint : Color.white.opacity(0.65))
     .background(managementSection == section ? Color.white.opacity(0.12) : .clear,
                 in: RoundedRectangle(cornerRadius: 9))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(managementSection == section ? .isSelected : [])
   }
  }
 }

 /// Bottom-right gameplay entry is separated from the top-right More/Exit
 /// capsule. This live status button replaces the permanent wide sidebar.
 private var collapsedStatusButton: some View {
  Button {
   withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
    controlsExpanded = true
   }
  } label: {
   HStack(spacing: 10) {
    playerToken(model.actor).frame(width: 32, height: 36)
    VStack(alignment: .leading, spacing: 2) {
     Text("\(model.game.players[model.actor].name) · \(phaseLabel(model.game.turn.phase))")
      .font(.caption.weight(.semibold))
      .lineLimit(1)
     Text("¥\(model.game.players[model.actor].cash) · " +
          (model.pending ? "动画中" : (model.waitingForHuman ? "点击进行操作" : "AI 行动中")))
      .font(.caption2)
      .lineLimit(1)
    }
    Image(systemName: "chevron.left")
     .font(.caption.weight(.bold))
   }
   .foregroundStyle(.white)
   .padding(.horizontal, 14)
   .padding(.vertical, 10)
   .frame(minHeight: CGFloat(VeilopolyLandscapeLayout.capsuleTouchHeight))
   .background(AstraB01PanelSkin(.glass))
   .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
   .overlay {
    RoundedRectangle(cornerRadius: 13)
     .stroke(Color(red: 0.73, green: 0.59, blue: 0.34), lineWidth: 1)
     .allowsHitTesting(false)
   }
  }
  .buttonStyle(.plain)
  .accessibilityLabel("展开操作面板，当前\(model.game.players[model.actor].name)，\(phaseLabel(model.game.turn.phase))")
  .accessibilityHint("可使用掷骰、购买、拍卖、交易、银行和管理功能")
 }

 private var boardViewport: some View {
  GeometryReader { box in
   let measured = VeilopolyLandscapeLayout.boardSize(availableWidth: Double(box.size.width),
                                                      availableHeight: Double(box.size.height))
   let width = CGFloat(measured.width)
   let height = CGFloat(measured.height)
   SpriteView(scene: model.scene, options: [.ignoresSiblingOrder])
    .frame(width: width, height: height)
    .background(dayFelt ? Color(red: 0.94, green: 0.91, blue: 0.83)
                         : Color(red: 0.07, green: 0.12, blue: 0.14),
                in: RoundedRectangle(cornerRadius: 12))
    .overlay {
     RoundedRectangle(cornerRadius: 12)
      .strokeBorder(Color(red: 0.69, green: 0.53, blue: 0.29).opacity(0.9), lineWidth: 1.5)
      .allowsHitTesting(false)
    }
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
   Button {
     model.selectedTile = (model.selectedTile + 39) % 40
     showTileInformation = true
    } label: {
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
    if let lore = VeilopolyWorldEditorial.page(for: tile) {
     Text("\(lore.title) · \(lore.teaser)")
      .font(.system(size: 10, weight: .regular, design: .serif))
      .foregroundColor(Color(red: 0.79, green: 0.70, blue: 0.49))
      .lineLimit(2)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityLabel("城市札记：\(lore.title)，\(lore.teaser)")
    }
   }
   .frame(maxWidth: .infinity, alignment: .leading)
   Button {
     model.selectedTile = (model.selectedTile + 1) % 40
     showTileInformation = true
    } label: {
    Image(systemName: "chevron.right").frame(width: 44, height: 44)
   }
   .buttonStyle(.plain)
   .accessibilityLabel("查看下一格")
  }
  .padding(.horizontal, 5)
  .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
  .accessibilityElement(children: .contain)
 }

 
 // Read-only inspection does not commit a move or advance the turn.
 private var selectedTileDetailSheet: some View {
  let tile = model.game.board[model.selectedTile]
  let owner = tile.owner.map { model.game.players[$0].name } ?? "未出售"
  return NavigationView {
   ScrollView {
    VStack(alignment: .leading, spacing: 14) {
     Text("#\(tile.i) · \(tile.name)")
      .font(.system(size: 24, weight: .bold, design: .rounded))
     Text(tile.purchasable ? "价格 ¥\(tile.price) · \(owner)" : "特殊地块 · \(owner)")
      .font(.title3).foregroundStyle(.secondary)
     if tile.purchasable {
      Text("基础租金 ¥\(tile.rent.first ?? 0)").font(.headline.monospacedDigit())
      Text(tile.mortgaged ? "已抵押" : "未抵押").font(.subheadline)
     }
     if let deed = VeilopolyCivicText.deed(model.game, tileIndex: tile.i) {
      VeilopolyCivicDocumentPanel(document: deed)
     }
     if let lore = VeilopolyWorldEditorial.page(for: tile) {
      Text(lore.title).font(.headline)
      Text(lore.teaser).font(.body).fixedSize(horizontal: false, vertical: true)
     }
     Text("只读地块档案，不会触发购买、拍卖、抵押或结束回合。")
      .font(.footnote).foregroundStyle(.secondary)
    }
    .frame(maxWidth: 540, alignment: .leading)
    .padding(20)
   }
   .navigationTitle("地块档案")
   .navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement: .confirmationAction) {
     Button("返回棋盘") { showTileInformation = false }
    }
   }
  }
  .navigationViewStyle(.stack)
  .preferredColorScheme(dayFelt ? .light : .dark)
 }

 
 private func numericEntry(_ title: String, value: String,
                           target: VeilopolyAmountTarget) -> some View {
  Button { amountTarget = target } label: {
   HStack(spacing: 5) {
    Text(title).font(.caption2).lineLimit(1)
    Spacer(minLength: 4)
    Text(value.isEmpty ? "输入" : value)
     .font(.system(size: 15, weight: .bold, design: .monospaced))
     .lineLimit(1)
    Image(systemName: "number").font(.caption2).accessibilityHidden(true)
   }
   .padding(.horizontal, 10)
   .frame(maxWidth: .infinity, minHeight: 44)
   .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
   .contentShape(Rectangle())
  }
  .buttonStyle(.plain)
  .accessibilityLabel("\(title)，当前 \(value)，点击修改")
 }

 private func numericBinding(_ target: VeilopolyAmountTarget) -> Binding<String> {
  switch target {
  case .bid: return $bidderCash
  case .bankAmount: return $bankAmount
  case .bankPeriods: return $bankPeriods
  case .offerCash: return $offerCash
  case .requestCash: return $requestCash
  case .stockShares: return $stockShares
  }
 }

 /// A landscape-friendly in-app number pad prevents the native keyboard
 /// from covering the bank, auction, trade and stock-order controls.
 private func numberPadOverlay(for target: VeilopolyAmountTarget) -> some View {
  let input = numericBinding(target)
  return ZStack {
   Color.black.opacity(0.78).ignoresSafeArea()
    .onTapGesture { amountTarget = nil }
   VStack(spacing: 7) {
    Text(target.title).font(.headline)
    Text(input.wrappedValue.isEmpty ? "0" : input.wrappedValue)
     .font(.system(size: 27, weight: .bold, design: .monospaced))
     .frame(maxWidth: .infinity, minHeight: 37)
     .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
     .accessibilityLabel("\(target.title)，\(input.wrappedValue)")
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
              spacing: 7) {
     ForEach(["1","2","3","4","5","6","7","8","9","清空","0","删除"], id: \.self) { digit in
      Button {
       switch digit {
       case "清空": input.wrappedValue = ""
       case "删除":
        if !input.wrappedValue.isEmpty { input.wrappedValue.removeLast() }
       default:
        if input.wrappedValue.count < 9 {
         input.wrappedValue = input.wrappedValue == "0" ? digit : input.wrappedValue + digit
        }
       }
      } label: {
       Text(digit).font(.system(size: digit.count > 1 ? 14 : 21, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 43)
        .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 9))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(digit)
     }
    }
    Button("完成") { amountTarget = nil }
     .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
     .background(Color(red: 0.63, green: 0.48, blue: 0.28),
                 in: RoundedRectangle(cornerRadius: 9))
     .buttonStyle(.plain)
   }
   .foregroundColor(.white)
   .padding(13)
   .frame(maxWidth: 350)
   .background(Color(red: 0.08, green: 0.16, blue: 0.19),
               in: RoundedRectangle(cornerRadius: 18))
   .overlay {
    RoundedRectangle(cornerRadius: 18)
     .stroke(Color(red: 0.72, green: 0.58, blue: 0.38), lineWidth: 1)
   }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
 }

 
 /// Draggable, read-only mini windows are opt-in from More. They live in
 /// the unused landscape space, never in a full-screen gesture layer.


 /// Layout never reaches over the board. On narrow phones the two cards stack.
 /// Only each card's 44pt grip moves it; tapping the data opens the browser.
 @ViewBuilder private func floatingHUDs(rightSpace: CGFloat, viewportHeight: CGFloat) -> some View {
  let maxY = max(0, viewportHeight - 62 - 74 - 95)
  if rightSpace >= 320 {
   HStack(alignment: .top, spacing: 8) {
    if showFinanceHUD {
     financeMiniCard(
      minX: showMarketHUD ? -max(0, rightSpace - 312) : -max(0, rightSpace - 156),
      maxX: showMarketHUD ? 156 : 0, maxY: maxY)
    }
    if showMarketHUD {
     marketMiniCard(minX: -max(0, rightSpace - 156), maxX: 0, maxY: maxY)
    }
   }
   .foregroundColor(.white)
  } else if rightSpace >= 170 {
   VStack(alignment: .trailing, spacing: 6) {
    if showFinanceHUD {
     financeMiniCard(minX: -max(0, rightSpace - 156), maxX: 0, maxY: maxY)
    }
    if showMarketHUD {
     marketMiniCard(minX: -max(0, rightSpace - 156), maxX: 0,
                    maxY: max(0, maxY - (showFinanceHUD ? 80 : 0)))
    }
   }
   .foregroundColor(.white)
  }
 }

 private func clampHUD(_ current: CGSize, delta: CGSize,
                       minX: CGFloat, maxX: CGFloat, maxY: CGFloat) -> CGSize {
  CGSize(width: max(minX, min(maxX, current.width + delta.width)),
         height: max(0, min(maxY, current.height + delta.height)))
 }

 private func financeMiniCard(minX: CGFloat, maxX: CGFloat, maxY: CGFloat) -> some View {
  let shift = clampHUD(financeHUDOffset, delta: financeHUDDrag,
                       minX: minX, maxX: maxX, maxY: maxY)
  return HStack(spacing: 0) {
   Button {
    managementSection = .bank
    showAssetExplorer = true
   } label: {
    VStack(alignment: .leading, spacing: 3) {
     Label("资产", systemImage: "building.columns")
      .font(.system(size: 13, weight: .semibold))
     Text("¥\(model.game.players[model.actor].cash)")
      .font(.system(size: 14, weight: .bold, design: .monospaced))
      .lineLimit(1)
    }
    .padding(.leading, 9)
    .frame(width: 104, height: 64, alignment: .leading)
    .contentShape(Rectangle())
   }
   .buttonStyle(.plain)
   .accessibilityLabel("查看资产详情")
   Image(systemName: "hand.draw")
    .font(.system(size: 16, weight: .semibold))
    .foregroundColor(.white.opacity(0.85))
    .frame(width: 44, height: 64)
    .background(.white.opacity(0.08))
    .contentShape(Rectangle())
    .gesture(DragGesture(minimumDistance: 6)
     .updating($financeHUDDrag) { gesture, state, _ in
      state = gesture.translation
     }
     .onEnded { gesture in
      financeHUDOffset = clampHUD(financeHUDOffset, delta: gesture.translation,
                                  minX: minX, maxX: maxX, maxY: maxY)
     })
    .accessibilityLabel("拖动资产悬浮窗")
  }
  .frame(width: 148, height: 64)
  .background(miniCardColor, in: RoundedRectangle(cornerRadius: 11))
  .overlay {
   RoundedRectangle(cornerRadius: 11)
    .strokeBorder(Color(red: 0.68, green: 0.55, blue: 0.32), lineWidth: 1)
    .allowsHitTesting(false)
  }
  .offset(x: shift.width, y: shift.height)
 }

 private func marketMiniCard(minX: CGFloat, maxX: CGFloat, maxY: CGFloat) -> some View {
  let shift = clampHUD(marketHUDOffset, delta: marketHUDDrag,
                       minX: minX, maxX: maxX, maxY: maxY)
  return HStack(spacing: 0) {
   Button {
    managementSection = .market
    showAssetExplorer = true
   } label: {
    VStack(alignment: .leading, spacing: 3) {
     Label("模拟股市", systemImage: "chart.xyaxis.line")
      .font(.system(size: 12, weight: .semibold))
     Text(firstQuoteSummary)
      .font(.system(size: 12, weight: .bold, design: .monospaced))
      .lineLimit(1)
      .minimumScaleFactor(0.85)
    }
    .padding(.leading, 9)
    .frame(width: 104, height: 64, alignment: .leading)
    .contentShape(Rectangle())
   }
   .buttonStyle(.plain)
   .accessibilityLabel("查看虚构股票行情")
   Image(systemName: "hand.draw")
    .font(.system(size: 16, weight: .semibold))
    .foregroundColor(.white.opacity(0.85))
    .frame(width: 44, height: 64)
    .background(.white.opacity(0.08))
    .contentShape(Rectangle())
    .gesture(DragGesture(minimumDistance: 6)
     .updating($marketHUDDrag) { gesture, state, _ in
      state = gesture.translation
     }
     .onEnded { gesture in
      marketHUDOffset = clampHUD(marketHUDOffset, delta: gesture.translation,
                                 minX: minX, maxX: maxX, maxY: maxY)
     })
    .accessibilityLabel("拖动股市悬浮窗")
  }
  .frame(width: 148, height: 64)
  .background(miniCardColor, in: RoundedRectangle(cornerRadius: 11))
  .overlay {
   RoundedRectangle(cornerRadius: 11)
    .strokeBorder(Color(red: 0.68, green: 0.55, blue: 0.32), lineWidth: 1)
    .allowsHitTesting(false)
  }
  .offset(x: shift.width, y: shift.height)
 }

 private var miniCardColor: Color { Color(red: 0.08, green: 0.19, blue: 0.22) }
 
 private var firstQuoteSummary: String {
  guard let quote = IntegratedBanking.ledger(model.game).market?.quotes.first else {
   return "行情未开放"
  }
  let whole = quote.currentPriceCents / 100
  let fraction = abs(quote.currentPriceCents % 100)
  return "\(quote.symbol) ¥\(whole).\(String(format: "%02d", fraction))"
 }


 // Read-only browsing never depends on turn.phase and never calls the reducer.
 private var readOnlyOverviewShortcut: some View {
  Button { showAssetExplorer = true } label: {
   Label("无需购买，先查看地产 / 银行 / 股票 / 交易",
         systemImage: "info.circle")
    .font(.system(size: 13, weight: .semibold))
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .contentShape(Rectangle())
  }
  .buttonStyle(.plain)
  .foregroundColor(.mint)
  .accessibilityHint("打开只读浏览器，不会提交购买或竞价")
 }


 /// Full-size editable management surface. Kept entirely outside the thin
 /// turn-status drawer; the reducer still rejects operations in wrong phases.
 private var managementWorkspaceSheet: some View {
  NavigationView {
   VStack(alignment: .leading, spacing: 10) {
    HStack(spacing: 12) {
     Label(model.game.players[model.actor].name, systemImage: "person.crop.circle")
      .font(.headline)
     Spacer(minLength: 6)
     Text("现金 ¥\(model.game.players[model.actor].cash)")
      .font(.system(size: 16, weight: .bold, design: .monospaced))
     Text("净资产 ¥\(netWorth(model.game.players[model.actor]))")
      .font(.system(size: 14, weight: .medium, design: .monospaced))
    }
    .lineLimit(1)
    managementNavigation
    Divider()
    ScrollView(.vertical) {
     managePanel
      .frame(maxWidth: 760, alignment: .leading)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    HStack(spacing: 12) {
     Button("返回棋盘（保留回合）") { showManagementWorkspace = false }
      .frame(maxWidth: .infinity, minHeight: 48)
      .buttonStyle(.bordered)
     Button(model.game.turn.rolledDouble ? "额外回合" : "结束本回合") {
      showManagementWorkspace = false
      model.perform(.endTurn)
     }
     .frame(maxWidth: .infinity, minHeight: 48)
     .buttonStyle(.borderedProminent)
     .disabled(model.pending || !model.waitingForHuman || model.game.turn.phase != .manage)
    }
   }
   .padding(16)
   .navigationTitle("资产工作台")
   .navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement: .confirmationAction) {
     Button("完成") { showManagementWorkspace = false }
    }
   }
  }
  .navigationViewStyle(.stack)
  .preferredColorScheme(.dark)
  .overlay {
   if let target = amountTarget { numberPadOverlay(for: target) }
  }
  .onDisappear { amountTarget = nil }
 }

 private var assetExplorerSheet: some View {
  NavigationView {
   VStack(spacing: 10) {
    Text("全部信息均可先看；浏览不代表同意购买、拍卖或交易。")
     .font(.subheadline)
     .foregroundStyle(.secondary)
     .frame(maxWidth: .infinity, alignment: .leading)
    managementNavigation
    ScrollView {
     assetOverviewContents
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
    }
   }
   .padding(16)
   .navigationTitle("资产与城市信息")
   .navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement: .confirmationAction) {
     Button("返回对局") { showAssetExplorer = false }
    }
   }
  }
  .navigationViewStyle(.stack)
  .preferredColorScheme(dayFelt ? .light : .dark)
 }

 @ViewBuilder private var assetOverviewContents: some View {
  switch managementSection {
  case .property: assetPropertyContents
  case .bank: assetBankContents
  case .market: assetMarketContents
  case .trade: assetTradeContents
  }
 }

 private var assetPropertyContents: some View {
  VStack(alignment: .leading, spacing: 10) {
   Text("40 格地产与建筑").font(.headline)
   if model.game.board.indices.contains(overviewTile) {
    let tile = model.game.board[overviewTile]
    Text("当前查看：#\(tile.i) · \(tile.name)")
     .font(.title3.weight(.semibold))
    Text(tile.purchasable
         ? "价格 ¥\(tile.price) · 基础租金 ¥\(tile.rent.first ?? 0)"
         : "特殊地块")
     .font(.subheadline)
    Text(tile.owner.map { "业主：\(model.game.players[$0].name)" } ?? "无主")
     .foregroundStyle(.secondary)
    if let deed = VeilopolyCivicText.deed(model.game, tileIndex: overviewTile) {
     VeilopolyCivicDocumentPanel(document: deed)
    }
   }
   ForEach(model.game.board, id: \.i) { tile in
    Button { overviewTile = tile.i } label: {
     HStack {
      Text("#\(tile.i) · \(tile.name)")
       .lineLimit(1)
      Spacer(minLength: 10)
      Text(tile.owner.map { model.game.players[$0].name } ?? "无主")
       .foregroundColor(.secondary)
     }
     .padding(.horizontal, 8)
     .frame(minHeight: 44)
     .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
   }
  }
 }

 private var assetBankContents: some View {
  VStack(alignment: .leading, spacing: 12) {
   Text("银行账户与债务").font(.headline)
   Text("现金 ¥\(model.game.players[model.actor].cash)")
    .font(.title3.monospacedDigit())
   Text("账面净资产 ¥\(netWorth(model.game.players[model.actor]))")
    .font(.headline.monospacedDigit())
   if let ledger = model.game.banking,
      ledger.accounts.indices.contains(model.actor) {
    let account = ledger.accounts[model.actor]
    Text("存款本金 ¥\(account.savings.reduce(0) { $0 + $1.principal })")
    Text("贷款待还 ¥\(account.loans.reduce(0) { $0 + $1.totalDue })")
    Text("持有投资：\(account.positions.count) 项")
    Text("账期：\(ledger.completedTurns)")
   }
   if let digest = VeilopolyBankAutomation.digest(model.game, player: model.actor) {
    Text(digest.memorandum)
     .fixedSize(horizontal: false, vertical: true)
   }
   Text("这里只显示账户状态；存取款及贷款需满足当前规则。")
    .font(.footnote).foregroundStyle(.secondary)
  }
 }

 private var assetMarketContents: some View {
  let ledger = IntegratedBanking.ledger(model.game)
  let market = ledger.market ?? StockMarketEngine.initial(seed: model.game.seed)
  return VStack(alignment: .leading, spacing: 12) {
   Text("五只虚构股票").font(.headline)
   Text("行情只用于当前离线棋局，非真实证券价格。")
    .font(.footnote).foregroundStyle(.secondary)
   ForEach(market.quotes) { quote in
    HStack(spacing: 8) {
     Text(quote.symbol)
      .font(.headline.monospaced())
     Spacer(minLength: 8)
     Text("¥\(quote.currentPriceCents / 100).\(String(format: "%02d", abs(quote.currentPriceCents % 100)))")
      .font(.system(.body, design: .monospaced))
     if quote.isHalted { Text("暂停").foregroundColor(.orange) }
    }
    .frame(minHeight: 44)
   }
   Text("只读浏览不会提交订单；买卖按钮只在合法管理阶段生效。")
    .font(.footnote).foregroundStyle(.secondary)
  }
 }

 private var assetTradeContents: some View {
  VStack(alignment: .leading, spacing: 12) {
   Text("玩家与产权分布").font(.headline)
   ForEach(model.game.players, id: \.id) { player in
    VStack(alignment: .leading, spacing: 4) {
     Text(player.name).font(.headline)
     Text("现金 ¥\(player.cash) · 地产 \(model.game.board.filter { $0.owner == player.id }.count) 处")
      .font(.subheadline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
   }
   if model.game.trade == nil {
    Text("当前无待确认的交易。")
   } else {
    Text("当前存在待确认交易。")
   }
   Text("交易信息可随时查看，但发起或接受交易仍需合法回合。")
    .font(.footnote).foregroundStyle(.secondary)
  }
 }


 // A standalone educational chance toy — NO wagering, currency movement,
 // purchases, account integration, cash-outs, or effect on the saved match.
 private var probabilityLabSheet: some View {
  NavigationView {
   VStack(spacing: 18) {
    Label("骰子概率体验", systemImage: "die.face.5")
     .font(.title2.weight(.bold))
    Text("你可以预测一个六面骰子的奇偶，观察理论概率与实际结果。每次预测的命中率理论上都是 1/2。")
     .font(.body)
     .fixedSize(horizontal: false, vertical: true)
    HStack(spacing: 16) {
     Button("预测奇数") { rollProbabilityDie(guessEven: false) }
      .buttonStyle(.borderedProminent)
      .frame(minHeight: 44)
     Button("预测偶数") { rollProbabilityDie(guessEven: true) }
      .buttonStyle(.borderedProminent)
      .frame(minHeight: 44)
    }
    if let face = probabilityLastRoll {
     Text("本轮骰子：\(face)")
      .font(.system(size: 27, weight: .bold, design: .rounded))
    }
    Text("练习次数：\(probabilityAttempts) · 预测正确：\(probabilityMatches)")
     .font(.headline.monospacedDigit())
    Text("这是独立的概率体验，没有押注、奖池、游戏币损益、兑换或付费。")
     .font(.footnote)
     .foregroundStyle(.secondary)
    Spacer(minLength: 0)
   }
   .padding(22)
   .frame(maxWidth: 520)
   .navigationTitle("概率实验室")
   .navigationBarTitleDisplayMode(.inline)
   .toolbar {
    ToolbarItem(placement: .confirmationAction) {
     Button("返回") { showProbabilityLab = false }
    }
   }
  }
  .navigationViewStyle(.stack)
  .preferredColorScheme(.dark)
 }

 private func rollProbabilityDie(guessEven: Bool) {
  let face = Int.random(in: 1...6)
  probabilityLastRoll = face
  probabilityAttempts += 1
  if (face % 2 == 0) == guessEven { probabilityMatches += 1 }
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
  model.flushSave()
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
    .overlay(alignment: .leading) {
     playerToken(p.id)
      .frame(width: 34, height: 38)
      .padding(2)
      .background(Color(red: 0.08, green: 0.14, blue: 0.18), in: RoundedRectangle(cornerRadius: 9))
      .padding(.leading, 5)
      .allowsHitTesting(false)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(p.name)，现金 ¥\(p.cash)，" +
      (p.bankrupt ? "已破产" : p.jailTurns > 0 ? "在监狱" : "位于第 \(p.position) 格") +
      (p.id == model.actor ? "，当前行动玩家" : ""))
   }
  }
 }
 private func playerToken(_ player: Int) -> some View {
  let name = AstraDetailArtwork.tokenCandidates(for: player)
   .first { AstraDetailArtwork.resourceURL($0) != nil } ?? "pawnBlue"
  return Image(name, bundle: .module).resizable().scaledToFit().accessibilityHidden(true)
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
  else if model.game.turn.phase == .manage && model.waitingForHuman {
   VStack(alignment: .leading, spacing: 8) {
    Label("可管理资产", systemImage: "square.grid.2x2")
     .font(.headline)
    Text("银行、地产、模拟股市与交易统一在全屏工作台操作。")
     .font(.system(size: 13))
     .fixedSize(horizontal: false, vertical: true)
    action("打开资产工作台", symbol: "rectangle.expand.vertical") {
     showManagementWorkspace = true
    }
    .disabled(model.pending)
   }
  }
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
      VStack(alignment: .leading, spacing: 7) {
       Label("落到 \(model.game.board[i].name)", systemImage: "building.2")
        .font(.system(size: 15, weight: .bold))
       Text("价格 ¥\(model.game.board[i].price) · 基础租金 ¥\(model.game.board[i].rent.first ?? 0)")
        .font(.system(size: 14, weight: .medium, design: .monospaced))
       Button("查看完整产权与租金说明") {
        model.selectedTile = i
        showTileInformation = true
       }
       .font(.system(size: 14, weight: .semibold))
       .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      }
     }
    case .auction: auctionPanel
   case .manage: managePanel
   case .trade: tradeResponsePanel
   case .debt:
    VStack(alignment: .leading, spacing: 10) {
     Label("债务清算", systemImage: "exclamationmark.triangle").font(.headline)
     if let notice = VeilopolyCivicText.debt(model.game) {
      VeilopolyCivicDocumentPanel(document: notice)
     }
     Text("可用资产已按本局规则尝试处置，请确认剩余债务清算。")
      .font(.caption2).foregroundStyle(.secondary)
     action("确认破产", symbol: "exclamationmark.triangle") { model.perform(.declareBankruptcy) }
    }
   default: EmptyView()
   }
  }
 }

 /// Always visible above the scrollable content on purchase decisions.
 private func purchaseDecisionBar(tileID: Int) -> some View {
  let tile = model.game.board[tileID]
  return VStack(alignment: .leading, spacing: 6) {
   Text("抵达 \(tile.name) · 自由选择")
    .font(.system(size: 14, weight: .bold))
    .lineLimit(1)
   HStack(spacing: 8) {
    action("直接路过", symbol: "figure.walk", secondary: true) {
     model.perform(.skipPurchase, tile: tileID)
    }
    action("购买 ¥\(tile.price)", symbol: "house.fill") {
     model.perform(.buyProperty, tile: tileID)
    }
    .disabled(model.game.players[model.actor].cash < tile.price)
   }
   HStack(spacing: 8) {
    action("公开拍卖", symbol: "gavel", secondary: true) {
     model.perform(.startAuction, tile: tileID)
    }
    action("查看地块", symbol: "info.circle", secondary: true) {
     model.selectedTile = tileID
     showTileInformation = true
    }
   }
   Text("直接路过不扣款、不拍卖，地产仍无主。")
    .font(.system(size: 12, weight: .medium))
    .fixedSize(horizontal: false, vertical: true)
    .foregroundStyle(.white.opacity(0.82))
  }
  .padding(8)
  .background(Color(red: 0.06, green: 0.23, blue: 0.24),
              in: RoundedRectangle(cornerRadius: 12))
  .accessibilityElement(children: .contain)
 }

 private func action(_ title: String, symbol: String,
                     secondary: Bool = false, pressed: @escaping () -> Void) -> some View {
  Button(action: pressed) {
   HStack(spacing: 8) {
    Image(systemName: symbol)
     .font(.system(size: 17, weight: .semibold))
     .frame(width: 22, height: 22)
     .accessibilityHidden(true)
    Text(title)
     .font(.system(size: 14, weight: .semibold))
     .lineLimit(2)
     .minimumScaleFactor(0.9)
   }
   .foregroundColor(.white)
   .padding(.horizontal, 10)
   .frame(maxWidth: .infinity, minHeight: 48)
   .background(secondary
               ? Color(red: 0.17, green: 0.28, blue: 0.33)
               : Color(red: 0.44, green: 0.34, blue: 0.18),
               in: RoundedRectangle(cornerRadius: 11, style: .continuous))
   .overlay {
    RoundedRectangle(cornerRadius: 11)
     .strokeBorder(Color(red: 0.75, green: 0.60, blue: 0.35).opacity(0.85),
                   lineWidth: 1)
     .allowsHitTesting(false)
   }
   .contentShape(Rectangle())
  }
  .buttonStyle(.plain)
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

 /// Artwork is decorative; bidding controls are real visible Buttons outside
 /// this bitmap, never invisible touch zones positioned over painted icons.
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
   }
   .frame(width: 256, height: 174)
   .accessibilityElement(children: .combine)
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
  VStack(alignment: .leading, spacing: 12) {
   if let auction = model.game.auction {
    Text("公开拍卖 · \(model.game.board[auction.tile].name)")
     .font(.system(size: 18, weight: .bold))
    Text("当前最高价 ¥\(auction.currentBid) · 你可以出价或直接弃权。")
     .font(.system(size: 14, weight: .medium))
    HStack(spacing: 8) {
     Button { adjustAuctionBid(by: -1) } label: {
      Image(systemName: "minus.circle.fill")
       .font(.system(size: 26))
       .frame(width: 48, height: 48)
       .contentShape(Rectangle())
     }
     .buttonStyle(.plain)
     .accessibilityLabel("减少出价")
     .disabled((Int(bidderCash) ?? 0) <= auction.currentBid + 1)
     numericEntry("拟出价", value: bidderCash, target: .bid)
     Button { adjustAuctionBid(by: 1) } label: {
      Image(systemName: "plus.circle.fill")
       .font(.system(size: 26))
       .frame(width: 48, height: 48)
       .contentShape(Rectangle())
     }
     .buttonStyle(.plain)
     .accessibilityLabel("增加出价")
     .disabled((Int(bidderCash) ?? 0) >= model.game.players[model.actor].cash)
    }
    HStack(spacing: 8) {
     action("确认出价", symbol: "checkmark.circle") {
      model.perform(.bid, amount: Int(bidderCash) ?? 0)
     }
     .disabled((Int(bidderCash) ?? 0) <= auction.currentBid ||
               (Int(bidderCash) ?? 0) > model.game.players[model.actor].cash)
     action("放弃竞价", symbol: "xmark.circle", secondary: true) {
      model.perform(.bid, amount: 0)
     }
    }
    astraAuctionHero
    if let notice = VeilopolyCivicText.auction(model.game) {
     VeilopolyCivicDocumentPanel(document: notice)
    }
   }
  }
 }
 @ViewBuilder private var managePanel: some View {
  switch managementSection {
  case .property: propertyPanel
  case .bank: bankPanel
  case .market: stockMarketPanel
  case .trade: tradeProposalPanel
  }
 }

 private var propertyPanel: some View {
  VStack(alignment: .leading,spacing: 12) {
   Text("地产与建设").font(.headline)
   Menu {
    ForEach(model.game.board.filter { $0.owner == model.actor }, id: \.i) { t in
     Button("#\(t.i) \(t.name)") { model.selectedTile = t.i }
    }
   } label: {
    Label("地块 #\(model.selectedTile) · \(model.game.board[model.selectedTile].name)",systemImage:"square.grid.3x3")
     .frame(maxWidth:.infinity,alignment:.leading)
   }
   if let deed = VeilopolyCivicText.deed(model.game, tileIndex: model.selectedTile) {
    VeilopolyCivicDocumentPanel(document: deed)
   }
   HStack {
    propertyAction("建造", symbol: "hammer", kind: .buildHouse)
    propertyAction("卖房", symbol: "minus.square", kind: .sellHouse)
   }
   HStack {
    propertyAction("抵押", symbol: "lock", kind: .mortgage)
    propertyAction("赎回", symbol: "lock.open", kind: .redeem)
   }
   Text("同色地产需集齐并均衡建造；银行剩余房屋 \(model.game.bank.houses) / 酒店 \(model.game.bank.hotels)。")
    .font(.caption2).foregroundStyle(.secondary)
   if model.game.board.allSatisfy({ $0.owner != model.actor }) {
    Text("尚未持有地产。掷骰落在无主地块后，可购买或进入拍卖。")
     .font(.caption).foregroundStyle(.secondary)
   }
  }
 }

 private func propertyAction(_ title: String, symbol: String, kind: MoveKind) -> some View {
  let move = Move(kind, player: model.actor, seq: model.game.nextSeq, tile: model.selectedTile)
  let reason = VeilopolyGamePresentation.rejection(model.game, move: move)
  return VStack(alignment: .leading, spacing: 3) {
   action(title, symbol: symbol, secondary: kind == .sellHouse || kind == .redeem) {
    model.perform(kind, tile: model.selectedTile)
   }
   .disabled(reason != nil)
   if let reason { Text(reason).font(.caption2).foregroundStyle(.secondary) }
  }
  .frame(maxWidth: .infinity, alignment: .topLeading)
 }

 private var tradeProposalPanel: some View {
  let proposal = Move(.proposeTrade, player: model.actor, seq: model.game.nextSeq, to: tradeTarget,
   offer: TradeTransfer(cash: Int(offerCash) ?? -1, tiles: chosenOffer.sorted()),
   request: TradeTransfer(cash: Int(requestCash) ?? -1, tiles: chosenRequest.sorted()))
  let rejection = VeilopolyGamePresentation.rejection(model.game, move: proposal)
  return VStack(alignment: .leading, spacing: 12) {
   Text("交易提案").font(.subheadline.weight(.semibold))
   Picker("交易对象", selection: $tradeTarget) {
    ForEach(model.game.players.filter { $0.id != model.actor && !$0.bankrupt }, id:\.id) { p in
     Text(p.name).tag(p.id)
    }
   }.pickerStyle(.menu)
   HStack {
    numericEntry("我方现金", value: offerCash, target: .offerCash)
    numericEntry("对方现金", value: requestCash, target: .requestCash)
   }
   HStack(alignment:.top) {
    VStack(alignment: .leading) {
     Text("我方地产").font(.caption)
     ForEach(model.game.board.filter { $0.owner == model.actor }, id:\.i) { tile in
      Toggle(tile.name, isOn: Binding(get:{ chosenOffer.contains(tile.i) },
       set:{ if $0 { chosenOffer.insert(tile.i) } else { chosenOffer.remove(tile.i) } }))
       .font(.caption)
     }
    }
    VStack(alignment:.leading) {
     Text("对方地产").font(.caption)
     ForEach(model.game.board.filter { $0.owner == tradeTarget }, id:\.i) { tile in
      Toggle(tile.name, isOn: Binding(get:{ chosenRequest.contains(tile.i) },
       set:{ if $0 { chosenRequest.insert(tile.i) } else { chosenRequest.remove(tile.i) } }))
       .font(.caption)
     }
    }
   }
   action("发起交易",symbol:"arrow.left.arrow.right") {
    model.perform(.proposeTrade,to:tradeTarget,
     offer: proposal.offer, request: proposal.request)
   }
   .disabled(rejection != nil)
   if let rejection { Text(rejection).font(.caption2).foregroundStyle(.secondary) }
  }
 }
 // Pure Swift bank moves are routed through the same authoritative GameState reducer.
 // Kimi owns the final animated skin; this is the functional accessibility fallback.
 private var bankPanel: some View {
  let deposit = Move(.bankDeposit, player: model.actor, seq: model.game.nextSeq,
                     amount: Int(bankAmount), financeProduct: .demandDeposit)
  let borrow = Move(.bankBorrow, player: model.actor, seq: model.game.nextSeq,
                    amount: Int(bankAmount), financePeriods: Int(bankPeriods))
  let depositReason = VeilopolyGamePresentation.rejection(model.game, move: deposit)
  let borrowReason = VeilopolyGamePresentation.rejection(model.game, move: borrow)
  return VStack(alignment: .leading, spacing: 8) {
   Divider()
   Text("银行与金融").font(.subheadline.weight(.semibold))
   astraBankHero
   if let receipt = VeilopolyCivicText.banking(model.game, player: model.actor) {
    VeilopolyCivicDocumentPanel(document: receipt)
   }
   if let digest = VeilopolyBankAutomation.digest(model.game, player: model.actor) {
    VStack(alignment: .leading, spacing: 5) {
     Label("自动账期巡检 · 第\(digest.period)期", systemImage: "clock.arrow.circlepath")
      .font(.caption.weight(.semibold))
      .foregroundColor(Color(red: 0.83, green: 0.67, blue: 0.43))
     Text(digest.memorandum)
      .font(.caption2).fixedSize(horizontal: false, vertical: true)
     ForEach(digest.notices.prefix(5)) { item in
      Text(item.text).font(.caption2)
       .foregroundColor(item.urgent ? .orange : .secondary)
       .fixedSize(horizontal: false, vertical: true)
     }
     if digest.notices.count > 5 {
      Text("还有 \(digest.notices.count - 5) 项到期信息，请查看完整账本。")
       .font(.caption2).foregroundStyle(.secondary)
     }
    }
    .padding(9)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(red: 0.12,green: 0.27,blue: 0.28),
                in: RoundedRectangle(cornerRadius: 10))
    .overlay {
     RoundedRectangle(cornerRadius: 10)
      .strokeBorder(Color(red: 0.73,green: 0.56,blue: 0.32),lineWidth: 1)
      .allowsHitTesting(false)
    }
   }
   HStack(spacing: 8) {
    numericEntry("金额", value: bankAmount, target: .bankAmount)
    numericEntry("期数", value: bankPeriods, target: .bankPeriods)
   }
   HStack(spacing: 8) {
    action("存入活期", symbol: "building.columns") {
     model.perform(.bankDeposit, amount: Int(bankAmount), financeProduct: .demandDeposit)
    }
    .disabled(depositReason != nil)
    action("申请贷款", symbol: "creditcard") {
     model.perform(.bankBorrow, amount: Int(bankAmount), financePeriods: Int(bankPeriods))
    }
    .disabled(borrowReason != nil)
   }
   if let depositReason { Text("存款：" + depositReason).font(.caption2).foregroundStyle(.secondary) }
   if let borrowReason { Text("贷款：" + borrowReason).font(.caption2).foregroundStyle(.secondary) }
   if let ledger = model.game.banking, ledger.accounts.indices.contains(model.actor) {
    let account = ledger.accounts[model.actor]
    ForEach(account.savings, id: \.id) { deposit in
     action("取回存款 ¥\(deposit.principal)", symbol: "arrow.down.left") {
      model.perform(.bankWithdraw, financeID: deposit.id)
     }
     .disabled(ledger.completedTurns < deposit.unlockPeriod)
    }
    ForEach(account.loans, id: \.id) { loan in
     action("偿还贷款 ¥\(loan.totalDue)", symbol: "arrow.up.right") {
      model.perform(.bankRepay, financeID: loan.id)
     }
     .disabled(model.game.players[model.actor].cash < loan.totalDue)
     Text("还款期：\(loan.duePeriod) · 当前期：\(ledger.completedTurns)")
      .font(.caption2).foregroundStyle(loan.duePeriod <= ledger.completedTurns ? Color.orange : Color.secondary)
    }
    ForEach(account.positions, id: \.id) { item in
     action("结算投资 #\(item.id)", symbol: "chart.line.uptrend.xyaxis") {
      model.perform(.bankSettle, financeID: item.id)
     }
     .disabled(ledger.completedTurns < item.duePeriod)
    }
    Text("金融期数：\(ledger.completedTurns)")
     .font(.caption2).foregroundStyle(.secondary)
   }
   Text("存款、贷款与股市共用当前现金。贷款到期前请预留还款资金。")
    .font(.caption2).foregroundStyle(.secondary)
  }
 }

 private var stockMarketPanel: some View {
  let ledger = IntegratedBanking.ledger(model.game)
  let market = ledger.market ?? StockMarketEngine.initial(seed: model.game.seed)
  return VeilopolyStockMarketPanel(
   market: market, player: model.actor,
   cash: model.game.players[model.actor].cash,
   selectedSymbol: $stockSymbol, shareText: $stockShares,
   executions: model.stockExecutions.filter { $0.player == model.actor },
   orderError: model.stockOrderError,
   buyRestriction: IntegratedBanking.hasOverdueLoan(ledger, player: model.actor)
     ? VeilopolyGamePresentation.message(.financeOverdue) : nil,
   onEditShareCount: { amountTarget = .stockShares },
    onBuy: { symbol, shares in
    model.perform(.stockBuy, stockSymbol: symbol, stockShares: shares)
   },
   onSell: { symbol, shares in
    model.perform(.stockSell, stockSymbol: symbol, stockShares: shares)
   })
 }
 private var tradeResponsePanel: some View {
  VStack(spacing: 12) {
   Text("交易确认").font(.headline)
   if let trade = model.game.trade {
    astraTradeHero(trade)
    if let contract = VeilopolyCivicText.trade(model.game) {
     VeilopolyCivicDocumentPanel(document: contract)
    }

   }
   HStack {
    action("接受",symbol:"checkmark") { model.perform(.acceptTrade) }
    action("拒绝",symbol:"xmark",secondary:true) { model.perform(.rejectTrade) }
   }
   if let trade = model.game.trade {
    let counter = VeilopolyGamePresentation.counterOffer(trade,
     offeredCash: Int(offerCash) ?? -1, requestedCash: Int(requestCash) ?? -1,
     sequence: model.game.nextSeq)
    HStack {
     numericEntry("我方出资", value: offerCash, target: .offerCash)
     numericEntry("对方出资", value: requestCash, target: .requestCash)
    }
    Text("还价将保留当前地产与出狱卡条件，仅修改现金。")
     .font(.caption2).foregroundStyle(.secondary)
    action("提交还价", symbol: "arrow.triangle.2.circlepath") {
     model.perform(.counterTrade, offer: counter.offer, request: counter.request)
    }
    .disabled(VeilopolyGamePresentation.rejection(model.game, move: counter) != nil)
   }
  }
  .onAppear { loadCounterCash() }
  .onChange(of: model.game.trade) { _ in loadCounterCash() }
 }
 private func loadCounterCash() {
  guard let trade = model.game.trade else { return }
  offerCash = String(trade.request.cash)
  requestCash = String(trade.offer.cash)
 }
 private var settlementPanel: some View {
  VStack(spacing: 12) {
   astraSettlementHero
   if let report = VeilopolyCivicText.settlement(model.game) {
    VeilopolyCivicDocumentPanel(document: report)
   }
   ForEach(model.game.players.sorted(by:{ a,b in netWorth(a) > netWorth(b) }),id:\.id) { p in
    HStack {
     Text(p.name); Spacer()
     Text("账面净资产 ¥\(netWorth(p))")
    }.font(.subheadline)
   }
   action("再来一局",symbol:"arrow.clockwise") {
    model.reset(seed: VeilopolyNewGameSeed.fresh(excluding: model.game.seed))
   }
   Text("净资产按地产账面价值、存款及投资本金、股票市值减应还贷款计算。")
    .font(.caption2).foregroundStyle(.secondary)
  }
 }
 private func netWorth(_ p: Player) -> Int {
  VeilopolyAssetSummary(game: model.game, player: p.id).netWorth
 }
}
#else
// SwiftUI + SpriteKit require the iOS/macOS Apple SDK; Engine/AI/Net remain portable.
import VeilopolyEngine
#endif
