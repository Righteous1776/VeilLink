import Foundation

public enum Phase: String, Codable, CaseIterable { case roll, moveAnim, tileResolve, auction, manage, trade, debt, finished }
public enum TileKind: String, Codable { case go, street, railroad, utility, chance, chest, tax, jail, freeParking, goToJail }
public enum ColorGroup: String, Codable, CaseIterable { case brown, lightBlue, pink, orange, red, yellow, green, darkBlue }
public enum PlayerKind: String, Codable { case human, ai }
public enum AILevel: String, Codable { case conservative, balanced, aggressive }
public enum DeckKind: String, Codable { case chance, chest }
public enum TokenStyle: String, Codable { case pawn, car, ship, plane }

public struct Tile: Codable, Equatable {
 public var i: Int
 public var kind: TileKind
 public var name: String
 public var color: ColorGroup?
 public var price: Int
 public var rent: [Int]
 public var houseCost: Int
 public var owner: Int?
 public var mortgaged: Bool
 public var houses: Int
 public var hotel: Bool
 public init(i: Int, kind: TileKind, name: String, color: ColorGroup? = nil,
             price: Int = 0, rent: [Int] = [], houseCost: Int = 0,
             owner: Int? = nil, mortgaged: Bool = false, houses: Int = 0, hotel: Bool = false) {
  self.i = i; self.kind = kind; self.name = name; self.color = color
  self.price = price; self.rent = rent; self.houseCost = houseCost
  self.owner = owner; self.mortgaged = mortgaged; self.houses = houses; self.hotel = hotel
 }
 public var purchasable: Bool { kind == .street || kind == .railroad || kind == .utility }
 public var improved: Bool { houses > 0 || hotel }
}

public struct Player: Codable, Equatable {
 public var id: Int
 public var name: String
 public var kind: PlayerKind
 public var aiLevel: AILevel
 public var cash: Int
 public var position: Int
 public var jailTurns: Int
 public var chanceJailCards: Int
 public var chestJailCards: Int
 public var bankrupt: Bool
 public var tokenStyle: TokenStyle
 public init(id: Int, name: String, kind: PlayerKind = .ai, aiLevel: AILevel = .balanced) {
  self.id = id; self.name = name; self.kind = kind; self.aiLevel = aiLevel
  self.cash = 1500; self.position = 0; self.jailTurns = 0
  self.chanceJailCards = 0; self.chestJailCards = 0; self.bankrupt = false
  self.tokenStyle = [TokenStyle.pawn, .car, .ship, .plane][id % 4]
 }
}

public struct Bank: Codable, Equatable { public var houses: Int = 32; public var hotels: Int = 12; public init() {} }
public struct DeckState: Codable, Equatable {
 public var order: [Int]; public var cursor: Int
 public init(order: [Int], cursor: Int = 0) { self.order = order; self.cursor = cursor }
}
public struct TurnState: Codable, Equatable {
 public var player: Int = 0
 public var phase: Phase = .roll
 public var doubleCount: Int = 0
 public var rollCount: Int = 0
 public var lastRoll: [Int] = []
 public var pendingSteps: Int = 0
 public var pendingPurchase: Int? = nil
 public var rolledDouble: Bool = false
 public var releasedFromJail: Bool = false
 public init() {}
}
public struct AuctionState: Codable, Equatable {
 public var tile: Int
 public var active: [Int]
 public var currentBid: Int
 public var bidder: Int?
 public var turn: Int
 public init(tile: Int, active: [Int]) {
  self.tile = tile; self.active = active; self.currentBid = 0; self.bidder = nil
  self.turn = active[0]
 }
}
public struct TradeTransfer: Codable, Equatable {
 public var cash: Int
 public var tiles: [Int]
 public var chanceCards: Int
 public var chestCards: Int
 public init(cash: Int = 0, tiles: [Int] = [], chanceCards: Int = 0, chestCards: Int = 0) {
  self.cash = cash; self.tiles = tiles; self.chanceCards = chanceCards; self.chestCards = chestCards
 }
}
public struct TradeState: Codable, Equatable {
 public var from: Int
 public var to: Int
 public var offer: TradeTransfer
 public var request: TradeTransfer
 public init(from: Int, to: Int, offer: TradeTransfer, request: TradeTransfer) {
  self.from = from; self.to = to; self.offer = offer; self.request = request
 }
}
public struct PendingDebt: Codable, Equatable {
 public var player: Int
 public var amount: Int
 public var creditor: Int?
 public init(player: Int, amount: Int, creditor: Int?) { self.player = player; self.amount = amount; self.creditor = creditor }
}

public enum CardEffectKind: String, Codable { case cash, moveTo, moveNearest, moveRelative, goToJail, jailCard, repair }
public enum CashTarget: String, Codable { case bank, allOthers, selfPlayer }
public enum NearestSet: String, Codable { case railroad, utility }
public struct CardEffect: Codable, Equatable {
 public var kind: CardEffectKind
 public var amount: Int?
 public var target: CashTarget?
 public var tile: Int?
 public var collectGo: Bool?
 public var nearest: NearestSet?
 public var multiplier: Int?
 public var delta: Int?
 public var perHouse: Int?
 public var perHotel: Int?
 public init(kind: CardEffectKind, amount: Int? = nil, target: CashTarget? = nil, tile: Int? = nil,
             collectGo: Bool? = nil, nearest: NearestSet? = nil, multiplier: Int? = nil,
             delta: Int? = nil, perHouse: Int? = nil, perHotel: Int? = nil) {
  self.kind = kind; self.amount = amount; self.target = target; self.tile = tile
  self.collectGo = collectGo; self.nearest = nearest; self.multiplier = multiplier
  self.delta = delta; self.perHouse = perHouse; self.perHotel = perHotel
 }
}
public struct CardDefinition: Codable, Equatable {
 public var id: Int; public var deck: DeckKind; public var text: String; public var effects: [CardEffect]
 public init(id: Int, deck: DeckKind, text: String, effects: [CardEffect]) {
  self.id = id; self.deck = deck; self.text = text; self.effects = effects
 }
}
public struct PendingCard: Codable, Equatable { public var id: Int; public var deck: DeckKind }

public enum MoveKind: String, Codable, CaseIterable {
 case rollDice, applyMovement, resolveTile, buyProperty, startAuction, bid
 case buildHouse, sellHouse, mortgage, redeem
 case proposeTrade, counterTrade, acceptTrade, rejectTrade
 case payBail, useJailCard, declareBankruptcy, endTurn
 case bankDeposit, bankWithdraw, bankBorrow, bankRepay, bankInvest, bankSettle
 case stockBuy, stockSell, stockTick
}
public struct Move: Codable, Equatable {
 public var type: MoveKind
 public var player: Int
 public var seq: Int
 public var tile: Int?
 public var amount: Int?
 public var to: Int?
 public var offer: TradeTransfer?
 public var request: TradeTransfer?
 public var deck: DeckKind?
 public var financeProduct: FinancialFeature?
 public var financePeriods: Int?
 public var financeID: Int?
 public var stockSymbol: String?
 public var stockShares: Int?
 public init(_ type: MoveKind, player: Int, seq: Int,
             tile: Int? = nil, amount: Int? = nil, to: Int? = nil,
             offer: TradeTransfer? = nil, request: TradeTransfer? = nil, deck: DeckKind? = nil,
             financeProduct: FinancialFeature? = nil, financePeriods: Int? = nil, financeID: Int? = nil,
             stockSymbol: String? = nil, stockShares: Int? = nil) {
  self.financeProduct = financeProduct; self.financePeriods = financePeriods; self.financeID = financeID
  self.stockSymbol = stockSymbol; self.stockShares = stockShares
  self.type = type; self.player = player; self.seq = seq
  self.tile = tile; self.amount = amount; self.to = to; self.offer = offer; self.request = request; self.deck = deck
 }
}
public enum EffectKind: String, Codable {
 case diceRolled, playerMoved, passedGo, rentPaid, cashChanged, cardDrawn, jailed, released
 case bought, auctionStarted, bid, bidFold, auctionWon, built, soldBuilding, mortgaged, redeemed
 case tradeProposed, traded, tradeRejected, liquidation, bankrupt, turnEnded, extraRoll, gameWon
 case bankDeposited, bankWithdrawn, bankBorrowed, bankRepaid, bankInvestmentOpened, bankInvestmentSettled, bankMatured
 case stockBought, stockSold, stockTicked, stockHalted
}
public struct Effect: Codable, Equatable {
 public var kind: EffectKind
 public var player: Int?
 public var tile: Int?
 public var from: Int?
 public var to: Int?
 public var amount: Int?
 public var steps: Int?
 public var dice: [Int]?
 public var text: String?
 public var deck: DeckKind?
 public var stockSymbol: String?
 public var stockShares: Int?
 public var stockPriceCents: Int?
 public init(_ kind: EffectKind, player: Int? = nil, tile: Int? = nil, from: Int? = nil,
             to: Int? = nil, amount: Int? = nil, steps: Int? = nil, dice: [Int]? = nil,
             text: String? = nil, deck: DeckKind? = nil,
             stockSymbol: String? = nil, stockShares: Int? = nil, stockPriceCents: Int? = nil) {
  self.kind = kind; self.player = player; self.tile = tile; self.from = from; self.to = to
  self.amount = amount; self.steps = steps; self.dice = dice; self.text = text; self.deck = deck
  self.stockSymbol = stockSymbol; self.stockShares = stockShares; self.stockPriceCents = stockPriceCents
 }
}
public struct GameState: Codable, Equatable {
 public var seed: UInt64
 public var rngCounter: UInt64
 public var board: [Tile]
 public var players: [Player]
 public var bank: Bank
 public var chanceDeck: DeckState
 public var chestDeck: DeckState
 public var cards: [CardDefinition]
 public var turn: TurnState
 public var auction: AuctionState?
 public var trade: TradeState?
 public var pendingCard: PendingCard?
 public var pendingDebt: PendingDebt?
 public var moveLog: [Move]
 public var nextSeq: Int
 public var winner: Int?
 /// Optional for backward compatibility: old snapshots decode with nil and no bank history.
 public var banking: IntegratedBankLedger?
 public init(seed: UInt64, board: [Tile], players: [Player], cards: [CardDefinition]) {
  self.seed = seed; self.rngCounter = 0; self.board = board; self.players = players
  self.bank = Bank(); self.chanceDeck = DeckState(order: cards.filter { $0.deck == .chance }.map(\.id))
  self.chestDeck = DeckState(order: cards.filter { $0.deck == .chest }.map(\.id))
  self.cards = cards; self.turn = TurnState()
  self.auction = nil; self.trade = nil; self.pendingCard = nil; self.pendingDebt = nil
  self.moveLog = []; self.nextSeq = 0; self.winner = nil; self.banking = nil
 }
}
public struct GameContext: Equatable {
 public var currentPlayer: Int
 public var phase: Phase
 public var allowedMoves: [MoveKind]
 public var lastRoll: [Int]
 public init(currentPlayer: Int, phase: Phase, allowedMoves: [MoveKind], lastRoll: [Int]) {
  self.currentPlayer = currentPlayer; self.phase = phase; self.allowedMoves = allowedMoves; self.lastRoll = lastRoll
 }
}
public enum GameError: String, Error, Codable, Equatable {
 case notYourTurn = "NotYourTurn", wrongPhase = "WrongPhase", noCash = "NoCash"
 case setNotComplete = "SetNotComplete", buildUneven = "BuildUneven", alreadyMortgaged = "AlreadyMortgaged"
 case tradeMismatch = "TradeMismatch", invalidTile = "InvalidTile", notOwner = "NotOwner"
 case alreadyOwned = "AlreadyOwned", insufficientBankSupply = "InsufficientBankSupply"
 case invalidPayload = "InvalidPayload", invalidBid = "InvalidBid", invalidSequence = "InvalidSequence"
 case inJail = "InJail", noJailCard = "NoJailCard", noDebt = "NoDebt", alreadyBankrupt = "AlreadyBankrupt"
 case gameFinished = "GameFinished", invalidContext = "InvalidContext", invalidState = "InvalidState"
 case financeTermsPending = "FinanceTermsPending", financePositionLocked = "FinancePositionLocked"
 case financeOverdue = "FinanceOverdue"
 case stockNotFound = "StockNotFound", insufficientShares = "InsufficientShares"
 case stockTradingHalted = "StockTradingHalted"
 case bankLiquidity = "BankLiquidity"
}

public enum StateDigest {
 /// JSON sortedKeys + FNV-1a 64, independent of process-dependent Swift Hasher.
 public static func hash(_ state: GameState) -> String {
  let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
  guard let data = try? encoder.encode(state) else { return "ENCODING_ERROR" }
  var hash: UInt64 = 14_695_981_039_346_656_037
  for byte in data { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
  let result = String(hash, radix: 16)
  return String(repeating: "0", count: max(0, 16 - result.count)) + result
 }
}
