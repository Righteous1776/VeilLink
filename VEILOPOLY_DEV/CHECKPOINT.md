# Veilopoly 开发断点（2026-11-06）

## 本分支起点

- 基于 `main@ccafebab147e069fbabfff579dbf323b0d54f191` 创建 `dev/veilopoly`。
- 本次提交仅创建独立研发区域及权限/任务文档；**没有改变 VeilLink 主产品源码、传输层、SQLite 或发布流程**。
- 此前在当前会话交付过独立 Swift Package 工程 `Veilopoly_P1-P4_checkpoint_20261106.zip`（约 214 KiB）；该 ZIP **尚未同步为 GitHub 本分支的 Swift 源码**。今后迁入应写入 `VEILOPOLY_DEV/Veilopoly/`，保留原始 docs、单测和 CC0 来源清单；不可声称此分支已包含 P1–P4 代码。

## 以前的本地验证记录（非 GitHub CI）

- Swift 6.2.1/Linux：已记录 24 个 XCTest 全部通过、无失败；
- 500 个种子的 AI 自动回合测试是有界模拟，每局至多 500 步，并非 500 局全部自然完局；
- SwiftUI / SpriteKit 及 iOS 16 真机验证**未完成**；
- P3 只有协议级 transport 抽象；P5 真实 VeilLink 对接**未授权**。

## 下次开始的唯一优先事项

1. 将当前会话交付的独立 Swift Package 源码/测试/规范/授权素材导入 `VEILOPOLY_DEV/Veilopoly/`；
2. 按哈希和文件表审计导入一致性，检查 .gitignore/资源许可证；
3. 用 iOS 16 SDK 编译运行，执行完整 XCTest、触摸和动画 ack 断点；
4. 将实际测试结果写入 `VEILOPOLY_DEV/reviews/`，再申请 P4 集成审查。

开发队列和授权边界以 `GOVERNANCE.md`、`ROADMAP.md` 为准。
