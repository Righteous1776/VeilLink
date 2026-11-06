#if os(iOS) && canImport(SpriteKit)
import SpriteKit
import VeilopolyEngine

/// Kimi K2 original-pixel 2.5D board visuals. All game rules remain in Engine.
/// An all-or-nothing resource preflight prevents half-skinned scenes.
@MainActor
final class KimiK2BoardSkin {
 let tiles: [Int: SKSpriteNode]
 private let ownerStrips: [Int: SKSpriteNode]
 private let mortgageOverlays: [Int: SKSpriteNode]
 private let improvementShadows: [Int: SKSpriteNode]
 private let ownerTextures: [SKTexture]

 private init(tiles: [Int: SKSpriteNode], owners: [Int: SKSpriteNode],
              mortgages: [Int: SKSpriteNode], shadows: [Int: SKSpriteNode],
              ownerTextures: [SKTexture]) {
  self.tiles=tiles; self.ownerStrips=owners
  self.mortgageOverlays=mortgages; self.improvementShadows=shadows
  self.ownerTextures=ownerTextures
 }

 static func install(in scene: SKScene, load: (String) -> SKTexture?) -> KimiK2BoardSkin? {
  guard KimiK2BoardCatalog.runtimeEnabled, KimiK2TileMap.tiles.count == 40 else { return nil }
  let names = [
   "kimiK2BoardTableDark", "kimiK2BoardEdgeDark", "kimiK2BoardBaseDark",
   "kimiK2BoardFrameDark", "kimiK2BoardCenterEmblem", "kimiK2TilesDark",
   "kimiK2OwnerStripes", "kimiK2TileMortgageOverlay", "kimiK2BuildingShadow"
  ]
  var textures: [String: SKTexture] = [:]
  for name in names {
   guard let resource = load(name) else { return nil }
   textures[name] = resource
  }
  guard let atlas = textures["kimiK2TilesDark"],
        let owners = textures["kimiK2OwnerStripes"],
        let mortgage = textures["kimiK2TileMortgageOverlay"],
        let shadow = textures["kimiK2BuildingShadow"] else { return nil }

  // Validate all UVs BEFORE adding anything to the live scene.
  let frames: [SKTexture]? = {
   var result: [SKTexture] = []
   for tile in KimiK2TileMap.tiles {
    let frame = KimiK2AtlasGeometry.Rect(tile.pixelX, tile.pixelY,
                                          tile.pixelWidth, tile.pixelHeight)
    guard let uv = KimiK2AtlasGeometry.bottomUV(frame: frame) else { return nil }
    let spriteTexture = SKTexture(rect: CGRect(x: CGFloat(uv.x), y: CGFloat(uv.y),
                                               width: CGFloat(uv.width), height: CGFloat(uv.height)), in: atlas)
    spriteTexture.filteringMode = .linear
    result.append(spriteTexture)
   }
   return result
  }()
  guard let frames, frames.count == 40 else { return nil }

  // L0/L1 artwork is already baked into the projected design canvas.
  // Never apply an additional 15-degree yScale to these full-size images.
  for (name, z) in [
   ("kimiK2BoardTableDark", CGFloat(0)),
   ("kimiK2BoardEdgeDark", CGFloat(1)),
   ("kimiK2BoardBaseDark", CGFloat(2)),
   ("kimiK2BoardFrameDark", CGFloat(3))
  ] {
   guard let texture = textures[name] else { continue }
   let node = SKSpriteNode(texture: texture)
   node.position = CGPoint(x: 512, y: 470)
   node.size = CGSize(width: 1024, height: 940)
   node.zPosition = z
   node.name = "KimiK2/" + name
   scene.addChild(node)
  }
  if let texture = textures["kimiK2BoardCenterEmblem"] {
   let emblem = SKSpriteNode(texture: texture)
   emblem.position = CGPoint(x: 512, y: 470)
   emblem.size = CGSize(width: 256, height: 256)
   emblem.zPosition = 3.5
   emblem.name = "KimiK2/emblem"
   scene.addChild(emblem)
  }

  let ownerTextures: [SKTexture] = (0..<4).map { i in
   SKTexture(rect: CGRect(x: CGFloat(i) / 4.0, y: 0, width: 0.25, height: 1),
             in: owners)
  }
  var sprites: [Int: SKSpriteNode] = [:]
  var ownership: [Int: SKSpriteNode] = [:]
  var mortgages: [Int: SKSpriteNode] = [:]
  var shadows: [Int: SKSpriteNode] = [:]
  for (index, tile) in KimiK2TileMap.tiles.enumerated() {
   let sprite = SKSpriteNode(texture: frames[index])
   sprite.position = CGPoint(x: CGFloat(tile.centerX), y: CGFloat(tile.centerY))
   sprite.size = CGSize(width: CGFloat(tile.displayWidth), height: CGFloat(tile.displayHeight))
   sprite.zRotation = CGFloat(tile.rotationRadians)
   sprite.zPosition = 4
   sprite.name = tile.id
   scene.addChild(sprite)
   sprites[index] = sprite

   let stripe = SKSpriteNode(texture: ownerTextures[0])
   stripe.size = CGSize(width: max(24, CGFloat(tile.displayWidth) - 10), height: 9)
   stripe.position = CGPoint(x: 0, y: -CGFloat(tile.displayHeight)/2 + 10)
   stripe.zPosition = 1
   stripe.isHidden = true
   sprite.addChild(stripe)
   ownership[index] = stripe

   let overlay = SKSpriteNode(texture: mortgage)
   overlay.size = sprite.size
   overlay.zPosition = 1.5
   overlay.alpha = 0.77
   overlay.isHidden = true
   sprite.addChild(overlay)
   mortgages[index] = overlay

   let buildingShadow = SKSpriteNode(texture: shadow)
   buildingShadow.position = CGPoint(x: 0, y: CGFloat(tile.displayHeight)/2 - 23)
   buildingShadow.size = CGSize(width: 25, height: 12)
   buildingShadow.zPosition = 1.8
   buildingShadow.isHidden = true
   sprite.addChild(buildingShadow)
   shadows[index] = buildingShadow
  }
  return KimiK2BoardSkin(tiles:sprites, owners:ownership, mortgages:mortgages,
                         shadows:shadows, ownerTextures:ownerTextures)
 }

 func apply(_ state: GameState) {
  for tile in state.board {
   if let stripe = ownerStrips[tile.i] {
    if let owner = tile.owner, ownerTextures.indices.contains(owner) {
     stripe.texture = ownerTextures[owner]
     stripe.isHidden = false
    } else {
     stripe.isHidden = true
    }
   }
   mortgageOverlays[tile.i]?.isHidden = !tile.mortgaged
   improvementShadows[tile.i]?.isHidden = tile.houses == 0 && !tile.hotel
  }
 }
}
#endif
