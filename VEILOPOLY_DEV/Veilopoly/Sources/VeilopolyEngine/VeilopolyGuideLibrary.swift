import Foundation

/// Owner-approved editorial implementation for the current provisional game.
/// It is intentionally NOT encoded in GameState, replay, market, networking or saves.
public enum VeilopolyGuideChapter: String, CaseIterable {
 case start, property, economy, safety
 public var title: String {
  switch self {
  case .start: return "起步与回合"
  case .property: return "城市产权"
  case .economy: return "银号与证券"
  case .safety: return "清算与续局"
  }
 }
}
public struct VeilopolyGuideTopic: Equatable, Identifiable {
 public let id: String
 public let chapter: VeilopolyGuideChapter
 public let title: String
 public let subtitle: String
 public let detail: String
 public let footnote: String
 public init(id: String, chapter: VeilopolyGuideChapter,
             title: String, subtitle: String, detail: String, footnote: String) {
  self.id=id; self.chapter=chapter; self.title=title
  self.subtitle=subtitle; self.detail=detail; self.footnote=footnote
 }
}

/// Single source of truth for in-app player help, including what's provisional.
public enum VeilopolyGuideLibrary {
 public static let edition = "VEILOPOLY-IVORY-GUIDE-R1"
 public static let minimumIOSMajorVersion = 15
 public static let topics: [VeilopolyGuideTopic] = [
  .init(id: "welcome", chapter: .start, title: "城市邀请函",
        subtitle: "从同一张棋盘开始",
        detail: "本局使用40格棋盘、4个席位。默认1名本地玩家，其余席位由电脑操作；每位玩家初始持有¥1500。",
        footnote: "这是一款原创、离线优先的桌游研发版。棋盘、卡牌与金融数值仍有待正式规则裁定，不代表现成实体桌游的全部规则。"),
  .init(id: "turn", chapter: .start, title: "如何完成一回合",
        subtitle: "掷骰、落点、结算、管理",
        detail: "轮到你的掷骰阶段，点击「掷骰子」。棋子移动与地块效果结算完成后，可在「资产管理」阶段处理地产、银行、股市或交易，再点击「结束回合」。",
        footnote: "经过起点会根据当前经典规则领取¥200；恰好停在起点也使用同一规则。点击棋盘格可查看详情，但不会代替正式的买卖操作。"),
  .init(id: "doubles", chapter: .start, title: "连续双骰",
        subtitle: "一次额外回合，或一份司法传票",
        detail: "非监狱状态掷出相同点数时，按现行规则可能获得额外回合；连续第三次掷出相同点数则直接入狱。",
        footnote: "在监狱中掷出双骰可以获释，但不会因此再获得额外回合。实际执行由游戏引擎裁定。"),
  .init(id: "jail", chapter: .start, title: "出狱手续",
        subtitle: "掷骰、保释与出狱卡",
        detail: "在监狱中可以尝试按规则掷骰、支付¥50保释，或使用持有的机会／命运出狱卡。出狱卡数量与来源会随游戏状态改变。",
        footnote: "第三次未掷出双骰时会按照当前规则处理强制保释；现金不足可能进入债务流程。"),
  .init(id: "chance", chapter: .start, title: "机会与命运",
        subtitle: "读完信件再继续",
        detail: "棋盘上的「机会」和「命运」使用各自的卡组。正式显示由独立标题、简短故事和「执行结果」组成；具体现金与移动效果以抽中的卡牌为准。",
        footnote: "目前各16张卡为临时引擎牌池，规则所有者尚未批准最终经济效果。关闭卡面后才继续后续视觉事件。"),
  .init(id: "tiles", chapter: .property, title: "地块与归属",
        subtitle: "先看登记簿，再决定落子",
        detail: "选中棋盘格会显示名称、当前所有者及城市札记。可购买的地块包括街区、铁路和公共事业；特殊格不能作为普通产权购买。",
        footnote: "无主产权需要在正式落点决策阶段购买或拍卖。单纯点选地块不会扣款，不会改变所有权。"),
  .init(id: "auction", chapter: .property, title: "城市公开竞价",
        subtitle: "出价高于当前价，交割以落槌为准",
        detail: "地产进入拍卖后，按当前竞价顺序轮流出价或退出。出价必须是高于当前最高价的正整数，并且不能超过自己当前现金。",
        footnote: "拍卖公告只是实时竞价记录；只有引擎发出成交效果，才会扣除成交价并登记新的所有者。当前研发版未设置竞拍倒计时。"),
  .init(id: "build", chapter: .property, title: "房屋与旅馆",
        subtitle: "集齐颜色，均衡建设",
        detail: "在当前规则中，需要拥有同一颜色的全部街区，且没有抵押，才能均衡建造。每栋房屋需支付该地块对应的建筑成本。",
        footnote: "当前经典建设规则是4栋房屋后可升级1座旅馆，银行库存为32栋房屋与12座旅馆。摄影参考中的2栋房屋方案尚未作为本模式生效。"),
  .init(id: "sell", chapter: .property, title: "出售建筑",
        subtitle: "撤建也要遵守组内均衡",
        detail: "出售建筑时会依现行规则检查同色组楼层，不能任意从较低等级的街区撤建。卖回银行通常按建设成本的一半取得现金。",
        footnote: "旅馆降级需要足够的银行房屋库存。所有可执行性都以实际操作按钮与规则引擎为准。"),
  .init(id: "mortgage", chapter: .property, title: "抵押与赎回",
        subtitle: "一份典当契据，不是出售地产",
        detail: "产权抵押后，产权仍归原持有人，但抵押期间不收取租金。当前规则一般以标价的一半发放抵押资金，赎回时需支付本金及按规则计算的费用。",
        footnote: "对于同色街区，需要先处理建筑后才能抵押；具体数字请以所选产权与系统结算为准。"),
  .init(id: "rail", chapter: .property, title: "铁路与公共事业",
        subtitle: "不同的账册，不同的租金",
        detail: "铁路租金随同一持有人拥有的铁路数量变化。公共事业租金根据掷骰点数及持有数量计算，机会卡有时会要求特殊倍率。",
        footnote: "它们不是普通街区：不建造房屋与旅馆。具体租金由当前落点、骰子和牌面效果共同决定。"),
  .init(id: "trade", chapter: .property, title: "产权交换协议",
        subtitle: "接受前，核对双边交易条件",
        detail: "交易可以包含双方现金、允许交换的产权以及所持出狱卡。正式确认后才进行产权和现金划转；待确认的合同不是成交证明。",
        footnote: "「还价」会交换双方在谈判中的角色。交易面板会显示真实两方的报价，不应依赖过期截图。"),
  .init(id: "finance", chapter: .economy, title: "同一个钱包",
        subtitle: "地产、银行与股市共用现金",
        detail: "玩家的可用现金由同一份对局状态维护。购买地产、付租、借贷、存款和股票交易均围绕该余额执行，没有独立的虚构货币钱包。",
        footnote: "存款本金、投资本金、贷款应偿与股票市值在文书中分列展示；它们不能简单相加当成可立即花费的现金。"),
  .init(id: "deposit", chapter: .economy, title: "银号存款",
        subtitle: "存根与当前可取回条件",
        detail: "存款会从当前现金划出，在银行账本中登记。活期与定期存款的取回和收益条件以本局已批准的规则配置为准。",
        footnote: "当前测试配置中，未确认的定期利率和期限不会自动被编造；缺少必要条款时操作将明确拒绝。"),
  .init(id: "loan", chapter: .economy, title: "贷款与还款",
        subtitle: "偿债期限属于游戏回合",
        detail: "贷款具有本金、利率、到期期数和待偿总额。真实生效的条件会记录在本局账本中，而不是由界面的文字另行决定。",
        footnote: "银行期数在普通玩家回合结束后推进；额外掷骰本身不构成另一个金融结算期。"),
  .init(id: "investment", chapter: .economy, title: "投资与到期",
        subtitle: "未批准的收益不得显示为保证利润",
        detail: "投资产品可能有锁定期与结算规则，但当前资料中仍有收益表未完成裁决的条目。界面必须按实际允许的产品和条款显示可用状态。",
        footnote: "若引擎尚未启用某项产品，文案不会承诺固定收益，也不会伪造到账记录。"),
  .init(id: "market", chapter: .economy, title: "虚构证券交易所",
        subtitle: "五家模拟公司，共用一份市场账本",
        detail: "VTL、AUR、MNT、NOV、ORB 为本局虚构证券。每次全新对局会生成独立随机种子；新版股票行情采用不固定时点的市场状态变化，不连接真实证券市场。",
        footnote: "交易按模拟即时报价及股数执行，手续费与现金变化由引擎计算。行情曲线是游戏状态记录，不是现实行情或投资建议。"),
  .init(id: "ticker", chapter: .economy, title: "股票行情与停牌",
        subtitle: "先核对股数、手续费和可用余额",
        detail: "证券终端展示买入／卖出预估、持股数量、成本与浮动盈亏。订单被拒绝时不会改变游戏状态；停牌状态不应继续提交成交承诺。",
        footnote: "最近成交回执会随当前对局存档保存，旧版本未保存的历史回执不会凭空恢复。"),
  .init(id: "debt", chapter: .safety, title: "债务清算通知",
        subtitle: "待偿余额不等于已宣告破产",
        detail: "现金不足时，引擎会依据规则尝试处置可用资产；如仍有待付款，将进入清算阶段，由玩家确认后执行破产处理。",
        footnote: "「债务清算通知」应列出实际待偿金额与债权人，不能在玩家尚未破产时写成已经破产。"),
  .init(id: "victory", chapter: .safety, title: "终局结算",
        subtitle: "胜负以破产淘汰结果为准",
        detail: "当前模式在只剩一位未破产玩家时判定胜者。结算公报显示胜者、资金、产权及行动编号，净资产排名属于额外账面信息。",
        footnote: "目前没有正式启用固定60／90分钟胜利规则，也不以股票收益单独决定胜者。"),
  .init(id: "autosave", chapter: .safety, title: "离线续局",
        subtitle: "关键操作提交后自动存档",
        detail: "本地单机对局通过双槽存档恢复最近经过校验的游戏状态。离开界面会请求写入；股票行情的高频时间步按间隔合并保存。",
        footnote: "突然断电下仍可能失去尚未落盘的最新股票时间步。请勿删除应用数据；损坏存档会保留供诊断，不会被静默覆盖。"),
  .init(id: "multiplayer", chapter: .safety, title: "联机与同步",
        subtitle: "保留研发接口，不冒充已经上线",
        detail: "项目已存在联机恢复协议与主客端状态同步抽象，但真实 VeilLink 双设备传输仍属于待集成研发阶段。",
        footnote: "当前可以确认的自动续局是单机模式；尚未实现的两机重连不会显示为已保障的功能。"),
  .init(id: "access", chapter: .safety, title: "屏幕、操控与辅助功能",
        subtitle: "大棋盘与细节面板属于同一个界面",
        detail: "建议横屏使用。棋盘触摸用于选中地块，正式买卖由浮动操作面板执行；机会／命运弹窗需要阅读并确认后继续。",
        footnote: "iOS 15 是当前 Veilopoly 最低部署目标，但完整 Xcode 编译与 iPhone 7 真机性能仍待验收。"),
 ]
 public static func topics(in chapter: VeilopolyGuideChapter) -> [VeilopolyGuideTopic] {
  topics.filter { $0.chapter == chapter }
 }
 public static func filtered(_ query: String) -> [VeilopolyGuideTopic] {
  let phrase=query.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !phrase.isEmpty else { return topics }
  return topics.filter {
   [$0.title, $0.subtitle, $0.detail, $0.footnote].contains {
    $0.localizedCaseInsensitiveContains(phrase)
   }
  }
 }
 /// Dynamic help heading is derived from the state actually being played.
 public static func status(_ state: GameState) -> String {
  guard state.players.indices.contains(state.turn.player) else {
   return "状态不可用 · 请核对对局数据"
  }
  let who=state.players[state.turn.player].name
  if let winner=state.winner, state.players.indices.contains(winner) {
   return "本局已结束 · 胜者：\(state.players[winner].name)"
  }
  return "当前回合 · \(who) · 第\(state.nextSeq)步"
 }
}
