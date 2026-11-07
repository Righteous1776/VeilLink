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
 private(set) var isLight = false
 private let backgrounds: [String: SKSpriteNode]
 private let darkBackgroundTextures: [String: SKTexture]
 private let lightBackgroundTextures: [String: SKTexture]
 private let darkTileFrames: [SKTexture]
 private let lightTileFrames: [SKTexture]

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

 private init(tiles: [Int: SKSpriteNode], backgrounds: [String: SKSpriteNode],
              darkBackgroundTextures: [String: SKTexture],
              lightBackgroundTextures: [String: SKTexture],
              darkTileFrames: [SKTexture], lightTileFrames: [SKTexture],
              ownerTextures: [SKTexture], mortgageTexture: SKTexture,
              shadowTexture: SKTexture, houseTexture: SKTexture?, hotelTexture: SKTexture?) {
  self.tiles=tiles
  self.backgrounds=backgrounds
  self.darkBackgroundTextures=darkBackgroundTextures
  self.lightBackgroundTextures=lightBackgroundTextures
  self.darkTileFrames=darkTileFrames
  self.lightTileFrames=lightTileFrames
  self.ownerTextures=ownerTextures
  self.mortgageTexture=mortgageTexture
  self.buildingShadowTexture=shadowTexture
  self.houseTexture=houseTexture
  self.hotelTexture=hotelTexture
  usesBuildingSprites = houseTexture != nil && hotelTexture != nil
 }

 static func install(in scene: SKScene, load: (String) -> SKTexture?) -> KimiK2BoardSkin? {
  guard KimiK2BoardCatalog.runtimeEnabled, KimiK2TileMap.tiles.count == 40 else { return nil }
  // All eight theme-specific PNGs have already passed Git object/byte audit.
  // Treat theme loading as one transaction: missing art falls back to the
  // original procedural board instead of leaving a half-skinned state.
  let names = [
   "kimiK2BoardTableDark", "kimiK2BoardEdgeDark", "kimiK2BoardBaseDark",
   "kimiK2BoardFrameDark", "kimiK2BoardTableLight", "kimiK2BoardEdgeLight",
   "kimiK2BoardBaseLight", "kimiK2BoardFrameLight", "kimiK2BoardCenterEmblem",
   "kimiK2TilesDark", "kimiK2TilesLight", "kimiK2OwnerStripes",
   "kimiK2TileMortgageOverlay", "kimiK2BuildingShadow"
  ]
  var textures: [String: SKTexture] = [:]
  for name in names {
   guard let resource = load(name) else { return nil }
   textures[name] = resource
  }
  guard let atlas = textures["kimiK2TilesDark"],
        let lightAtlas = textures["kimiK2TilesLight"],
        let owners = textures["kimiK2OwnerStripes"],
        let mortgage = textures["kimiK2TileMortgageOverlay"],
        let shadow = textures["kimiK2BuildingShadow"] else { return nil }

  func frames(for atlas: SKTexture) -> [SKTexture]? {
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
   return result.count == 40 ? result : nil
  }
  guard let darkFrames = frames(for: atlas),
        let lightFrames = frames(for: lightAtlas) else { return nil }

  // K2 projected layers share a single fixed canvas. Never apply a second
  // perspective transform when swapping day/night art at runtime.
  let backgroundKeys: [(key: String, z: CGFloat)] = [
   ("BoardTable", 0), ("BoardEdge", 1), ("BoardBase", 2), ("BoardFrame", 3)
  ]
  var backgrounds: [String: SKSpriteNode] = [:]
  var darkBackgrounds: [String: SKTexture] = [:]
  var lightBackgrounds: [String: SKTexture] = [:]
  for item in backgroundKeys {
   guard let dark = textures["kimiK2" + item.key + "Dark"],
         let light = textures["kimiK2" + item.key + "Light"] else { return nil }
   darkBackgrounds[item.key] = dark
   lightBackgrounds[item.key] = light
   let background = SKSpriteNode(texture: dark)
   background.position = CGPoint(x: 512, y: 470)
   background.size = CGSize(width: 1024, height: 940)
   background.zPosition = item.z
   background.name = "KimiK2/" + item.key
   backgrounds[item.key] = background
   scene.addChild(background)
  }
  let centerCity = load(AstraCenterCityArtwork.alias)
  if let texture = centerCity ?? textures["kimiK2BoardCenterEmblem"] {
   let emblem = SKSpriteNode(texture: texture)
   emblem.position = CGPoint(x: CGFloat(AstraCenterCityArtwork.centerX),
                             y: CGFloat(AstraCenterCityArtwork.centerY))
   let size: CGFloat = centerCity == nil ? 256 : CGFloat(AstraCenterCityArtwork.displaySize)
   emblem.size = CGSize(width: size, height: size)
   emblem.zPosition = 3.5
   emblem.name = centerCity == nil ? "KimiK2/emblem" : "Astra/centerCity"
   scene.addChild(emblem)
  }

  let ownerTextures: [SKTexture] = (0..<4).map { index in
   SKTexture(rect: CGRect(x: CGFloat(index)/4.0, y: 0, width: 0.25, height: 1),
             in: owners)
  }
  var tileSprites: [Int: SKSpriteNode] = [:]
  for (index, tile) in KimiK2TileMap.tiles.enumerated() {
   let sprite = SKSpriteNode(texture: darkFrames[index])
   sprite.position = CGPoint(x: CGFloat(tile.centerX), y: CGFloat(tile.centerY))
   sprite.size = CGSize(width: CGFloat(tile.displayWidth), height: CGFloat(tile.displayHeight))
   sprite.zRotation = CGFloat(tile.rotationRadians)
   sprite.zPosition = 4
   sprite.name = tile.id
   scene.addChild(sprite)
   tileSprites[index] = sprite
  }
  return KimiK2BoardSkin(tiles: tileSprites, backgrounds: backgrounds,
                         darkBackgroundTextures: darkBackgrounds,
                         lightBackgroundTextures: lightBackgrounds,
                         darkTileFrames: darkFrames, lightTileFrames: lightFrames,
                         ownerTextures: ownerTextures,
                         mortgageTexture: mortgage, shadowTexture: shadow,
                         houseTexture: load("house"), hotelTexture: load("hotel"))
 }

 /// Swap preloaded visual textures without recreating Engine, tile nodes,
 /// touch regions, dynamic owner/building state, or the camera.
 func setLight(_ light: Bool) {
  guard isLight != light else { return }
  isLight = light
  for (key, node) in backgrounds {
   node.texture = light ? lightBackgroundTextures[key] : darkBackgroundTextures[key]
  }
  let selected = light ? lightTileFrames : darkTileFrames
  for (index, node) in tiles where selected.indices.contains(index) {
   node.texture = selected[index]
  }
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
