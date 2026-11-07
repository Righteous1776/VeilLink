import Foundation

/// Only visual prose. Never include this catalog in GameState, network hashes,
/// simulated prices, card resolution, dice or persistent serialization.
public struct VeilopolyWorldPage: Equatable {
 public let id: String
 public let index: Int
 public let canonicalName: String
 public let kind: TileKind
 public let title: String
 public let teaser: String
 public let story: String
 public init(_ index: Int, _ canonicalName: String, _ kind: TileKind,
             _ title: String, _ teaser: String, _ story: String) {
  self.index = index
  self.id = "VL-LORE-TILE-" + String(format: "%02d", index)
  self.canonicalName = canonicalName
  self.kind = kind
  self.title = title
  self.teaser = teaser
  self.story = story
 }
}

/// Canonical 40-square world text, tied strictly to the current provisional
/// board names and types. Renamed or custom tiles automatically show no lore.
public enum VeilopolyWorldEditorial {
 public static let edition = "VEILOPOLY-IVORY-WORLD-R1"
 public static let pages: [VeilopolyWorldPage] = [
  .init(0, "起点", .go, "启程之章", "钟楼下，新的回合正等待开篇。", "白石广场的喷泉静静流动，行囊与车票在晨光中排列整齐。每一次经过此地，都像是城市为旅人重新打开了一扇门。"),
  .init(1, "地中海大道", .street, "海风旧街", "一封来自海岸的邀请，被压在街角的地图下。", "街道两侧的窗台上长着常青藤，微咸的风穿过拱廊。商铺的钥匙挂在铜钩上，等待下一位愿意细心经营的人。"),
  .init(2, "命运", .chest, "封缄之函", "一封盖着蜡印的信，尚未写明收件人的未来。", "旧邮局的信使递来一只素色信封。信里可能是一笔意外的礼金，也可能是等待签收的账目；答案只在拆封时出现。"),
  .init(3, "波罗的海大道", .street, "雾港小径", "海港的晨雾，将街灯柔和地藏了起来。", "这里的石砌码头记得许多次告别。薄雾散去后，修船铺的门板次第抬起，来自远方的生意又悄然靠岸。"),
  .init(4, "所得税", .tax, "税务公署", "每一笔往来，都要在账册中留下清晰的一行。", "长窗后，书记员正整理本季的银号账册。城市的道路与灯火有其开支，今日所需缴纳的款项由正式规则裁定。"),
  .init(5, "铁路 5", .railroad, "第一站台", "汽笛响起，列车为旅人留下一段新路程。", "褪色的时刻表仍悬在铁艺拱顶下。第一班车穿过低矮城门，车站从清晨起便成为商旅交换消息的地方。"),
  .init(6, "东方大道", .street, "晨曦长廊", "金色晨光，沿着长廊的石柱缓缓移动。", "古老的铺石路一直通向东侧集市。店主在门口摆放新到的货物，纸袋和铜铃让整条长廊有了生气。"),
  .init(7, "机会", .chance, "偶然来信", "命运的另一条小径，往往从一张车票开始。", "街头报童递来一张印着金边的短笺。你不知道下一步会驶向哪一站，只知道这座城市总为好奇的人留着侧门。"),
  .init(8, "佛蒙特大道", .street, "松影街角", "安静的树影里，藏着一间还亮着灯的书店。", "大道上的砖墙被松枝轻轻遮住。午后的读者坐在窗边翻开旧书，而店外的行人继续赶赴各自的约会。"),
  .init(9, "康涅狄格大道", .street, "白石寓所", "洁白的石阶通向整齐而温暖的旧式庭院。", "狭长的花坛沿着门前围栏延伸。傍晚时分，窗后的灯一盏盏亮起，整条街仿佛被细心地收进画框。"),
  .init(10, "监狱 / 探访", .jail, "铁门与钟声", "钟声照常敲响，铁门内外却有不同的时间。", "法庭的回廊安静而庄重。探访者在簿册上签名；当事人能否离开，则取决于本局已有的出狱规则。"),
  .init(11, "圣查尔斯广场", .street, "花窗广场", "华丽的花窗，把彩色光斑洒在浅色石地上。", "广场中央的长椅面对一排拱形廊柱。午后总有人带来一束新花，入夜后则只剩轻柔的脚步声。"),
  .init(12, "公共事业 12", .utility, "灯火事务所", "当第一盏路灯点亮，城市便拥有了夜晚。", "铜制仪表在小小的控制室中运转。整座城市的光与动力从这里被细心记录，账面归属仍以当前游戏状态为准。"),
  .init(13, "州大道", .street, "议事长街", "旧式门廊下，商人与旅客交换各自的消息。", "这条街连接着邮局和市政厅。每日午后，总有匆忙的信差穿过廊柱，带走刚写完的文件。"),
  .init(14, "弗吉尼亚大道", .street, "丝绒橱窗", "橱窗里的丝绒与玻璃，留住了黄昏的余光。", "裁缝店在门前挂起当天的样衣。拱廊里的音乐若有若无，来客们常在这里为某个重要日子挑选礼物。"),
  .init(15, "铁路 15", .railroad, "第二站台", "地图翻到下一页，列车驶入繁忙的城区。", "信号灯在铁轨旁轮流亮起。候车室里摆着几只旧皮箱，一张张车票把陌生人的故事短暂地并在一起。"),
  .init(16, "圣詹姆斯广场", .street, "晚钟庭院", "晚钟穿过庭院，落在修长的石柱之间。", "广场边的小剧院刚刚换上海报。傍晚的人群沿鹅卵石路而来，灯光让每扇门都有了自己的舞台。"),
  .init(17, "命运", .chest, "第二封信", "命运并不总在路口等候，也藏在平常的来信里。", "邮差将一封素纸信放在门前。你还没看见署名，就已经听到远处钟声；拆开之后，账簿或许会多出一页。"),
  .init(18, "田纳西大道", .street, "爵士长夜", "爵士乐的节奏，随街角的灯光缓缓摇曳。", "傍晚的小酒馆外贴着新演出的海报。路边的留声机转动着唱片，这条大道从不急着让夜晚结束。"),
  .init(19, "纽约大道", .street, "霓虹橱窗", "拥挤的十字路口，写满城市不眠的故事。", "高楼下的报摊传来纸张翻动的声音。每个人都在赶路，唯有橱窗里的暖光耐心照看着匆忙的人群。"),
  .init(20, "免费停车", .freeParking, "静候之所", "暂时停靠，也是一段旅程必要的留白。", "石桥边留有一块宽阔的空地，旅人可以在这里重新整理地图。此处是否涉及奖励，只以本局既定规则为准。"),
  .init(21, "肯塔基大道", .street, "红砖巡礼", "红砖建筑连成街景，像一本缓慢展开的旧书。", "巷口的小钟楼仍依旧时的节奏报时。窗边的花盆与台阶被仔细擦拭，整条大道透着安稳的生活气息。"),
  .init(22, "机会", .chance, "十字路口", "一张薄纸邀请函，可能改写下一站的方向。", "街头的公告板刚换上新的一页。有人在这里得到旅行的机会，也有人收获一份意外的任务；唯有抽卡后才知道答案。"),
  .init(23, "印第安纳大道", .street, "落叶与拱门", "长长的树荫，把午后的路分成明暗两半。", "老宅的铁门边堆着金色落叶。钟表匠偶尔停下手中的工作，望着窗外新开张的店铺。"),
  .init(24, "伊利诺伊大道", .street, "金穗长街", "粮仓的铜制门牌，在阳光里闪着温暖的光。", "手推车沿着平整的石路缓慢前行。长街两侧的集市从清晨一直热闹到黄昏，橱窗里摆满来自远地的货物。"),
  .init(25, "铁路 25", .railroad, "第三站台", "钟表指针划过整点，月台再次响起汽笛。", "红色信号旗在风中舒展。旧式木椅上叠着几份报纸，车轮声带着旅客前往城市更远的边缘。"),
  .init(26, "大西洋大道", .street, "潮声大道", "远处潮声不息，金边路牌映着午后日光。", "海边的步道铺着浅灰石砖。行人沿着防波堤散步，路旁的咖啡馆把最好的窗位留给了海面。"),
  .init(27, "文特诺大道", .street, "庭园回廊", "修剪齐整的绿篱，围住了一座安静的庭院。", "阳光穿过细长的枝叶，照在浅色拱门上。人们在此写信、散步，或讨论下一场小小的城市庆典。"),
  .init(28, "公共事业 28", .utility, "水务档案馆", "城市的水脉，被记录在一本厚厚的蓝色账册里。", "老式水塔投下长长的影子。检修员沿着管道缓缓巡查，让每一条街的日常继续安稳运转。"),
  .init(29, "马文花园", .street, "四季花庭", "枝叶围成的花径，藏着四季不同的颜色。", "花园里有一座小小的喷泉。春天是新芽，夏天是长椅上的书，秋天则有落叶轻轻盖住石阶。"),
  .init(30, "前往监狱", .goToJail, "司法令", "有些道路不由旅人选择，裁定会决定下一站。", "公署的台阶上传来匆忙的脚步声。一份正式文书已送达，接下来的移动由本局司法与出狱规则处理。"),
  .init(31, "太平洋大道", .street, "远洋航图", "古铜色航海图上，海风吹开了一角。", "临海的观景台镶着深色栏杆。旧船只的模型陈列在窗边，提醒往来商人海洋另一侧仍有新的故事。"),
  .init(32, "北卡罗来纳大道", .street, "松林庄园", "松林尽头的白色屋檐，映着最后一缕夕阳。", "笔直的长路连接着几座安静的宅邸。园丁细心照看门前的绿篱，让四季都有不同的风景。"),
  .init(33, "命运", .chest, "第三封信", "封蜡仍未拆开，未知仍有它自己的分量。", "旧信箱里有一封没有回信地址的来函。纸张很轻，落在账册上却仿佛多了一份重量；内容要在抽取时才揭晓。"),
  .init(34, "宾夕法尼亚大道", .street, "长阶公馆", "高高的石阶通向一排灯光温暖的公馆。", "庄重的门廊在傍晚显出柔和轮廓。远处的马车声渐渐隐去，只留下玻璃窗上的金色反光。"),
  .init(35, "铁路 35", .railroad, "终点站台", "一趟列车结束旅程，下一趟已经准备启程。", "站厅中央的钟没有停过。旅客提着行李从不同方向汇聚，在下一声汽笛响起前完成自己的告别。"),
  .init(36, "机会", .chance, "最后的转角", "走到城墙尽头，仍有一封邀请等在拐角。", "路牌后藏着一道通向旧城区的小路。你以为已经熟悉这座城市，它却总能留下一张未曾见过的车票。"),
  .init(37, "公园大道", .street, "青铜林荫", "枝叶遮住喧嚣，长椅上只剩细碎的日光。", "这里的街灯镶着古铜色花纹。雨后的树干散发清香，住户在门前摆好一束刚摘下的花。"),
  .init(38, "奢侈税", .tax, "特别征收", "贵重的物件，也会在账册上留下另一种重量。", "征收厅的橱窗摆着历年的印章。税额不是故事的一部分，而由本局规则在抵达此格时准确结算。"),
  .init(39, "木板路", .street, "海岸终章", "木板路伸向海面，夕阳把天际染成金色。", "浪声从栏杆下传来，远处的灯塔在暮色里点亮。这里是漫长旅途的海岸，也是下一场城市故事的序章。"),
 ]
 public static func page(for tile: Tile) -> VeilopolyWorldPage? {
  guard pages.indices.contains(tile.i) else { return nil }
  let page = pages[tile.i]
  guard page.index == tile.i, page.canonicalName == tile.name,
        page.kind == tile.kind else { return nil }
  return page
 }
}

public struct VeilopolyIssuerPage: Equatable {
 public let symbol: String
 public let canonicalName: String
 public let sector: String
 public let subtitle: String
 public let summary: String
 public init(_ symbol: String, _ canonicalName: String, _ sector: String,
             _ subtitle: String, _ summary: String) {
  self.symbol = symbol; self.canonicalName = canonicalName
  self.sector = sector; self.subtitle = subtitle; self.summary = summary
 }
}

/// Five fictional issuer blurbs. No made-up financial fundamentals, dividends,
/// profitability, price projections or real-world advice.
public enum VeilopolyMarketEditorial {
 public static let edition = "VEILOPOLY-IVORY-EXCHANGE-R1"
 public static let issuers: [VeilopolyIssuerPage] = [
  .init("VTL", "维尔交通", "交通", "钢轨上的旧时刻", "从城门到海港，列车与路网把遥远的街区连接成一张细密的地图。"),
  .init("AUR", "极光能源", "能源", "灯塔的长明灯", "发电机房的铜制仪表昼夜运转，城市的灯火都被记进同一本能源账簿。"),
  .init("MNT", "薄荷港湾", "消费", "港口的橱窗", "海风掠过码头商铺，包装精巧的货物在清晨被送往城市各处。"),
  .init("NOV", "新星工坊", "工业", "铸造师的工房", "机械师在长窗下打磨齿轮，旧式工艺与新图纸在这里慢慢相遇。"),
  .init("ORB", "轨道系统", "科技", "仰望星图的人", "观测室里铺开蓝色星图，工程师把远方的想象写成一页页方案。"),
 ]
 public static func issuer(for quote: StockQuote) -> VeilopolyIssuerPage? {
  issuers.first {
   $0.symbol == quote.symbol && $0.canonicalName == quote.name &&
   $0.sector == quote.sector
  }
 }
 public static func regimeNotice(_ market: StockMarketState) -> String {
  switch market.regime {
  case -2: return "行市札记 · 模拟市场气氛明显偏弱，报价仍以本局行情为准。"
  case -1: return "行市札记 · 交易气氛趋于谨慎，价格仍在逐笔演变。"
  case 0: return "行市札记 · 买卖双方暂时相持，市场方向未见一致。"
  case 1: return "行市札记 · 模拟市场气氛偏强，仍需留意价格的变化。"
  case 2: return "行市札记 · 交易热度较高，波动与机会并非同一个概念。"
  default: return "行市札记 · 行情状态暂不可辨，请参考交易所实时报价。"
  }
 }
 public static func quoteNotice(_ quote: StockQuote) -> String {
  if quote.isHalted { return "交易所公告 · 当前暂停交易，能否提交订单以引擎裁定为准。" }
  if quote.sessionVolume == 0 { return "交易所公告 · 本轮暂未记录模拟成交量。" }
  return "交易所公告 · 本轮累计模拟成交量 \(quote.sessionVolume) 股；报价随本局推进。"
 }
}
