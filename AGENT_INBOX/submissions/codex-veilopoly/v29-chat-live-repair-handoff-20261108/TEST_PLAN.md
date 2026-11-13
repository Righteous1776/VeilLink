# 已执行与待执行

## 已执行（受测树 source_sha，不是只应用文本补丁）

- swift test --package-path VEILOPOLY_DEV/Veilopoly --jobs 2 → Linux378/378、0失败、97.173s → PASS
- 同包 --filter CurrentRoomRulesTests|LiveRoomTests →24/24、0失败 → PASS
- python3 scripts/test-verify-veilopoly-release.py →5/5 → PASS
- python3 scripts/test-verify-vertex-release.py →7/7（磁盘满导致一次 fixture setup 失败，清理旧临时构建缓存后重跑）→ PASS
- iOS15 frontend parse →语法检查通过，不是 SDK typecheck → PASS（仅语法）
- https://github.com/Righteous1776/VeilLink/actions/runs/42431674523 →完整 Apple CI SUCCESS → PASS
- 该 CI macOS 包测试 →378/378、58.514s → PASS
- 该 CI iOS Simulator 宿主 →916/916、180.422s，含6个新增真实桥接/fake通道测试 → PASS
- 该 CI UI smoke →1/1，仅首次启动诊断路径，不是聊天邀请 UI 自动点击验收 → PASS
- Simulator + unsigned iPhoneOS Release →编译成功 → PASS
- 实际 IPA 校验 →模型/原生框架、114项大富翁离线资源、大小、架构/OS、保护资产散列均通过 → PASS

最新修复候选 ZIP artifact13597897677，IPA50,999,437 bytes，App94,084,824 bytes。
IPA SHA256：399c5e5aac50b1c7dade8b35979b280629cb2c1723ce6760f297266ee2944ce9。
ZIP SHA256：8b9b2b4fe12aaf29ce972817e46843acae15ea698f461fbe487678c2f4194487。
下载：https://github.com/Righteous1776/VeilLink/actions/runs/42431674523/artifacts/13597897677
未签名，Owner 自备合法兼容的签名/安装方式；候选不是正式 Release。

## 待下一代理/Owner 复测

1. 两台设备安装上面同一份新修复候选；不要混用旧29.0/build66包。
2. 聊天“+ → 发送游戏邀请 → 大富翁”，对端不先开独立大厅也能在聊天接受/拒绝。
3. 接受后只呈现一个共享房间；新局双方每人25,000、银行2,000,000、V5地价/卡牌/金融一致。
4. 从聊天、聊天游戏面板、独立大厅继续，应是同一个房间/序号/存档；面板、贴图与单机一致。
5. 等待重连后无需再点邀请；未支持控制消息的对端显示明确错误，不能降级伪装成功。
6. 旧经典存档不改价；显式离开、保留A/B存档后重邀才是新V5局。
7. 后台重连、一笔客席股票/银行交易、恢复存档，不重复掷骰/扣款。

以上真实双机、BLE/LAN、iPhone触控/键盘/横屏路径均 NOT_RUN；不能拿 fake 测试冒充。
