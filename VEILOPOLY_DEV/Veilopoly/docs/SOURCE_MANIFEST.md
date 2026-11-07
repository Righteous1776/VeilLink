# MANIFEST · Veilopoly 策划与素材包 v1（2026-11-06）

## 内容
```
docs/
  GAME_DESIGN.md      游戏设计：40格棋盘、回合阶段机、拍卖/交易/抵押/坐牢/破产规则、三档AI、VeilLink治理边界
  MODELING_SPEC.md    解析建模：G/ctx/move纯函数引擎、15种move清单、拍卖与交易状态机、卡牌Effect模型、
                      房主权威+事件溯源+哈希校验联机协议、seeded RNG确定性、AI决策伪代码、验收基线
  RENDERING_SPEC.md   2.5D渲染：12-15°倾角场景层级L0-L7、素材映射表、动画时间轴（骰子1.2s/走子150ms每格）、
                      ViewCommand解耦协议、性能预算、音效映射表
assets/
  boardgame-pack/         490项（棋子/骰子/卡牌/筹码，PNG+SVG+精灵表）
  board-game-icons/       250项 UI 图标
  casino-audio/           54个音效
  ui-audio/               55个音效
  LICENSES.md             许可清单（全CC0）
assets-src/             四个原始zip（溯源用，可删除）
```

## 分工
- 我（Kimi）：解析建模 + 动画渲染规格 + 素材收集 ✅ 已交付
- ChatGPT：按 MODELING_SPEC/RENDERING_SPEC 编写 Swift 实现

## 治理状态
- 未触碰 VeilLink 产品树；代码落地需 owner 授权（基线月「不新增功能」决策未解除），
  落地时走 INBOX_ONLY 五件套，锚点 main HEAD `ccafebab`，保护 Protocol 4 / VLGM1 v1 / SQLite Schema V8。

## 校验
- 素材 SHA256 与源站一致（下载自 kenney.nl 签名链接，经 tree 清点 1470 文件）
- zip 自解压校验：PASS
