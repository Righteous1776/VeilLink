# ASTRA-FX-02 · SpriteKit 特效时序只读审计

优先级：P1，Astra 额度够再执行。仓库 `Righteous1776/VeilLink`；分支 `dev/veilopoly`；目录 `VEILOPOLY_DEV/Veilopoly/`。

**只读 4 个文件**：`Sources/VeilopolyUI/BoardScene.swift`、`RenderCommands.swift`、`RenderCommandAckGate.swift`、`VeilopolyTokenFormation.swift`。检查骰子 1.2 秒、走子每格 150ms、现金浮字、购地建造扩散环、回合横幅、快速跳过和 Reduce Motion。寻找 ACK 重复/丢失、旧节点残留、棋子偏移、纹理/声音重复加载和视觉卡顿的具体程序风险；将 Effect→ViewCommand→ACK 结束状态列明。

交付仅 `ASTRA_FX_02_REPORT.md`：最多 5 个具有代码证据的缺陷，2 条优先的最小补丁思路，简短事件/ACK 对照表，最多 6 项交给 Kimi 的素材/动画接口要求。没有新美术、没有 Swift 引擎/规则变动。

Plus 额度纪律：只读指定 4 文件，输出≤1000中文字；不跑全量测试、不读取全库、不修改任何 GitHub 分支、不生成大图。不把静态审查说成 iOS 实测。Owner 交报告给 ChatGPT 后由 ChatGPT 统一修复。
