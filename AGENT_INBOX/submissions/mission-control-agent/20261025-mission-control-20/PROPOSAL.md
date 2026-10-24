# 20 new capabilities — real code packaged, design contract in GitHub

# VeilLink Mission Control — 20 功能契约（R1）

**注意：本 PR 只投递功能契约，完整候选源码以交付给仓库 Owner 的独立 ZIP 包为准。本提交不能直接让 App 获得这些能力。**

主分支基线：`501ef814a0a9bea41419fe2d9f48315371b30320`
源码包文件名：`VeilLink_MissionControl_20Features_R1_20261025.zip`
SHA-256：`61b4bb8cdb6070b2d5c47100bff9a0f3c1ebba67471b57db6174e62aa6250a3d`

设计边界：iOS 15+；Foundation 离线引擎 + SwiftUI 工具页面 + XCTest；零网络/密钥/数据库写入；数据仅手动输入，不表示真实 BLE 在线能力。

- 01 BLE 信号体检：RSSI 平均、标准差、弱信号比例、综合参考分
- 02 干扰突变雷达：快速 RSSI 突降与连续弱链路样本检测
- 03 可信多跳路径规划：有限跳数图搜索，排除不可信候选边
- 04 多链路候选比较：按带宽、丢包和延迟模型排序
- 05 传输耗时估计：以吞吐、数据量、丢包估算理论上下界
- 06 断点缺块图：计算已确认/缺失块，压缩缺块区间
- 07 BLE MTU 载荷预算：ATT 通知载荷理论上限计算
- 08 UTF-8 安全分段：按字节上限不拆 Unicode 扩展字素簇
- 09 重试退避模拟：封顶指数退避步骤规划
- 10 协议能力位解码：Wire v4 ACK/控制/控制回执与未知位
- 11 临时凭据到期校验：ISO8601 期限对比（不验证签名）
- 12 备份清单预检：路径穿越、重复、大小和摘要格式风险
- 13 附件魔数识别：通过十六进制文件头识别 PNG/JPEG/ZIP/PDF 等
- 14 分享前脱敏预览：本地掩码常见邮箱、手机号与凭据赋值
- 15 离线批量检索：手动输入语句的关键词查询
- 16 待办指令提炼：提取 TODO/待办/记得/截止等行动项
- 17 会话时间线统计：聚合 JSON 消息日期、活跃量与发送者
- 18 重复消息聚类：空白归一后的重复内容统计
- 19 触控序列异常诊断：按下、移动、松开、取消的缺失和重复检测
- 20 黑匣子事件聚类：JSONL 事件计数、时延/卡顿/密钥故障标记

## 候选源码（ZIP 内）

- `VeilLink/Core/VeilMissionControlEngine.swift` — 20 个确定性工具操作
- `VeilLink/UI/VeilMissionControlView.swift` — 20 项 UI 入口，后台线程运算，复制结果
- `VeilLinkTests/VeilMissionControlEngineTests.swift` — XCTest 候选
- `PATCH.diff` — 对上述三个新增文件的 add-only unified patch，在独立空工作树 git apply --check 通过

## 验证边界

Linux Swift Foundation 引擎编译和 20/20 样例运行通过，XCTest 源文件 typecheck 通过；iOS SDK、XcodeGen、真机、IPA 未运行。真实 BLE/多跳/传输/密钥功能未接入，这些是手动输入的纯计算分析器。

## Gate

Owner/Governor 取得上述完整源码 ZIP 并校验 SHA-256 → 在独立集成分支应用 ZIP 内 PATCH.diff → 完整 Xcode 编译/XCTest → iPhone 7 触控与布局回归 → 解决 PR #64–#66 后再接入工具中心。不得自动触发 IPA。


**Reason for staged GitHub scope:** the GitHub connector in this session accepts text content but does not import local container file bytes. A temporary file-service bridge was attempted and returned `container_session_expired`. Do not falsely claim the complete Swift patch is stored in GitHub. The full candidate source exists in the user-delivered ZIP with verified checksum; this branch contains the contract only. Owner can later attach that ZIP to an authorized integration workflow. Never commit the ZIP as an opaque binary to Inbox.
