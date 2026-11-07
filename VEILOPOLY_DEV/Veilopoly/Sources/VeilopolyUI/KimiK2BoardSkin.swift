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
 let usesFineTiles: Bool
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
 private let detailedBuildings: Bool
 private let fineTextures: [String: SKTexture]
 private var fineIcons: [Int: SKSpriteNode] = [:]
 private var groupBands: [Int: SKSpriteNode] = [:]
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
              shadowTexture: SKTexture, houseTexture: SKTexture?, hotelTexture: SKTexture?,
              detailedBuildings: Bool, fineTextures: [String: SKTexture]) {
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
  self.detailedBuildings=detailedBuildings
  self.fineTextures=fineTextures
  usesFineTiles = fineTextures.count == AstraTileArtwork.aliases.count
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
  var fineTextures: [String: SKTexture] = [:]
  for alias in AstraTileArtwork.aliases {
   if let texture = load(alias) { fineTextures[alias] = texture }
  }
  if fineTextures.count != AstraTileArtwork.aliases.count { fineTextures = [:] }

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

  // Two independent shallow card stacks echo a physical perimeter board.
  // They are decorative deck markers, not extra draw actions or baked UI.
  if let face = fineTextures[AstraTileArtwork.face] {
   for (index, x) in [212.0, 812.0].enumerated() {
    let stack = SKNode()
    stack.name = index == 0 ? "Astra/chance-deck" : "Astra/chest-deck"
    stack.position = CGPoint(x: CGFloat(x), y: 470)
    stack.zPosition = 3.6
    for depth in 0..<3 {
     let card = SKSpriteNode(texture: face)
     card.size = CGSize(width: 76, height: 106)
     card.position = CGPoint(x: CGFloat(depth) * 2, y: CGFloat(depth) * 2)
     card.zPosition = CGFloat(depth) * 0.1
     stack.addChild(card)
    }
    let alias = index == 0 ? "astraTileChance" : "astraTileChest"
    if let texture = fineTextures[alias] {
     let icon = SKSpriteNode(texture: texture)
     icon.size = CGSize(width: 42, height: 42)
     icon.position = CGPoint(x: 4, y: 12)
     icon.zPosition = 0.4
     stack.addChild(icon)
    }
    let label = SKLabelNode(text: index == 0 ? "机会" : "命运")
    label.fontName = "AvenirNext-DemiBold"; label.fontSize = 12
    label.fontColor = SKColor(red: 0.1, green: 0.22, blue: 0.23, alpha: 1)
    label.position = CGPoint(x: 4, y: -30); label.zPosition = 0.4
    stack.addChild(label)
    scene.addChild(stack)
   }
  }

  let ownerTextures: [SKTexture] = (0..<4).map { index in
   SKTexture(rect: CGRect(x: CGFloat(index)/4.0, y: 0, width: 0.25, height: 1),
             in: owners)
  }
  var tileSprites: [Int: SKSpriteNode] = [:]
  for (index, tile) in KimiK2TileMap.tiles.enumerated() {
   let sprite = SKSpriteNode(texture: fineTextures[AstraTileArtwork.face] ?? darkFrames[index])
   sprite.position = CGPoint(x: CGFloat(tile.centerX), y: CGFloat(tile.centerY))
   sprite.size = CGSize(width: CGFloat(tile.displayWidth), height: CGFloat(tile.displayHeight))
   sprite.zRotation = CGFloat(tile.rotationRadians)
   sprite.zPosition = 4
   sprite.name = tile.id
   scene.addChild(sprite)
   tileSprites[index] = sprite
  }
  let detailHouse = load(AstraDetailArtwork.house)
  let detailHotel = load(AstraDetailArtwork.hotel)
  let hasDetails = detailHouse != nil && detailHotel != nil
  return KimiK2BoardSkin(tiles: tileSprites, backgrounds: backgrounds,
                         darkBackgroundTextures: darkBackgrounds,
                         lightBackgroundTextures: lightBackgrounds,
                         darkTileFrames: darkFrames, lightTileFrames: lightFrames,
                         ownerTextures: ownerTextures,
                         mortgageTexture: mortgage, shadowTexture: shadow,
                         houseTexture: hasDetails ? detailHouse : load("house"),
                         hotelTexture: hasDetails ? detailHotel : load("hotel"),
                         detailedBuildings: hasDetails, fineTextures: fineTextures)
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
  for (index, node) in tiles where selected.indices.contains(index) && !usesFineTiles {
   node.texture = selected[index]
  }
 }

 func apply(_ state: GameState) {
  for tile in state.board {
   guard let art = tiles[tile.i] else { continue }
   let layout = KimiK2TileMap.visual(for: tile.i).map(AstraTileArtwork.layout)
   func point(_ x: Double, _ y: Double) -> CGPoint {
    let p = layout?.local(x, y) ?? (x: x, y: y)
    return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
   }
   if usesFineTiles, let layout {
    if tile.kind == .street, let color = tile.color {
     let band = groupBands[tile.i] ?? SKSpriteNode()
     if band.parent == nil { art.addChild(band); groupBands[tile.i] = band }
     band.name = "LivePropertyBand"
     band.color = Self.groupColor(color)
     // Tile-local +Y points toward the center on every edge of the board.
     band.size = CGSize(width: art.size.width - 12, height: 8)
     band.position = CGPoint(x: 0, y: art.size.height / 2 - 8)
     band.zRotation = 0; band.zPosition = 0.8
    } else { groupBands.removeValue(forKey: tile.i)?.removeFromParent() }
    if let alias = AstraTileArtwork.icon(for: tile), let texture = fineTextures[alias] {
     let icon = fineIcons[tile.i] ?? SKSpriteNode()
     if icon.parent == nil { art.addChild(icon); fineIcons[tile.i] = icon }
     icon.name = "LiveSpecialIcon"
     icon.texture = texture
     icon.size = CGSize(width: CGFloat(layout.iconSize), height: CGFloat(layout.iconSize))
     icon.position = point(0, layout.iconY)
     icon.zRotation = -art.zRotation; icon.zPosition = 1.1
    } else { fineIcons.removeValue(forKey: tile.i)?.removeFromParent() }
   }
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
    if usesFineTiles, let layout {
     stripe.size = CGSize(width: CGFloat(layout.width - 12), height: 3)
     stripe.position = point(0, -layout.height / 2 + 3)
     stripe.zRotation = -art.zRotation
    }
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
     if usesFineTiles, let layout {
      shadow.position = point(0, layout.buildingY - 6)
      shadow.zRotation = -art.zRotation
      shadow.size = CGSize(width: 54, height: 10)
     }
     art.addChild(shadow)
     improvementShadows[tile.i] = shadow
    }
   } else {
    improvementShadows.removeValue(forKey: tile.i)?.removeFromParent()
   }

   // Rebuild only on the actual house/hotel state transition. The detailed
   // sprites keep one world-space light direction despite rotated edge tiles.
   if usesBuildingSprites && lastBuildingState[tile.i] != targetCount {
    lastBuildingState[tile.i] = targetCount
    buildingSprites.removeValue(forKey: tile.i)?.forEach { $0.removeFromParent() }
    var visuals: [SKSpriteNode] = []
    if targetCount == 5, let hotelTexture {
     let hotel = SKSpriteNode(texture: hotelTexture)
     hotel.name = "Veilopoly/hotel-\(tile.i)"
     hotel.zRotation = detailedBuildings ? -art.zRotation : 0
     hotel.size = CGSize(width: 21, height: 21)
     hotel.position = CGPoint(x: 0, y: art.size.height/2 - 23)
     if usesFineTiles, let layout { hotel.position = point(0, layout.buildingY) }
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
      house.name = "Veilopoly/house-\(tile.i)-\(i)"
      house.zRotation = detailedBuildings ? -art.zRotation : 0
      house.size = CGSize(width: 14, height: 14)
      house.position = positions[i]
      if usesFineTiles, let layout {
       house.position = point([-22.0, -7.0, 7.0, 22.0][i], layout.buildingY)
      }
      house.zPosition = 2
      art.addChild(house)
      visuals.append(house)
     }
    }
    buildingSprites[tile.i] = visuals
   }
  }
 }

 private static func groupColor(_ color: ColorGroup) -> SKColor {
  switch color {
  case .brown: return .brown
  case .lightBlue: return SKColor(red: 0.49, green: 0.78, blue: 0.93, alpha: 1)
  case .pink: return SKColor(red: 0.92, green: 0.38, blue: 0.64, alpha: 1)
  case .orange: return .orange
  case .red: return .red
  case .yellow: return .yellow
  case .green: return .green
  case .darkBlue: return SKColor(red: 0.13, green: 0.24, blue: 0.76, alpha: 1)
  }
 }
}
#endif
