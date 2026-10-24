# 第三方开源资源集成候选 / 许可证核验表

**R1 当前状态：只评估、登记候选依赖；没有复制第三方受版权保护的源码、没有拉取开源 ZIP、没有把第三方库加到 `project.yml`。**

取得源码不等于取得素材包、数据库内容、品牌及商标的再授权。实际集成必须固定 commit/tag、保存许可证和 attribution、审计传递依赖、通过 iOS15 构建与真实设备测试。

| 项目 | GitHub 地址 | 许可 | 建议用途 | 集成风险与门禁 |
|---|---|---|---|---|
| GRDB.swift | https://github.com/groue/GRDB.swift | MIT | SQLite 查询/FTS5/离线索引 | latest v7.11.1 requires Swift 6.1; not compatible with project Swift 5.9. Validate a supported 6.x line first; do not replace SQLite v10 store. |
| MapLibre Native | https://github.com/maplibre/maplibre-native | BSD-2-Clause + bundled notices | 离线地图/多地点底图 | No bundled tiles; multiple third-party notices; heavy for iPhone7; offline data license separately. |
| Godot Engine | https://github.com/godotengine/godot | MIT | 独立 2D/3D 游戏渲染 | High binary/build integration cost; needs license notice and isolated game target; do not insert raw engine into Core blindly. |
| Lottie iOS | https://github.com/airbnb/lottie-ios | Apache-2.0 | 矢量动效、欢迎页动画 | Podspec iOS 13, Swift 5.9; iPhone7 reduce-motion and thermal fallback required. |
| DGCharts | https://github.com/ChartsOrg/Charts | Apache-2.0 | 多轴图表/遥测可视化 | Podspec iOS12, Swift5.7; verify current release with XcodeGen and accessibility. |
| ZXing-C++ | https://github.com/zxing-cpp/zxing-cpp | Apache-2.0 | 复杂二维码/条码校验 | C++20 compiler and ObjC++/Swift integration; iOS12+ podspec, bridge and permissions need validation. |
| CodeScanner | https://github.com/twostraws/CodeScanner | MIT | SwiftUI 相机二维码扫描 | Camera permission and offline-only processing; avoid duplicating existing QR tool; check version deployment first. |
| Swift Collections | https://github.com/apple/swift-collections | Apache-2.0 WITH Swift-exception | 高效率 Deque/优先队列 | Repository main uses Swift 6.4; pin an older compatible tag after compiling Swift 5.9. |
| Swift Algorithms | https://github.com/apple/swift-algorithms | Apache-2.0 WITH Swift-exception | 序列组合、窗口、组合搜索 | Pin compatible release and test memory/bounds; latest repo may require newer tools. |
| SnapshotTesting | https://github.com/pointfreeco/swift-snapshot-testing | MIT | iPhone 7 UI快照与主题回归测试 | Test target only, do not ship in app; use exact same simulator images for baselines. |
| ZIPFoundation | https://github.com/weichsel/ZIPFoundation | MIT | 现有 ZIP 备份读写/检查 | Already dependency in VeilLink; DO NOT refactor protected backup/key contracts in this feature batch. |

## 依赖集成硬门

1. 只有 Governor 可以批准依赖变更与 `project.yml` 写入，不允许 Inbox-only agent 越权修改产品。
2. 供应链冻结：记录明确仓库、release/tag、commit SHA、下载域、许可证、NOTICE 和 checksum，不允许 floating branch 构建生产包。
3. SQLite v10、Wire v4、Keychain、签名/Entitlements、A9/A10 及备份迁移不允许因第三方库导入而改变。
4. 测试 iOS15 Swift5.9，尤其 iPhone7 RAM/CPU/电量；不能用最新版工具链支持来推定项目当前可用。
5. 任何下载的地图数据、游戏模型/音乐/贴图均有独立许可；未经验证不能直接复制导入。
6. 安全敏感能力（加密、签署、认证、重放防护）不得拿实验运算器替代现有加密协议。
7. Attribution 要求落实到随包 THIRD_PARTY_NOTICES 与项目仓库，包含二级及传递依赖。
