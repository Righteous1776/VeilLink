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
 private var tilePriceLabels: [Int: SKLabelNode] = [:]
 private var tileCaptions: [Int: SKLabelNode] = [:]
 private let activeTileMarker = SKShapeNode(rectOf: CGSize(width: 84, height: 76), cornerRadius: 8)
 private let inspectionMarker = SKShapeNode(rectOf: CGSize(width: 80, height: 72), cornerRadius: 8)
 var onBoardTap: ((Int?) -> Void)?
 var reduceMotion = false
 private var pieces: [Int: SKSpriteNode] = [:]
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
 private func buildBoard() {
  // Promote only when the COMPLETE dark K2 asset set is present in Bundle.module.
  // The older procedural board remains available on a resource lookup failure.
  kimiSkin = KimiK2BoardSkin.install(in: self, load: { name in image(name) })
  if kimiSkin == nil {
   let base = SKShapeNode(rect: CGRect(x: 43, y: 45, width: 934, height: 850), cornerRadius: 15)
   base.fillColor = SKColor(red: 0.11, green: 0.18, blue: 0.22, alpha: 1)
   base.strokeColor = SKColor(red: 0.26, green: 0.45, blue: 0.48, alpha: 1)
   base.lineWidth = 4; base.zPosition = 1; addChild(base)
   let center = SKLabelNode(text: "VEILOPOLY")
   center.fontName = "AvenirNext-Heavy"; center.fontSize = 78
   center.fontColor = SKColor(red: 0.66, green: 0.85, blue: 0.87, alpha: 0.22)
   center.position = CGPoint(x: 510, y: 465); center.zPosition = 2; addChild(center)
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
   caption.position = kimiSkin == nil ? CGPoint(x: spot.x, y: spot.y - 15)
                                      : CGPoint(x: 0, y: 0)
   caption.zPosition = kimiSkin == nil ? 7 : 2.5
   if let art = kimiSkin?.tiles[i] { art.addChild(caption) }
   else { addChild(caption) }
   tileCaptions[i] = caption

   if let art = kimiSkin?.tiles[i] {
    let price = SKLabelNode(text: "")
    price.fontName = "AvenirNext-DemiBold"
    price.fontSize = 10
    price.fontColor = SKColor(red: 0.16, green: 0.27, blue: 0.29, alpha: 1)
    price.position = CGPoint(x: 0, y: -tileSize.height / 2 + 25)
    price.zPosition = 2.5
    art.addChild(price)
    tilePriceLabels[i] = price
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
  let icons = ["pawnBlue","carRed","shipGreen","planeYellow"]
  for i in 0..<4 {
   // Kimi K2 normalized token skins are optional; keep the verified Kenney fallback.
   let preferred = KimiVisualAssetNames.tokenCandidate(for: i).flatMap { image($0) }
   let token = SKSpriteNode(texture: preferred ?? image(icons[i]))
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
   improvements[tile.i]?.text = tile.hotel ? "▣" : (tile.houses > 0 ? "⌂×\(tile.houses)" : "")
   let labelLimit = kimiSkin == nil ? 5 : 4
   let caption = tile.name.count > labelLimit ? String(tile.name.prefix(labelLimit)) + "…" : tile.name
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
   }
  }
  for p in state.players {
   pieces[p.id]?.isHidden = p.bankrupt
   // Position is assigned once from the tile + stable player offset.
   // Do not accumulate x-offsets on repeated snapshots or move animations.
   pieces[p.id]?.zPosition = 30 + CGFloat(p.id)
  }
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
  // contains(_:) expects coordinates local to each tile node, not the scene.
  let hit = tiles.first(where: { element in
   element.value.contains(element.value.convert(local, from: self))
  })?.key
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
    if let last = path.last { pieces[player]?.position = tokenPoint(last, player: player) }
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
   let moves = path.map { tile -> SKAction in
    let time: TimeInterval = 0.15
    let position = tokenPoint(tile, player: id)
    return SKAction.group([SKAction.move(to: position, duration: time),
                           SKAction.sequence([SKAction.moveBy(x: 0,y: 14,duration: time/2),
                                              SKAction.moveBy(x: 0,y: -14,duration: time/2)])])
   }
   finishImmediately = { [weak self] in
    if let last = path.last { token.position = self?.tokenPoint(last, player: id) ?? token.position }
   }
   sound("step")
   // Repeat the audible step cue for each intermediate board square.
   let withCues = moves.map { SKAction.sequence([SKAction.run { [weak self] in self?.sound("step") }, $0]) }
   focus.run(SKAction.scale(to: 0.83, duration: 0.2), withKey: "focus")
   activeCommandNode = token
   token.run(SKAction.sequence(withCues + [SKAction.run { [weak self] in
    self?.focus.run(SKAction.scale(to: 1, duration: 0.3))
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
  case .cardShow(_, _):
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
  dice.forEach { $0.removeAllActions() }
  tiles.values.forEach { $0.removeAction(forKey: "command") }
  finishImmediately?(); finishImmediately = nil
  focus.removeAction(forKey: "focus"); focus.setScale(1)
  currentCompletion = nil; activeCommandNode = nil; completion()
 }
}
#endif
