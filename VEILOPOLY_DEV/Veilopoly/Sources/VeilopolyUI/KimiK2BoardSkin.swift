#if os(iOS) && canImport(SpriteKit)
import SpriteKit
import VeilopolyEngine

/// Kimi K2 original-pixel 2.5D board. Render-only; Engine owns all game rules.
/// The entire atlas is preflighted before any new SKNode enters the live scene.
/// Optional ownership/building overlays are allocated only when in use.
@MainActor
final class KimiK2BoardSkin {
 let tiles: [Int: SKSpriteNode]
 let usesBuildingSprites: Bool

 private let ownerTextures: [SKTexture]
 private let mortgageTexture: SKTexture
 private let buildingShadowTexture: SKTexture
 private let houseTexture: SKTexture?
 private let hotelTexture: SKTexture?
 private var ownerStrips: [Int: SKSpriteNode] = [:]
 private var mortgageOverlays: [Int: SKSpriteNode] = [:]
 private var improvementShadows: [Int: SKSpriteNode] = [:]
 private var buildingSprites: [Int: [SKSpriteNode]] = [:]
 private var lastBuildingState: [Int: Int] = [:]

 private init(tiles: [Int: SKSpriteNode], ownerTextures: [SKTexture],
              mortgageTexture: SKTexture, shadowTexture: SKTexture,
              houseTexture: SKTexture?, hotelTexture: SKTexture?) {
  self.tiles=tiles; self.ownerTextures=ownerTextures
  self.mortgageTexture=mortgageTexture
  self.buildingShadowTexture=shadowTexture
  self.houseTexture=houseTexture
  self.hotelTexture=hotelTexture
  usesBuildingSprites = houseTexture != nil && hotelTexture != nil
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

  let frames: [SKTexture]? = {
   var result: [SKTexture] = []
   for tile in KimiK2TileMap.tiles {
    let frame = KimiK2AtlasGeometry.Rect(tile.pixelX, tile.pixelY,
                                          tile.pixelWidth, tile.pixelHeight)
    guard let uv = KimiK2AtlasGeometry.bottomUV(frame: frame) else { return nil }
    let subtexture = SKTexture(rect: CGRect(x: CGFloat(uv.x), y: CGFloat(uv.y),
                                             width: CGFloat(uv.width), height: CGFloat(uv.height)), in: atlas)
    subtexture.filteringMode = .linear
    result.append(subtexture)
   }
   return result
  }()
  guard let frames, frames.count == 40 else { return nil }

  // The Kimi base, edge and frame already contain the projected board shape.
  // Do not add a second yScale or reinterpret their 1024×940 canvas.
  for (name, z) in [
   ("kimiK2BoardTableDark", CGFloat(0)),
   ("kimiK2BoardEdgeDark", CGFloat(1)),
   ("kimiK2BoardBaseDark", CGFloat(2)),
   ("kimiK2BoardFrameDark", CGFloat(3))
  ] {
   guard let texture = textures[name] else { continue }
   let background = SKSpriteNode(texture: texture)
   background.position = CGPoint(x: 512, y: 470)
   background.size = CGSize(width: 1024, height: 940)
   background.zPosition = z
   background.name = "KimiK2/" + name
   scene.addChild(background)
  }
  if let texture = textures["kimiK2BoardCenterEmblem"] {
   let emblem = SKSpriteNode(texture: texture)
   emblem.position = CGPoint(x: 512, y: 470)
   emblem.size = CGSize(width: 256, height: 256)
   emblem.zPosition = 3.5
   emblem.name = "KimiK2/emblem"
   scene.addChild(emblem)
  }

  let ownerTextures: [SKTexture] = (0..<4).map { index in
   SKTexture(rect: CGRect(x: CGFloat(index)/4.0, y: 0, width: 0.25, height: 1),
             in: owners)
  }
  var tileSprites: [Int: SKSpriteNode] = [:]
  for (index, tile) in KimiK2TileMap.tiles.enumerated() {
   let sprite = SKSpriteNode(texture: frames[index])
   sprite.position = CGPoint(x: CGFloat(tile.centerX), y: CGFloat(tile.centerY))
   sprite.size = CGSize(width: CGFloat(tile.displayWidth), height: CGFloat(tile.displayHeight))
   sprite.zRotation = CGFloat(tile.rotationRadians)
   sprite.zPosition = 4
   sprite.name = tile.id
   scene.addChild(sprite)
   tileSprites[index] = sprite
  }
  return KimiK2BoardSkin(tiles: tileSprites, ownerTextures: ownerTextures,
                         mortgageTexture: mortgage, shadowTexture: shadow,
                         houseTexture: load("house"), hotelTexture: load("hotel"))
 }

 func apply(_ state: GameState) {
  for tile in state.board {
   guard let art = tiles[tile.i] else { continue }
   if let owner = tile.owner, ownerTextures.indices.contains(owner) {
    let stripe: SKSpriteNode
    if let existing = ownerStrips[tile.i] { stripe = existing }
    else {
     stripe = SKSpriteNode(texture: ownerTextures[owner])
     stripe.size = CGSize(width: max(24, art.size.width - 10), height: 9)
     stripe.position = CGPoint(x: 0, y: -art.size.height/2 + 10)
     stripe.zPosition = 1
     art.addChild(stripe)
     ownerStrips[tile.i] = stripe
    }
    stripe.texture = ownerTextures[owner]
   } else {
    ownerStrips.removeValue(forKey: tile.i)?.removeFromParent()
   }

   if tile.mortgaged {
    if mortgageOverlays[tile.i] == nil {
     let overlay = SKSpriteNode(texture: mortgageTexture)
     overlay.size = art.size
     overlay.zPosition = 3.5
     overlay.alpha = 0.77
     art.addChild(overlay)
     mortgageOverlays[tile.i] = overlay
    }
   } else {
    mortgageOverlays.removeValue(forKey: tile.i)?.removeFromParent()
   }

   let targetCount = tile.hotel ? 5 : max(0, min(4, tile.houses))
   if targetCount > 0 {
    if improvementShadows[tile.i] == nil {
     let shadow = SKSpriteNode(texture: buildingShadowTexture)
     shadow.position = CGPoint(x: 0, y: art.size.height/2 - 23)
     shadow.size = CGSize(width: 28, height: 13)
     shadow.zPosition = 1.8
     art.addChild(shadow)
     improvementShadows[tile.i] = shadow
    }
   } else {
    improvementShadows.removeValue(forKey: tile.i)?.removeFromParent()
   }

   // Rebuild only on the actual house/hotel state transition. Assets are
   // inherited Kenney K1; no static Kimi preview content changes gameplay.
   if usesBuildingSprites && lastBuildingState[tile.i] != targetCount {
    lastBuildingState[tile.i] = targetCount
    buildingSprites.removeValue(forKey: tile.i)?.forEach { $0.removeFromParent() }
    var visuals: [SKSpriteNode] = []
    if targetCount == 5, let hotelTexture {
     let hotel = SKSpriteNode(texture: hotelTexture)
     hotel.size = CGSize(width: 21, height: 21)
     hotel.position = CGPoint(x: 0, y: art.size.height/2 - 23)
     hotel.zPosition = 2
     art.addChild(hotel)
     visuals.append(hotel)
    } else if targetCount > 0, let houseTexture {
     let positions: [CGPoint] = [
      CGPoint(x: -13, y: art.size.height/2 - 19),
      CGPoint(x:  13, y: art.size.height/2 - 19),
      CGPoint(x: -13, y: art.size.height/2 - 32),
      CGPoint(x:  13, y: art.size.height/2 - 32)
     ]
     for i in 0..<min(4, targetCount) {
      let house = SKSpriteNode(texture: houseTexture)
      house.size = CGSize(width: 14, height: 14)
      house.position = positions[i]
      house.zPosition = 2
      art.addChild(house)
      visuals.append(house)
     }
    }
    buildingSprites[tile.i] = visuals
   }
  }
 }
}
#endif
