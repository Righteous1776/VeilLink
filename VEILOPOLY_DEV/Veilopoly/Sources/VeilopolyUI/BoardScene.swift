#if os(iOS) && canImport(SwiftUI) && canImport(SpriteKit)
import SwiftUI
import SpriteKit
import AVFoundation
import UIKit
import VeilopolyEngine

@MainActor
final class GameBoardScene: SKScene {
 private var tiles: [Int: SKShapeNode] = [:]
 private var kimiSkin: KimiK2BoardSkin?
 private var proceduralBoardBase: SKShapeNode?
 private var proceduralBoardTitle: SKLabelNode?
 private var proceduralIndices: [SKLabelNode] = []
 private var tilePriceLabels: [Int: SKLabelNode] = [:]
 private var tileCaptions: [Int: SKLabelNode] = [:]
 private let activeTileMarker = SKShapeNode(rectOf: CGSize(width: 84, height: 76), cornerRadius: 8)
 private let inspectionMarker = SKShapeNode(rectOf: CGSize(width: 80, height: 72), cornerRadius: 8)
 var onBoardTap: ((Int?) -> Void)?
 var reduceMotion = false
 var stepDuration: TimeInterval = 0.36
 private var pieces: [Int: SKSpriteNode] = [:]
 private var tokenShadows: [Int: SKSpriteNode] = [:]
 private var tokenShadowFrames: [SKTexture] = []
 private var victoryBadge: SKSpriteNode?
 private var dayFelt = false
 private var improvements: [Int: SKLabelNode] = [:]
 private var mortgageMarks: [Int: SKShapeNode] = [:]
 private let focus = SKCameraNode()
 private var dice: [SKSpriteNode] = []
 private var sounds: [String: AVAudioPlayer] = [:]
 private var textureCache: [String: SKTexture] = [:]
 private var currentCompletion: (() -> Void)?
 private var acknowledgements = RenderCommandAckGate()
 private weak var activeCommandNode: SKNode?
 private var finishImmediately: (() -> Void)?
 private var audioMap: [String: String] = [
  "roll":"diceThrow", "step":"moveClick", "purchase":"purchase", "build":"build",
  "mortgage":"mortgage", "jail":"jail", "bankrupt":"bankrupt", "card":"drawCard", "cash":"cash", "turn":"turn",
  "diceShuffle":"diceShuffle", "buildClick":"buildClick"
 ]
 override init(size: CGSize) {
  super.init(size: size)
  scaleMode = .aspectFit
  backgroundColor = SKColor(red: 0.065, green: 0.09, blue: 0.13, alpha: 1)
  buildBoard()
  if kimiSkin != nil {
   // The single ivory board is the default, including cold-start and resume.
   dayFelt = IvoryUnifiedVisualSystem.defaultLightTheme
   backgroundColor = SKColor(red: 0.96, green: 0.93, blue: 0.86, alpha: 1)
  } else {
   dayFelt = false
  }
  camera = focus; focus.position = CGPoint(x: 512, y: 470); addChild(focus)
 }
 required init?(coder: NSCoder) { fatalError("Use init(size:)") }

 private func image(_ name: String) -> SKTexture? {
  if let cached = textureCache[name] { return cached }
  guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
        let im = UIImage(contentsOfFile: url.path) else { return nil }
  let texture = SKTexture(image: im)
  textureCache[name] = texture
  return texture
 }
 private func sound(_ key: String) {
  guard let name = audioMap[key], let url = Bundle.module.url(forResource: name, withExtension: "wav") else { return }
  if let existing = sounds[key] { existing.currentTime = 0; existing.play(); return }
  if let player = try? AVAudioPlayer(contentsOf: url) {
   player.volume = key == "step" ? 0.40 : 0.65
   sounds[key] = player; player.prepareToPlay(); player.play()
  }
 }
 private func colorFor(_ c: ColorGroup?) -> SKColor {
  switch c {
  case .brown: return .brown
  case .lightBlue: return SKColor(red: 0.49, green: 0.78, blue: 0.93, alpha: 1)
  case .pink: return SKColor(red: 0.92, green: 0.38, blue: 0.64, alpha: 1)
  case .orange: return .orange
  case .red: return .red
  case .yellow: return .yellow
  case .green: return .green
  case .darkBlue: return SKColor(red: 0.13, green: 0.24, blue: 0.76, alpha: 1)
  case .none: return SKColor(red: 0.80, green: 0.88, blue: 0.92, alpha: 1)
  }
 }
 private func point(_ i: Int) -> CGPoint {
  if kimiSkin != nil, let geometry = KimiK2TileMap.visual(for: i) {
   return CGPoint(x: CGFloat(geometry.centerX), y: CGFloat(geometry.centerY))
  }
  let x: CGFloat; let y: CGFloat
  if i <= 10 { x = CGFloat(10-i); y = 0 }
  else if i <= 20 { x = 0; y = CGFloat(i-10) }
  else if i <= 30 { x = CGFloat(i-20); y = 10 }
  else { x = 10; y = CGFloat(40-i) }
  return CGPoint(x: 85 + x * 85, y: 85 + y * 78) // 12-15 degree faux perspective
 }
 private func tokenPoint(_ tile: Int, player: Int) -> CGPoint {
  let center = point(tile)
  guard let offset = VeilopolyTokenFormation.offset(player: player) else { return center }
  return CGPoint(x: center.x + CGFloat(offset.x), y: center.y + CGFloat(offset.y))
 }
 private func shadowPoint(_ tile: Int, player: Int) -> CGPoint {
  let landing = tokenPoint(tile, player: player)
  return CGPoint(x: landing.x, y: landing.y - 18)
 }
 /// Kimi board theme is a purely visual preference, never a reducer command.
 func setDayFelt(_ enabled: Bool) {
  dayFelt = enabled
  kimiSkin?.setLight(enabled)
  backgroundColor = enabled ? SKColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1)
                            : SKColor(red: 0.065, green: 0.09, blue: 0.13, alpha: 1)
  // Keep the procedural board coherent with the surrounding day/night canvas.
  guard kimiSkin == nil else { return }
  proceduralBoardBase?.fillColor = enabled
   ? SKColor(red: 0.88, green: 0.84, blue: 0.74, alpha: 1)
   : SKColor(red: 0.11, green: 0.18, blue: 0.22, alpha: 1)
  proceduralBoardBase?.strokeColor = enabled
   ? SKColor(red: 0.48, green: 0.36, blue: 0.19, alpha: 1)
   : SKColor(red: 0.26, green: 0.45, blue: 0.48, alpha: 1)
  proceduralBoardTitle?.fontColor = enabled
   ? SKColor(red: 0.17, green: 0.33, blue: 0.34, alpha: 0.27)
   : SKColor(red: 0.66, green: 0.85, blue: 0.87, alpha: 0.22)
  for node in tiles.values {
   node.fillColor = enabled ? SKColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1)
                            : SKColor(red: 0.16, green: 0.23, blue: 0.28, alpha: 1)
   node.strokeColor = enabled ? SKColor(red: 0.63, green: 0.51, blue: 0.34, alpha: 1)
                              : SKColor(red: 0.37, green: 0.52, blue: 0.55, alpha: 0.6)
  }
  for node in tileCaptions.values {
   node.fontColor = enabled ? SKColor(red: 0.14, green: 0.28, blue: 0.29, alpha: 1)
                            : SKColor(white: 0.96, alpha: 0.93)
  }
  for node in proceduralIndices {
   node.fontColor = enabled ? SKColor(red: 0.21, green: 0.32, blue: 0.32, alpha: 1)
                            : SKColor(white: 0.85, alpha: 1)
  }
 }
 var supportsDayFelt: Bool { true }
 var isDayFelt: Bool { dayFelt }
 private func buildBoard() {
  // Promote only when the COMPLETE dark K2 asset set is present in Bundle.module.
  // The older procedural board remains available on a resource lookup failure.
  kimiSkin = KimiK2BoardSkin.install(in: self, load: { name in image(name) })
  if kimiSkin == nil {
   let base = SKShapeNode(rect: CGRect(x: 43, y: 45, width: 934, height: 850), cornerRadius: 15)
   base.fillColor = SKColor(red: 0.11, green: 0.18, blue: 0.22, alpha: 1)
   base.strokeColor = SKColor(red: 0.26, green: 0.45, blue: 0.48, alpha: 1)
   base.lineWidth = 4; base.zPosition = 1; addChild(base)
   proceduralBoardBase = base
   let center = SKLabelNode(text: "VEILOPOLY")
   center.fontName = "AvenirNext-Heavy"; center.fontSize = 78
   center.fontColor = SKColor(red: 0.66, green: 0.85, blue: 0.87, alpha: 0.22)
   center.position = CGPoint(x: 510, y: 465); center.zPosition = 2; addChild(center)
   proceduralBoardTitle = center
  }
  for i in 0..<40 {
   let spot = point(i)
   let spec = kimiSkin == nil ? nil : KimiK2TileMap.visual(for: i)
   let tileSize = CGSize(width: CGFloat(spec?.displayWidth ?? 81),
                         height: CGFloat(spec?.displayHeight ?? 73))
   // Invisible K2 hit regions retain the established action and tap pipeline.
   // The fallback keeps the original visible SKShapeNode tiles.
   let tile = SKShapeNode(rectOf: tileSize, cornerRadius: kimiSkin == nil ? 7 : 3)
   tile.position = spot
   tile.zRotation = CGFloat(spec?.rotationRadians ?? 0)
   tile.zPosition = kimiSkin == nil ? 4 : 4.5
   if kimiSkin == nil {
    tile.fillColor = SKColor(red: 0.16, green: 0.23, blue: 0.28, alpha: 1)
    tile.strokeColor = SKColor(red: 0.37, green: 0.52, blue: 0.55, alpha: 0.6)
    tile.lineWidth = 1.5
   } else {
    tile.fillColor = .clear
    tile.strokeColor = .clear
    tile.lineWidth = 0
   }
   addChild(tile)
   tiles[i] = tile

   if kimiSkin == nil {
    let index = SKLabelNode(text: String(i))
    index.fontName = "AvenirNext-DemiBold"; index.fontSize = 18
    index.fontColor = SKColor(white: 0.85, alpha: 1)
    index.verticalAlignmentMode = .center
    index.position = CGPoint(x: spot.x, y: spot.y + 13)
    index.zPosition = 6
    addChild(index)
    proceduralIndices.append(index)
   }

   // No Kimi preview text is embedded in the live game: authoritative Engine
   // names and property prices are painted into native SpriteKit labels.
   let caption = SKLabelNode(text: "")
   caption.fontName = "AvenirNext-DemiBold"
   caption.fontSize = kimiSkin == nil ? 11 : 11
   caption.fontColor = kimiSkin == nil
     ? SKColor(white: 0.96, alpha: 0.93)
     : SKColor(red: 0.10, green: 0.22, blue: 0.23, alpha: 1)
   caption.verticalAlignmentMode = .center
   caption.horizontalAlignmentMode = .center
   caption.name = "LiveTileName"
   caption.position = kimiSkin == nil ? CGPoint(x: spot.x, y: spot.y - 15)
                                      : CGPoint(x: 0, y: 4)
   caption.zPosition = kimiSkin == nil ? 7 : 2.5
   if let art = kimiSkin?.tiles[i] { art.addChild(caption) }
   else { addChild(caption) }
   tileCaptions[i] = caption

   if let art = kimiSkin?.tiles[i] {
    if kimiSkin?.usesFineTiles != true {
    // K2's preview tiles have sample labels/prices baked into their atlas.
    // Cover ONLY the exact text regions declared in SPRITE_MAP.json;
    // keep frame, color-band, ownership and special icons visible.
    let inkPaper = SKColor(red: 0.94, green: 0.92, blue: 0.86, alpha: 0.985)
    let localTextWidth = max(20, tileSize.width - 10)
    let namePlate = SKShapeNode(rect: CGRect(x: -localTextWidth / 2,
                                             y: -12, width: localTextWidth, height: 32),
                                cornerRadius: 2)
    namePlate.name = "LiveNameMask"
    namePlate.fillColor = inkPaper
    namePlate.strokeColor = .clear
    namePlate.zPosition = 2.2
    art.addChild(namePlate)
    let pricePlate = SKShapeNode(rect: CGRect(x: -localTextWidth / 2,
                                              y: -33, width: localTextWidth, height: 14),
                                 cornerRadius: 2)
    pricePlate.name = "LivePriceMask"
    pricePlate.fillColor = inkPaper
    pricePlate.strokeColor = .clear
    pricePlate.zPosition = 2.2
    art.addChild(pricePlate)
    }
    let price = SKLabelNode(text: "")
    price.name = "LiveTilePrice"
    price.fontName = "AvenirNext-DemiBold"
    price.fontSize = 10
    price.verticalAlignmentMode = .center
    price.fontColor = SKColor(red: 0.16, green: 0.27, blue: 0.29, alpha: 1)
    price.position = CGPoint(x: 0, y: -26)
    price.zPosition = 2.5
    art.addChild(price)
    tilePriceLabels[i] = price
    if kimiSkin?.usesFineTiles == true, let spec = KimiK2TileMap.visual(for: i) {
     let layout = AstraTileArtwork.layout(spec)
     let p = layout.local(0, layout.priceY)
     price.position = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
     price.zRotation = -art.zRotation
     caption.zRotation = -art.zRotation
     caption.preferredMaxLayoutWidth = CGFloat(layout.labelWidth)
     caption.numberOfLines = 2
     caption.fontSize = 10
    }
   }

   let buildings = SKLabelNode(text: "")
   buildings.fontName = "AvenirNext-Bold"
   buildings.fontSize = kimiSkin == nil ? 20 : 13
   buildings.fontColor = kimiSkin == nil ? .systemGreen :
      SKColor(red: 0.07, green: 0.43, blue: 0.24, alpha: 1)
   buildings.position = kimiSkin == nil
     ? CGPoint(x: spot.x + 3, y: spot.y - 27)
     : CGPoint(x: 0, y: tileSize.height / 2 - 26)
   buildings.zPosition = kimiSkin == nil ? 5 : 2.6
   if let art = kimiSkin?.tiles[i] { art.addChild(buildings) }
   else { addChild(buildings) }
   improvements[i] = buildings

   if kimiSkin == nil {
    let redSlash = SKShapeNode()
    let slash = CGMutablePath()
    slash.move(to: CGPoint(x: -31, y: -27))
    slash.addLine(to: CGPoint(x: 31, y: 27))
    redSlash.path = slash
    redSlash.strokeColor = .systemRed
    redSlash.lineWidth = 5
    redSlash.position = spot
    redSlash.zPosition = 8
    redSlash.isHidden = true
    addChild(redSlash)
    mortgageMarks[i] = redSlash
   }
  }
  activeTileMarker.fillColor = .clear
  activeTileMarker.strokeColor = SKColor(red: 0.78, green: 0.98, blue: 0.93, alpha: 0.88)
  activeTileMarker.lineWidth = 3
  activeTileMarker.zPosition = 12
  activeTileMarker.isHidden = true
  addChild(activeTileMarker)
  inspectionMarker.fillColor = .clear
  inspectionMarker.strokeColor = .systemYellow
  inspectionMarker.lineWidth = 3
  inspectionMarker.zPosition = 14
  inspectionMarker.isHidden = true
  addChild(inspectionMarker)
  // L7: feather-like edge vignette, deliberately translucent to preserve legibility.
  let vignette = SKShapeNode(rect: CGRect(x: 4, y: 3, width: 1016, height: 934), cornerRadius: 25)
  vignette.fillColor = .clear
  vignette.strokeColor = SKColor(white: 0.0, alpha: 0.15)
  vignette.lineWidth = 32; vignette.zPosition = 90; addChild(vignette)
  // Four original Kimi shadow frames. A resting pawn uses frame 0;
  // movement loops the atlas temporarily without keeping idle GPU actions.
  if kimiSkin != nil, let atlas = image("kimiFxPawnShadowAtlas") {
   tokenShadowFrames = (0..<4).map { frame in
    let texture = SKTexture(rect: CGRect(x: CGFloat(frame) / 4,
                                         y: 0, width: 0.25, height: 1), in: atlas)
    texture.filteringMode = .linear
    return texture
   }
  }
  for i in 0..<4 {
   if let resting = tokenShadowFrames.first {
    let shadow = SKSpriteNode(texture: resting)
    shadow.size = CGSize(width: 52, height: 25)
    shadow.position = shadowPoint(0, player: i)
    shadow.zPosition = 28 + CGFloat(i)
    shadow.alpha = 0.68
    shadow.name = "KimiK2/token-shadow-\(i)"
    addChild(shadow)
    tokenShadows[i] = shadow
   }
   // Fine material sprites, then original Kimi, then Kenney. All retain the
   // existing formation, movement path, shadow and ACK behavior.
   let preferred = AstraDetailArtwork.tokenCandidates(for: i).lazy.compactMap { self.image($0) }.first
   let token = SKSpriteNode(texture: preferred)
   token.name = "Veilopoly/player-token-\(i)"
   token.size = CGSize(width: VeilopolyTokenFormation.tokenSize,
                       height: VeilopolyTokenFormation.tokenSize)
   token.position = tokenPoint(0, player: i); token.zPosition = 30
   addChild(token); pieces[i] = token
  }
  for d in 0..<2 {
   let token = SKSpriteNode(texture: image("die1"))
   token.size = CGSize(width: 88, height: 88)
   token.position = CGPoint(x: 460 + CGFloat(d) * 110, y: 475)
   token.zPosition = 44; addChild(token); dice.append(token)
  }
 }

 private func configureMarker(_ marker: SKShapeNode, at index: Int) {
  marker.position = point(index)
  if let geometry = kimiSkin == nil ? nil : KimiK2TileMap.visual(for: index) {
   let width = CGFloat(geometry.displayWidth) + 5
   let height = CGFloat(geometry.displayHeight) + 5
   marker.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2,
                                            width: width, height: height),
                        cornerWidth: 7, cornerHeight: 7, transform: nil)
   marker.zRotation = CGFloat(geometry.rotationRadians)
  } else {
   marker.zRotation = 0
  }
 }

 func display(_ state: GameState, snapTokens: Bool = true) {
  kimiSkin?.apply(state)
  for tile in state.board {
   if kimiSkin == nil, let n = tiles[tile.i] {
    n.fillColor = tile.mortgaged ? SKColor(white: 0.23, alpha: 1) :
      (tile.owner == nil ? colorFor(tile.color).withAlphaComponent(tile.color == nil ? 0.13 : 0.42)
       : colorFor(tile.color).withAlphaComponent(0.78))
    n.strokeColor = tile.owner == nil ? SKColor(white: 0.45, alpha: 0.6)
     : (tile.owner.flatMap { [SKColor.systemBlue, .systemRed, .systemGreen, .systemYellow].indices.contains($0)
         ? [SKColor.systemBlue, .systemRed, .systemGreen, .systemYellow][$0] : nil }
        ?? SKColor(white: 0.45, alpha: 0.6))
   }
   mortgageMarks[tile.i]?.isHidden = !tile.mortgaged
   improvements[tile.i]?.text = kimiSkin?.usesBuildingSprites == true ? "" :
     (tile.hotel ? "▣" : (tile.houses > 0 ? "⌂×\(tile.houses)" : ""))
   let fine = kimiSkin?.usesFineTiles == true
   let labelLimit = kimiSkin == nil ? 5 : 4
   let caption = fine ? tile.name : (tile.name.count > labelLimit ? String(tile.name.prefix(labelLimit)) + "…" : tile.name)
   if fine, let spec = KimiK2TileMap.visual(for: tile.i) {
    let layout = AstraTileArtwork.layout(spec)
    let special = tile.kind != .street
    let p = layout.local(0, layout.nameY(special: special))
    tileCaptions[tile.i]?.position = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
    tileCaptions[tile.i]?.numberOfLines = special ? 1 : 2
    tileCaptions[tile.i]?.fontSize = special ? 9 : 10
   }
   if tileCaptions[tile.i]?.text != caption { tileCaptions[tile.i]?.text = caption }
   tilePriceLabels[tile.i]?.text = tile.purchasable ? "¥\(tile.price)" : ""
  }
  if state.players.indices.contains(state.turn.player) {
   configureMarker(activeTileMarker, at: state.players[state.turn.player].position)
   activeTileMarker.isHidden = state.winner != nil
  }
  if snapTokens {
   for p in state.players where !p.bankrupt {
    pieces[p.id]?.position = tokenPoint(p.position, player: p.id)
    tokenShadows[p.id]?.position = shadowPoint(p.position, player: p.id)
   }
  }
  for p in state.players {
   pieces[p.id]?.isHidden = p.bankrupt
   tokenShadows[p.id]?.isHidden = p.bankrupt
   // Position is assigned once from the tile + stable player offset.
   // Do not accumulate x-offsets on repeated snapshots or move animations.
   pieces[p.id]?.zPosition = 30 + CGFloat(p.id)
  }
  updateVictoryBadge(state)
 }

 private func updateVictoryBadge(_ state: GameState) {
  guard let winnerID = state.winner, state.players.indices.contains(winnerID),
        kimiSkin != nil,
        let texture = image(IvoryR1Artwork.preferredVictoryBadgeAlias()) ?? image("kimiFxVictoryBadge") else {
   victoryBadge?.removeFromParent()
   victoryBadge = nil
   return
  }
  // The real winner comes from Engine. The badge is decoration only;
  // Astra's settlement panel remains the accessible source of result data.
  if victoryBadge == nil {
   let badge = SKSpriteNode(texture: texture)
   badge.size = CGSize(width: 116, height: 116)
   badge.position = CGPoint(x: 512, y: 628)
   badge.zPosition = 65
   badge.name = "KimiK2/victoryBadge"
   let title = SKLabelNode(text: "")
   title.name = "winnerName"
   title.fontName = "AvenirNext-DemiBold"
   title.fontSize = 20
   title.fontColor = SKColor(red: 0.95, green: 0.85, blue: 0.66, alpha: 1)
   title.position = CGPoint(x: 0, y: -78)
   title.zPosition = 1
   badge.addChild(title)
   addChild(badge)
   victoryBadge = badge
   if !reduceMotion {
    badge.setScale(0.84)
    badge.run(.scale(to: 1, duration: 0.28), withKey: "winner-pop")
   }
  }
  (victoryBadge?.childNode(withName: "winnerName") as? SKLabelNode)?.text =
    state.players[winnerID].name
 }

 /// Tap-to-inspect: game input remains in the SwiftUI coordinator.
 func highlightTile(_ index: Int) {
  guard tiles[index] != nil else { inspectionMarker.isHidden = true; return }
  configureMarker(inspectionMarker, at: index)
  inspectionMarker.isHidden = false
 }
 override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
  guard let touch = touches.first else { return }
  let local = touch.location(in: self)
  // Use a pure, deterministic geometry picker; scene scale is irrelevant.
  let centers = tiles.map { index, node in
   VeilopolyTileHitTarget(index: index, x: Double(node.position.x),
                          y: Double(node.position.y))
  }
  let hit = VeilopolyTileHitTesting.nearest(
   x: Double(local.x), y: Double(local.y), centers: centers)
  onBoardTap?(hit)
 }
 
 func play(_ command: ViewCommand, finished: @escaping () -> Void) {
  removeAction(forKey: "command")
  let commandID = acknowledgements.begin()
  currentCompletion = finished
  activeCommandNode = nil
  // Never let a delayed SpriteKit completion acknowledge a newer command.
  let ack = { [weak self] in
   guard let self, self.acknowledgements.acknowledge(commandID),
         let completion = self.currentCompletion else { return }
   self.currentCompletion = nil; self.finishImmediately = nil
   self.activeCommandNode = nil
   completion()
  }
  // System Reduce Motion: apply terminal visual state and release the same
  // one-shot acknowledgment. The deterministic engine does not see this flag.
  if reduceMotion {
   switch command {
   case .diceRoll(let values):
    for (index, node) in dice.enumerated() {
     if values.values.indices.contains(index) {
      node.texture = image("die\(max(1, min(6, values.values[index])))")
     }
     node.zRotation = 0
    }
   case .tokenMove(let player, let path):
    if let last = path.last {
     pieces[player]?.position = tokenPoint(last, player: player)
     tokenShadows[player]?.position = shadowPoint(last, player: player)
     tokenShadows[player]?.texture = tokenShadowFrames.first
    }
   case .cardShow: sound("card")
   case .banner: sound("turn")
   case .cashFloat: sound("cash")
   case .tileFx: break
   }
   ack()
   return
  }
  switch command {
  case .diceRoll(let anim):
   sound("diceShuffle")
   sound("roll")
   // Kimi K1 six-frame sheet (SpriteKit bottom-origin), with old dice PNG
   // fallback for missing/invalid art. No RNG or phase work lives here.
   let frames: [SKTexture]
   if let sheet = image("diceSheetWhite") {
    frames = (1...6).compactMap { face in
     guard let uv = VeilopolyDiceAtlasMap.frame(face: face) else { return nil }
     return SKTexture(rect: CGRect(x: CGFloat(uv.x), y: CGFloat(uv.y), width: CGFloat(uv.width), height: CGFloat(uv.height)), in: sheet)
    }
   } else {
    frames = (1...6).compactMap { image("die\($0)") }
   }
   let values = anim.values
   let action = SKAction.customAction(withDuration: 1.2) { [weak self] _, elapsed in
    guard let self else { return }
    for (i,node) in self.dice.enumerated() {
     let face = elapsed < 0.96 ? Int(elapsed * 12 + CGFloat(i)) % max(frames.count,1)
        : max(0, min(5, values[i]-1))
     if !frames.isEmpty { node.texture = frames[face] }
     node.zRotation = elapsed < 0.85 ? CGFloat(elapsed) * 8 : 0
    }
   }
   finishImmediately = { [weak self] in
    guard let self else { return }
    for (i,node) in self.dice.enumerated() {
     let face = max(1,min(6,values[i]))
     node.texture = frames.count == 6 ? frames[face - 1] : self.image("die\(face)")
     node.zRotation = 0
    }
   }
   run(SKAction.sequence([action, SKAction.run(ack)]), withKey: "command")
  case .tokenMove(let id, let path):
   guard let token = pieces[id] else { ack(); return }
   let shadow = tokenShadows[id]
   if let shadow {
    let shadowMoves = path.map { tile in
     SKAction.move(to: shadowPoint(tile, player: id), duration: reduceMotion ? 0.08 : stepDuration)
    }
    shadow.run(.sequence(shadowMoves), withKey: "command")
    if tokenShadowFrames.count == 4 {
     shadow.run(.repeatForever(.animate(with: tokenShadowFrames, timePerFrame: 0.10)),
                withKey: "moving-shadow")
    }
   }
   let moves = path.map { tile -> SKAction in
    let time: TimeInterval = reduceMotion ? 0.08 : stepDuration
    let position = tokenPoint(tile, player: id)
    return SKAction.group([SKAction.move(to: position, duration: time),
                           SKAction.sequence([SKAction.moveBy(x: 0,y: 14,duration: time/2),
                                              SKAction.moveBy(x: 0,y: -14,duration: time/2)])])
   }
   finishImmediately = { [weak self] in
    guard let self else { return }
    if let last = path.last {
     token.position = self.tokenPoint(last, player: id)
     shadow?.position = self.shadowPoint(last, player: id)
    }
    shadow?.removeAction(forKey: "command")
    shadow?.removeAction(forKey: "moving-shadow")
    shadow?.texture = self.tokenShadowFrames.first
   }
   sound("step")
   // Repeat the audible step cue for each intermediate board square.
   let withCues = moves.map { SKAction.sequence([SKAction.run { [weak self] in self?.sound("step") }, $0]) }
    // Keep the camera fixed while tokens traverse all intermediate tiles.
   activeCommandNode = token
   token.run(SKAction.sequence(withCues + [SKAction.run { [weak self] in
    shadow?.removeAction(forKey: "command")
    shadow?.removeAction(forKey: "moving-shadow")
    shadow?.texture = self?.tokenShadowFrames.first
    if let last = path.last, let self {
     shadow?.position = self.shadowPoint(last, player: id)
    }
     // No camera zoom reset: board remains fully visible.
    ack()
   }]), withKey: "command")
  case .tileFx(let i, let kind):
   let node: SKNode?
   if let skinned = kimiSkin?.tiles[i] { node = skinned }
   else { node = tiles[i] }
   let key: String
   let duration: TimeInterval
   switch kind {
   case .purchase: key = "purchase"; duration = 0.5
   case .build: key = "build"; duration = 0.35
   case .mortgage: key = "mortgage"; duration = 0.4
   case .jail: key = "jail"; duration = 0.6
   case .bankrupt: key = "bankrupt"; duration = 1.2
   case .cash: key = "cash"; duration = 0.3
   }
   sound(key)
   if case .build = kind { sound("buildClick") }
   // Kimi's six original pulse frames are layered over the correct live tile;
   // if its atlas is absent, retain the lightweight procedural SpriteKit ring.
   let pulse: SKNode
   if kimiSkin != nil, let atlas = image("kimiFxTilePulseAtlas") {
    let frame: (column: Int, row: Int)
    switch kind {
    case .purchase: frame = (0, 0)
    case .build: frame = (1, 0)
    case .mortgage: frame = (2, 0)
    case .jail: frame = (0, 1)
    case .bankrupt: frame = (1, 1)
    case .cash: frame = (2, 1)
    }
    let subtexture = SKTexture(
     rect: CGRect(x: CGFloat(frame.column) / 3,
                  y: CGFloat(1 - frame.row) / 2,
                  width: 1.0 / 3, height: 1.0 / 2),
     in: atlas)
    let sprite = SKSpriteNode(texture: subtexture)
    sprite.size = CGSize(width: 115, height: 115)
    pulse = sprite
   } else {
    let ring = SKShapeNode(circleOfRadius: 38)
    ring.fillColor = .clear
    ring.strokeColor = kind == .bankrupt ? .systemRed : .systemMint
    ring.lineWidth = 5
    pulse = ring
   }
   pulse.position = point(i)
   pulse.zPosition = 23
   pulse.alpha = 0.85
   pulse.setScale(0.72)
   addChild(pulse)
   pulse.run(SKAction.sequence([
    .group([.scale(to: 1.32, duration: duration), .fadeOut(withDuration: duration)]),
    .removeFromParent()
   ]))
   activeCommandNode = node
   // Keep exactly-once render ACK and fast-forward cleanup as before.
   finishImmediately = { node?.setScale(1); pulse.removeFromParent() }
   if let node {
    node.run(SKAction.sequence([SKAction.scale(to: 1.08, duration: duration/2),
                                SKAction.scale(to: 1, duration: duration/2), SKAction.run(ack)]), withKey: "command")
   } else { pulse.removeFromParent(); ack() }
  case .cashFloat(let player, let amount):
   sound("cash")
   let label = SKLabelNode(text: (amount > 0 ? "+" : "") + "¥\(amount)")
   label.fontName = "AvenirNext-Bold"; label.fontSize = 36
   label.fontColor = amount >= 0 ? .systemGreen : .systemRed
   let origin = pieces[player]?.position ?? CGPoint(x: 510, y: 490)
   label.position = CGPoint(x: min(860, max(160, origin.x)),
                            y: min(790, max(160, origin.y + 56)))
   label.zPosition = 70; addChild(label)
   var chip: SKSpriteNode?
   if kimiSkin != nil, let atlas = image("kimiFxCashChipAtlas") {
    let frames = (0..<4).map { index in
     SKTexture(rect: CGRect(x: CGFloat(index) / 4, y: 0,
                            width: 0.25, height: 1), in: atlas)
    }
    let sparkle = SKSpriteNode(texture: frames[0])
    sparkle.size = CGSize(width: 42, height: 42)
    sparkle.position = CGPoint(x: label.position.x - 76, y: label.position.y)
    sparkle.zPosition = 69
    addChild(sparkle)
    sparkle.run(SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.12)),
                withKey: "coin-rotation")
    sparkle.run(SKAction.group([.moveBy(x: 0, y: 50, duration: 0.7),
                                .fadeOut(withDuration: 0.7)]))
    chip = sparkle
   }
   let finishedChip = chip
   finishImmediately = { label.removeFromParent(); finishedChip?.removeFromParent() }
   activeCommandNode = label
   label.run(SKAction.sequence([SKAction.group([.moveBy(x: 0,y: 50,duration: 0.7), .fadeOut(withDuration: 0.7)]),
                                .run {
                                 label.removeFromParent()
                                 finishedChip?.removeFromParent()
                                 ack()
                                }]), withKey: "command")
  case .cardShow(_, _, _):
   sound("card")
   run(SKAction.sequence([.wait(forDuration: 0.5),.run(ack)]),withKey: "command")
   finishImmediately = {}
  case .banner(let info):
   sound("turn")
   let plate: SKNode
   if kimiSkin != nil, let texture = image("kimiFxTurnBanner") {
    let sprite = SKSpriteNode(texture: texture)
    sprite.size = CGSize(width: 520, height: 76)
    plate = sprite
   } else {
    let shape = SKShapeNode(rectOf: CGSize(width: 510, height: 84), cornerRadius: 20)
    shape.fillColor = SKColor(red: 0.08, green: 0.18, blue: 0.23, alpha: 0.96)
    shape.strokeColor = SKColor(red: 0.50, green: 0.89, blue: 0.80, alpha: 0.88)
    shape.lineWidth = 2
    plate = shape
   }
   plate.position = CGPoint(x: 512, y: 470)
   plate.zPosition = 80; plate.alpha = 0
   let title = SKLabelNode(text: info.text)
   title.fontName = "AvenirNext-DemiBold"; title.fontSize = 31
   title.fontColor = .white; title.verticalAlignmentMode = .center
   title.zPosition = 1
   plate.addChild(title); addChild(plate)
   activeCommandNode = plate
   finishImmediately = { plate.removeFromParent() }
   plate.run(SKAction.sequence([.fadeIn(withDuration: 0.15),
                                .wait(forDuration: 0.80),
                                .fadeOut(withDuration: 0.25),
                                .run {
                                 plate.removeFromParent()
                                 ack()
                                }]), withKey: "command")
  }
 }
 func fastForward() {
  guard let commandID = acknowledgements.pending,
        acknowledgements.acknowledge(commandID),
        let completion = currentCompletion else { return }
  removeAction(forKey: "command")
  activeCommandNode?.removeAction(forKey: "command")
  pieces.values.forEach { $0.removeAction(forKey: "command") }
  tokenShadows.values.forEach {
   $0.removeAction(forKey: "command")
   $0.removeAction(forKey: "moving-shadow")
  }
  dice.forEach { $0.removeAllActions() }
  tiles.values.forEach { $0.removeAction(forKey: "command") }
  finishImmediately?(); finishImmediately = nil
  focus.removeAction(forKey: "focus"); focus.setScale(1)
  currentCompletion = nil; activeCommandNode = nil; completion()
 }
}
#endif
