# B01 v1.1 资产接入说明

本包是完整参考修订版，不与 v1 同目录混用。同一 astra 别名可能保留但图形内容更新，按当前 manifest 哈希重新导入。K1 原有别名和素材未改变；不要批量覆盖 K1 目录。

新增纸质凭证、地产分组与空白票券保持无文字运行纹理。票券颜色不是固定面额，地产色带不是固定规则映射；绑定关系来自实际游戏数据。若资源 `resize_mode` 为 `aspect_fit`，保持纵横比，不九宫格拉伸复杂雕刻花纹；只有明确带 `cap_insets` 的皮肤可做九宫格。新纸质组件上的动态文字使用深色文本，与原深蓝组件的浅色文本区分，具体样式以预览和设计 Token 为准。

## v1.1 紧凑主卡与新增资源

`astra.hero.buy`、`.auction`、`.trade`、`.bank`、`.settlement` 是 256×174pt 的五张紧凑主卡（PNG 512×348px），对应右侧操作面板。它们是无文字皮肤，金额、姓名、状态标签都要单独覆盖；本包 `hero_preview()` 中的中文仅在预览层，不会随运行皮肤进入游戏。`text_slots` 是皮肤局部坐标，整体等比缩放时，字体位置与槽尺寸使用同一个变换。

纸面文字用 `PRINT #314C57`，浅色文字 `INK #EAF0F2` 仅用于深蓝面板以及 `hero.bank` 下部的存款/贷款小面板。不可对所有 hero 一律套用浅色文本。语义标签应来自应用本地化，不从背景位图 OCR 或硬编码预览文案。

`hero.auction` 的加减图形已包含在主卡皮肤中，程序需叠加真实按钮与无障碍标签：源坐标分别为 `[12,118,44,44]` 与 `[200,118,44,44]`；金额输入位于 `[62,118,132,44]`。整个主卡不可作为单一不可交互图片；触控区域不能小于 44pt，缩小主卡时须由宿主重排或扩展命中框，不同时叠加重复的加减图标。

额外详情资源：`astra.deed.*` 八种分组色带；`astra.voucher.*` 四色积分票券；`astra.auction.ticket` 竞价摘要；`astra.trade.offer` 双方交换摘要；`astra.settlement.certificate` 结算详情；`astra.texture.paper` 纸纤维层。这些资源不是 K1 卡背或棋盘的替代品。票券不含固定面额；分组颜色不是玩家身份或输赢的唯一提示，程序仍需配名称、图标与状态文案。

所有详细票券、地产证、证书和 hero 均使用 aspectFit，保持刻线与圆徽比例。完整地产证 288×360pt 不应直接塞入 390pt 高横屏的右侧主栏；主栏使用 hero，完整卡仅用于有滚动/缩放策略的详情查看。只对 manifest 显式列出 cap_insets 的普通面板/按钮做九宫格拉伸。

## 图层与尺寸

所有 SVG 均带明确 width / height / viewBox。运行素材 SVG 没有 text 标签，PNG 保留真实 alpha；纹理填充和 modal-scrim 属于有意覆盖矩形的例外。图标 32pt，PNG @3x=96px；其他皮肤大部分 @2x。实际值以 ASSET_MANIFEST.json 为准。

图层：宿主背景 z=0 → Kimi board z=1 → UI panels z=20 → 字体/按钮 z=30 → modal scrim z=100 → card panel z=110 → card text/close z=120。不将装饰线条设为触控对象。模态显示时由程序明确拦截底层操作。

资源坐标为左上原点 pt。SpriteKit 若使用顶左锚点，anchorPoint=(0,1)，位置 Y=sceneHeight-y；比例由实际屏幕决定。别名禁止覆盖 pawnBlue/die1/cardChance 等 K1 名称。所有新别名以 astra. 开头。

## 伸缩

cap_insets 数组顺序固定 [top,left,bottom,right]；pt 与 px 均已给出。SwiftUI 使用 .resizable(capInsets: ..., resizingMode: .stretch)。SpriteKit centerRect=(left/W,bottom/H,(W-left-right)/W,(H-top-bottom)/H)，先换到原点左下的纹理坐标。不直接把 pt 当 UV。

带徽记的皮肤固定左侧 cap；不要把图标一起横向拉伸。低于 top+bottom+1 或 left+right+1 的尺寸不可伸缩。独立图标保持 aspectFit，建议显示 20–24pt，触控容器至少44×44pt。brushed-metal 是64pt可平铺纹理，resize mode 应由集成设为 tile；如需在很大面板维持微纹理节距，用独立纹理层叠加面板，不拉伸纹理。

带内嵌图标的旧版皮肤限制为保持原始高度、只横向伸缩：buttons、player HUD、feedback、period、input、badges、finance-product。它们的图标可能跨过九宫格中间行，纵向拉伸会使图标变形；不要把有 cap_insets 误解为任意二维伸缩许可。需要其他高度时，以 SVG 重新排版，或使用无图标面板背景 + 独立图标覆盖层；不要非等比拉伸整个控件。reference_only 胶囊保持 44pt 高。

## 横屏适配

SPRITE_MAP.json 中 layouts 含15屏 board_viewport、right_panel、scroll_clip、fixed_footer、capsule、HUD 与数据槽。数值是参考画布布局，宿主应读取真实 safeAreaInsets：iPhone 参考左右44pt、底部22pt，iPad左右24pt。左右安全区不对称时分别使用真实值。

iPhone操作栏宽288pt，iPad400pt；左侧场景保持完整 fit，不裁棋盘，不随操作栏滚动。棋盘矩形中的线框只是接入标识。动态字号放大时只增加右侧内容高度并允许滚动，固定底部操作条保留；不缩小确认按钮以塞入长文本。标题22pt，主操作14pt，标签12pt，辅助11pt；预览中8–10pt英文品牌眉题仅装饰，生产可隐藏。金额使用 tabular/monospaced 数字。

双胶囊93×44pt，两个46×44pt命中区，1pt分隔线。只参考外观，沿用现有更多/退出与确认逻辑。右侧圆点环不是新功能。

## 动态字段 / 状态合同

BUY：property.name、price、cashAfter、baseRent；按钮 buy/auction。资产集合：action panel + buy ornament + input（按需）+ primary/secondary。

AUCTION：property.name、currentBid、leadingPlayer、bidInput、error；使用 input-focused 编辑金额。加减控件若接入，icon-plus/minus 放入至少44pt的 secondary 背景；金额和递增步长必须来自规则，不在美术里固定。

TRADE：counterparty、offeredProperties、offeredCash、requestedProperties、requestedCash、confirmation；每方资产列表用 inset 和 owned/mortgaged 徽章，独立行选择；不得从美术预览推导自动同意规则。

BANK：wallet、deposit、loanOrdinal、collateral、duration、totalDue、maturity。loan-quote的动态栏由程序堆叠；finance-product共用一个模板，绑定托管/创投/股票三类，期间/收益在批准前显示 — 和 draft 锁定徽章。本包不包含充值、提款、现实兑换或保证回报设计。

SETTLEMENT：winner、netWorth、cash、propertyCount、ranking。winner 徽章区别普通状态，其他玩家排列用 inset，不依赖单一颜色。所有数值由引擎输出。

四类玩家卡：normal / current / jailed / bankrupt；status文字和图标与颜色同时变化，当前位置与监狱剩余回合组合为程序文本。当前回合使用 turn 图标与上沿金线。不要把四张样张的状态固定到四名特定玩家。

按钮 normal/pressed/disabled/loading：每种都有独立纹理，loading和disabled内含图标，因此 label 避开左44pt；禁用还必须同步 disabled/VoiceOver 状态。加载可以静态显示或由程序旋转pending图标，减少动态效果时禁止旋转。pressed不得靠缩小命中框表达。

## 卡牌与反馈

modal-scrim覆盖场景；card-face放在中央，正文单独排版。手机可用卡宽 min(280, availableWidth-32)，高度 min(360, availableHeight-32)，超长正文滚动，确认固定在内容之外。不要把280×360模板强行塞进390pt横屏的安全区；保留模板顶部88pt与下缘26pt，中部按9-slice压缩，文本高度重算。

feedback-positive/negative 只带 +/−，金额由程序渲染；confirmed/check、error/triangle、loading/clock、empty/info分别配文字，不仅依赖颜色。反馈条非按钮；朗读后不抢用户焦点。

## 横屏键盘

金额编辑使用右侧独立ScrollView。键盘出现时以keyboardLayoutGuide的实际顶部为操作区底界，确认/取消条置于键盘上方44pt高的固定附件栏，编辑行滚动到可见。键盘确实占据屏幕时不可承诺底部原坐标仍可点击；恢复高度后回到SPRITE_MAP固定条位置。不要把按钮藏在仅有numberPad的键盘后面。编辑期间保留胶囊与原始值，取消恢复值。iPad浮动键盘按实际遮挡矩形处理，不凭固定键盘高度移动整个棋盘。

## 编辑与再导出

SVG可用 Figma/Illustrator/Inkscape 导入编辑；渐变、路径和文本均为标准 SVG，无外链位图。sources/screens 是可编辑视觉组合稿；运行皮肤均在 ui/。sources/build_assets.py 使用 Python3、Pillow、Inkscape 生成原始批次；会覆盖本包生成素材，编辑SVG后不要运行重建脚本，除非改动也同步入脚本。sources/package_and_verify.py 只验证、生成完整清单并打ZIP。
