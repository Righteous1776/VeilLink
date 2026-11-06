# Veilopoly · Astra ART B01 v1.1

交付：Astra B01 视觉资产。状态：VALIDATED_LOCAL / 待游戏接入。Owner 最新指令“你直接写到对应的库的对应位置”授权将本批素材落入 `dev/veilopoly:VEILOPOLY_DEV/INCOMING_ASSETS/ASTRA_B01_v1_1/`，取代本任务先前的仅聊天交付限制。具体入库边界见 `INTAKE.md`；远端提交状态以 Git 回读为准。v1 原包在本地原样保留。

## 已制作

- 保留并修订 v1 的 UI 资产体系，每个运行素材均提供可编辑 SVG 与 PNG：28 图标、8 按钮状态、面板/材质/暗化层、四类玩家 HUD、六类反馈、卡牌正面、金融周期组件、五类操作装饰、四类输入框、四类徽章及两类金融模板。
- 本版合计 91 个资源别名：90 个运行资源 + 1 个胶囊外观参考；均配 SVG 与 PNG。保留 v1 的 70 个别名，其中五种 phase 装饰横条改为纸质风格；新增 21 个资源：8 色地产证、4 色空白积分票券、竞价票券、双方交易凭证、结算证书、纸纤维纹理、5 张紧凑操作主卡。准确逐项尺寸以 `ASSET_MANIFEST.json` 为准；实际校验结果见 `VALIDATION.md`。
- 1 个双按钮胶囊外观样张（SVG+PNG）；reference_only，继续使用现有程序按钮。
- BUY / AUCTION / TRADE / BANK / SETTLEMENT，分别提供 844×390pt、852×393pt、1180×820pt 的整屏 SVG 与 @2x PNG：共 15 屏。
- 5 份 360×640pt 可编辑操作栏源稿，保留 SVG 文本层。
- 组件总览、离线 HTML 浏览器、设计 Token、逐素材清单、坐标/锚点/9-slice 参数、生成脚本及完整性验证脚本。

## 交付边界

相对 K1：上述 Astra UI 均为 NEW；没有覆盖任何 K1 别名。UNCHANGED_K1：棋盘、地块、棋子、骰子、建筑、卡背、音频全部保留，包中不重复分发。相对 B01 v1 的变化见 `REFERENCE_DELTA.md`；K1_delta 与 B01 版本差异不是同一含义。

预览左侧是低细节场景定位线框，用于标明棋盘可用区域；不是 Kimi 最终棋盘、不是待导入的棋盘美术。线框及 KIMI 字样不在运行资源中。最终效果需 ChatGPT 将这些皮肤与 Kimi 场景组合验收。

PENDING：ChatGPT 游戏接线、Apple SDK 命中/字体/安全区验证、动态文字与真实规则绑定、Kimi 场景组合验收。B02 序列帧、动画图集本次未制作。静态加载图标可由程序旋转，不宣称已提供动画。

## 使用

先看 `README.md`，打开 `index.html` 看 15 屏与组件；再读 `sources/INTEGRATION.md`。只从 `ui/` 导入运行资产，`previews/` 不可整屏贴入游戏。动态金额、姓名、卡牌正文不烘焙到运行纹理；预览只使用破折号占位。资源清单中 `text_slots` 是局部 pt 坐标。

银行只是不可兑换的游戏积分。收益、利率和规则未批准前保留“规则待定”禁用态，不填假收益或保证回报。运行时规则状态由引擎负责。

## 来源

Owner 提供的纸币、传统地产桌游棋盘、微缩城市图片用于视觉方向：奶油纸底、雕刻线纹、地产分组色带、实体桌游的信息层级。所有交付图形仍为原创新建 SVG 路径/几何与纹理；不复制参考图品牌字标、吉祥物、角色，也不打包参考原图或第三方字体。城市仅提供气质参考，不生产城市、建筑或棋盘模型，避免与 Kimi 重复。Owner 可使用、修改、分发本交付原创资产。预览使用环境中的 Noto Sans CJK SC；应用推荐系统 SF Pro/PingFang SC。具体来源和 SHA 在 ASSET_MANIFEST.json；完整包内文件表见 FILE_INDEX.json。

仅阅读指定任务及三个关联文档、UI.swift 布局部分。参考分支 `dev/veilopoly`，SHA `3a0973bb1bdf839f019ccf46f6d62c7b45796058`。不包含任何 VeilLink bugfix 或其他项目工作。
