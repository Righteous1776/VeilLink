import SwiftUI

struct TacticalSoloGuideView: View {
    static let completionKey = "game.tactical.tutorial.v1.completed"

    private enum Section: String, CaseIterable, Identifiable {
        case tutorial = "新手教程"
        case rules = "完整规则"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var section: Section = .tutorial
    @State private var tutorialPage = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Picker("内容", selection: $section) {
                    ForEach(Section.allCases) { item in Text(item.rawValue).tag(item) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if section == .tutorial { tutorial }
                else { rulebook }
            }
            .padding(.top, 10)
            .background(VeilAmbientBackground())
            .navigationTitle("官渡决战指南")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { complete() }.foregroundColor(VeilTheme.gold)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var tutorial: some View {
        VStack(spacing: 10) {
            TabView(selection: $tutorialPage) {
                tutorialCard(
                    icon: "flag.checkered",
                    eyebrow: "第 1 步 · 你的任务",
                    title: "率曹军赢下官渡",
                    body: "你执曹军并且先行动。夺取地图上的官渡、乌巢和白马来累计胜利点；先到 8 点即可获胜。攻入袁军大营或击溃袁绍中军，也会立刻胜利。",
                    tip: "第一局先把目标放在官渡：它位于中央、每轮价值 2 点。"
                ).tag(0)
                tutorialCard(
                    icon: "hand.tap.fill",
                    eyebrow: "第 2 步 · 下达命令",
                    title: "点部队，再点亮起的格子",
                    body: "每个行动阶段最多下达两道命令。同一支部队在一个阶段只能行动一次。黄色格可机动，敌军所在的可攻击格会显示交战预估；确认后才真正开战。",
                    tip: "不想下第二道命令时可点“结束阶段”，电脑随后连续执行袁军命令。"
                ).tag(1)
                tutorialCard(
                    icon: "shippingbox.fill",
                    eyebrow: "第 3 步 · 保持补给",
                    title: "粮道决定机动力",
                    body: "部队需要能沿可通行格连接到己方大营或己方粮队。失去补给后，本阶段机动力会降到 1，战斗也会受到 −1 修正。切换棋盘上方的“补给”图层可以直接查看粮道。",
                    tip: "粮队很脆弱。让它跟在主力后方，不要单独暴露在骑军冲击范围内。"
                ).tag(2)
                tutorialCard(
                    icon: "shield.lefthalf.filled",
                    eyebrow: "第 4 步 · 看懂战斗",
                    title: "地形、指挥与兵种共同结算",
                    body: "骑军攻击最高且机动 3；步军攻守均衡；远程军能隔 2 格攻击；中军相邻部队获得 +1 指挥支援。林地、丘陵和营地为守方提供 +1 防御。双方再各掷一枚确定性六面骰。",
                    tip: "交战预估展示 36 种骰点组合的受损概率，不会提前泄露本次实际骰点。"
                ).tag(3)
                tutorialCard(
                    icon: "map.fill",
                    eyebrow: "第 5 步 · 争夺目标",
                    title: "整轮结束时计分",
                    body: "只有曹军和袁军都完成行动后，才按照目标格上的实际占领者计分：乌巢 2 点、白马 1 点、官渡 2 点。只在旁边施压不会得分，必须有己方部队站上目标格。",
                    tip: "使用“目标”图层查看双方在关键地区附近的兵力压力。"
                ).tag(4)
                tutorialCard(
                    icon: "sparkles",
                    eyebrow: "第 6 步 · 第一轮建议",
                    title: "稳步建立中央战线",
                    body: "先让一支步军或骑军向官渡推进，再让中军靠近主力提供支援。不要急着让粮队冲锋。袁军由完全离线的 TacticalBot 控制，它会评估目标、兵力、补给、中军安全与大营威胁。",
                    tip: "随时点右上角“？”重看本教程；重开会恢复双方初始部署。"
                ).tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: 10) {
                Button("上一步") { tutorialPage = max(0, tutorialPage - 1) }
                    .buttonStyle(VeilGameSecondaryButtonStyle())
                    .disabled(tutorialPage == 0)
                Button(tutorialPage == 5 ? "开始作战" : "下一步") {
                    if tutorialPage == 5 { complete() }
                    else { tutorialPage += 1 }
                }
                .buttonStyle(VeilGamePrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func tutorialCard(icon: String, eyebrow: String, title: String, body: String, tip: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(VeilTheme.gold)
                Text(eyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(VeilTheme.mutedGold)
                Text(title).font(.title2.bold()).foregroundColor(VeilTheme.text)
                Text(body).font(.body).foregroundColor(VeilTheme.text).fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "lightbulb.fill").foregroundColor(VeilTheme.gold)
                    Text(tip).font(.subheadline).foregroundColor(VeilTheme.secondaryText)
                }
                .padding(12)
                .background(VeilTheme.gold.opacity(0.08))
                .clipShape(VeilPanelShape(cut: 9, radius: 6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .veilCard(emphasized: true)
        .padding(.horizontal, 16)
    }

    private var rulebook: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                rules("胜利条件", icon: "trophy.fill", rows: [
                    "累计 8 胜利点；或占领敌方大营；或消灭敌方中军。",
                    "第 8 轮结束仍无人即时获胜时，胜利点较高者获胜；同分为和局。"
                ])
                rules("回合与命令", icon: "arrow.triangle.2.circlepath", rows: [
                    "每轮先由曹军行动，再由袁军行动；每方阶段有 2 道命令。",
                    "每支存活部队每阶段最多行动一次。机动、攻击均消耗一道命令，也可提前结束阶段。",
                    "袁军阶段结束后结算目标分，并进入下一轮。"
                ])
                rules("部队", icon: "person.3.fill", rows: [
                    "中军：攻 3、防 4、机动 2；为自身相邻 1 格内友军提供 +1 指挥支援。",
                    "步军：攻 3、防 3、机动 2；正面战线的稳定主力。",
                    "骑军：攻 4、防 3、机动 3；适合抢点、包抄与打击粮队。",
                    "远程：攻 2、防 2、机动 2、射程 2；无需进入敌军格即可攻击。",
                    "粮队：攻防各 1、机动 1、仅 1 步；本身始终是补给源。其余部队和中军通常有 2 步。"
                ])
                rules("地图与机动", icon: "map", rows: [
                    "平原、驿道、渡口、营地消耗 1 机动力；林地、丘陵消耗 2；河道不可进入。",
                    "不能穿过或停在其他存活部队占据的格子；攻击则选择射程内的敌军格。",
                    "失去补给的部队机动力降至 1。"
                ])
                rules("补给与战斗", icon: "shield.fill", rows: [
                    "补给从己方大营或存活粮队出发，沿可通行且未被敌军占据的格子连接到部队。断粮使战斗值 −1。",
                    "攻击分＝兵种攻击＋d6＋补给修正＋指挥支援；防御分＝兵种防御＋d6＋补给修正＋地形＋指挥支援。",
                    "攻击高 1–2：守军损失 1 步；高至少 3：守军损失 2 步。防御反高至少 3：攻击方损失 1 步；其余为僵持。",
                    "骰值由对局编号、命令序号和参战单位确定，同一局面可离线重算。"
                ])
                rules("目标与界面", icon: "scope", rows: [
                    "乌巢 2 点、白马 1 点、官渡 2 点；必须在袁军阶段结束时实际占领才得分。",
                    "“战场”显示标准棋盘；“补给”显示粮道；“威胁”显示敌我攻击覆盖；“目标”显示目标附近兵力压力。",
                    "选中攻击目标后先看交战预估，再点确认；预估来自全部 36 种 d6 对掷组合。"
                ])
            }
            .padding(16)
        }
    }

    private func rules(_ title: String, icon: String, rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline).foregroundColor(VeilTheme.goldBright)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 9) {
                    Circle().fill(VeilTheme.gold).frame(width: 5, height: 5).padding(.top, 7)
                    Text(row).font(.subheadline).foregroundColor(VeilTheme.text).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .veilCard()
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: Self.completionKey)
        dismiss()
    }
}
