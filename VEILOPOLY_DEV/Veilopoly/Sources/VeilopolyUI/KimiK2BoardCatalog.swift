/// Stable, source-hashed Kimi K2 2.5D board candidate registry.
/// Metadata only; no texture is present in Bundle.module until independently staged.
public struct KimiK2Asset: Sendable, Equatable {
 public let id: String
 public let alias: String
 public let sourceAlias: String
 public let sha256: String
 public let expectedGitBlobSHA1: String
 public let byteCount: Int
 public let layer: String
 public init(id: String, alias: String, sourceAlias: String,
             sha256: String, expectedGitBlobSHA1: String,
             byteCount: Int, layer: String) {
  self.id=id; self.alias=alias; self.sourceAlias=sourceAlias
  self.sha256=sha256; self.expectedGitBlobSHA1=expectedGitBlobSHA1
  self.byteCount=byteCount; self.layer=layer
 }
}
public enum KimiK2BoardCatalog {
 public static let sourceArchiveSHA256 = "b17b0f9424662f3b4101e21ef5642fbd6a6158f7f87b0ec9d48da1bb6756b04c"
 public static let sourceMapSHA256 = "6da17faa28b0bed1ecbcd70b4e95cb8e7d6b236a267c65baa6486e3b643dbeda"
 public static let tileCount = 40
 public static let atlasWidthPx = 2048
 public static let atlasHeightPx = 1280
 public static let selectedBytes = 519024
 public static let runtimeEnabled = false
 public static let assets: [KimiK2Asset] = [
  .init(id:"VL-K2-ART-001", alias:"kimiK2BoardTableDark", sourceAlias:"boardTableDark", sha256:"c1c33252c8276b297c7d63793e97666a3c08d7688dfb68c4c1d2a3acd020f628", expectedGitBlobSHA1:"3dbc97ee27a3a4730f093c80f084e6bf79729c96", byteCount:24488, layer:"L0"),
  .init(id:"VL-K2-ART-002", alias:"kimiK2BoardTableLight", sourceAlias:"boardTableLight", sha256:"c2ca43189a2581ffdd95f43941c57779c1f24028ee7541e7198b7fc034dc7569", expectedGitBlobSHA1:"1db8f9885e5b0ca12f99f48780542d743d5cfba4", byteCount:23323, layer:"L0"),
  .init(id:"VL-K2-ART-003", alias:"kimiK2BoardEdgeDark", sourceAlias:"boardEdgeDark", sha256:"d1e521fab0942fe424379ddba45a4882b98b9fc97aba740b5c8ea1573be6877f", expectedGitBlobSHA1:"da592e6ab962cbc9358e02a09ec32405a8984018", byteCount:6183, layer:"L1"),
  .init(id:"VL-K2-ART-004", alias:"kimiK2BoardEdgeLight", sourceAlias:"boardEdgeLight", sha256:"ae701a18c73042761a533773f2a1bb19eb102d9a6d655fe44a569d57e276e3b0", expectedGitBlobSHA1:"66548cc716670f9420c142a2f1c7b5fd654451df", byteCount:6427, layer:"L1"),
  .init(id:"VL-K2-ART-005", alias:"kimiK2BoardBaseDark", sourceAlias:"boardBaseDark", sha256:"314b3fce1ca6c8786c19b36120bafa6fa4137c75729ea0d829c37ce0118d501a", expectedGitBlobSHA1:"97a3643ee1f04eb607d6a09361adb10eb355e8bd", byteCount:5989, layer:"L1"),
  .init(id:"VL-K2-ART-006", alias:"kimiK2BoardBaseLight", sourceAlias:"boardBaseLight", sha256:"a44e441df9beff0901bf4877ba790ac28ddba2ada4d8a9e35f6f7b2678da4689", expectedGitBlobSHA1:"9eec652fd09fbea487d4370ae42af198b9ecb02e", byteCount:5979, layer:"L1"),
  .init(id:"VL-K2-ART-007", alias:"kimiK2BoardFrameDark", sourceAlias:"boardFrameDark", sha256:"a6cb8b84a60f9ff723aff410b2f613e958ff4bbead7a336c3c16aea00099881b", expectedGitBlobSHA1:"3e49fa34870cc62aa6cf3f96633394924aa27583", byteCount:147542, layer:"L1"),
  .init(id:"VL-K2-ART-008", alias:"kimiK2BoardFrameLight", sourceAlias:"boardFrameLight", sha256:"57ee15b830a2ac7e22bbc6e1754e952b8d22fd22549847192ee803f065caeebb", expectedGitBlobSHA1:"3cfcd158237f369db0130ae4bd4e735d4039c63e", byteCount:208324, layer:"L1"),
  .init(id:"VL-K2-ART-009", alias:"kimiK2BoardCenterEmblem", sourceAlias:"boardCenterEmblem", sha256:"a3e1948a818ef0576aae14dacfbbc6430d75d516de89fbf7a4fe6eab8da00f12", expectedGitBlobSHA1:"e2fcaaa0bb5ceb8d66ccd195141316a17413b9bc", byteCount:3820, layer:"L3"),
  .init(id:"VL-K2-ART-010", alias:"kimiK2TilesDark", sourceAlias:"tilesDark", sha256:"f2a85ffaa597622044a9d79ebbee779d9bbd4b81db07da7f004ca42e2281bb45", expectedGitBlobSHA1:"dc757a375a373ac4f7ac17907a4e8bc0aa75a23b", byteCount:30631, layer:"L1"),
  .init(id:"VL-K2-ART-011", alias:"kimiK2TilesLight", sourceAlias:"tilesLight", sha256:"f61de562551d041aea025190a3dd19b9feb40d6ea177f15b7757357d9c41043e", expectedGitBlobSHA1:"8b28e51ddc91b6a6452425c78ed4d1baf4e4a29c", byteCount:30800, layer:"L1"),
  .init(id:"VL-K2-ART-012", alias:"kimiK2OwnerStripes", sourceAlias:"ownerStripes", sha256:"ab17fc27fab1fcce32333296162b654a8622aa49e59d78940bfe6dcf187dbb9e", expectedGitBlobSHA1:"a7c4c9cf9a5e38cd41cc154afe1af2cd89fa298e", byteCount:2160, layer:"L2"),
  .init(id:"VL-K2-ART-013", alias:"kimiK2TileMortgageOverlay", sourceAlias:"tileMortgageOverlay", sha256:"7e71b1a76ee2ca4bbb6d1cf48796adce454eb6632d80c898368e2104373a5623", expectedGitBlobSHA1:"b979da70ec042f0928394c24d2566a007f012897", byteCount:3115, layer:"L2"),
  .init(id:"VL-K2-ART-014", alias:"kimiK2BuildingShadow", sourceAlias:"buildingShadow", sha256:"bbd84eb388367dd7c19d46fa55721db4ed7201c17f3df33b423af04a5136b54b", expectedGitBlobSHA1:"ab2612db978403b7875c5cf144b3ac5d574fb19e", byteCount:2042, layer:"L2"),
  .init(id:"VL-K2-ART-015", alias:"kimiK2SpecialIconsMask", sourceAlias:"specialIconsMask", sha256:"0e220e16fb5aa63a093d3c9bd39298f6f9b5484c495c3fb07df60eb1e1bdce6a", expectedGitBlobSHA1:"0a109e2b7a45d2f75423dcc98e10646ca4a4913a", byteCount:18201, layer:"L3"),
 ]
 public static func find(_ sourceAlias: String) -> KimiK2Asset? {
  assets.first { $0.sourceAlias == sourceAlias }
 }
 public static func tileAtlas(light: Bool) -> KimiK2Asset? {
  find(light ? "tilesLight" : "tilesDark")
 }
 public static func base(light: Bool) -> KimiK2Asset? {
  find(light ? "boardBaseLight" : "boardBaseDark")
 }
}
