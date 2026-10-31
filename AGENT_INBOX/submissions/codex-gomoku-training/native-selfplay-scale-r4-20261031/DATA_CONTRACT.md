# 数据契约 — 真实原生自对弈、可追溯棋谱与导入

## A. 原始逐局 JSONL（研究数据；每行 1 场）

参考历史 `production_native_2000.jsonl` 的实际字段：`seed`、`moves`、`result`、`botDecisions`、`blackMode`、`whiteMode`、`budget`。在 R4 中建议**扩展**为：
- `schema`: `veillink.native-gomoku-match.v2`
- `game_id`: 引擎 SHA + 训练工作 id + seed + 先后手/算法 variant 的不可变唯一 ID
- `engine_sha`: 精确 Swift 实现 Git commit；`source_sha256`: 编译源文件 hash 列表
- `swift_version`, `build_flags`, `platform`, `budget`, `start_seed`, `opening_class`、`formation_black`、`formation_white`, `training_snapshot_hash`
- `moves`: `[0,224]` 棋盘索引数组（首手到终局）; `preset_moves`: 外部强制指定的开局手数（不能算 Bot 决策）
- `botDecisions`: 实际 `chooseMove` 返回并合法应用的次数 = `len(moves)-preset_moves`；每个不符合必须拒绝
- `result`: 兼容原 `humanWon` = 黑/host 胜，`aiWon` = 白/guest 胜，`draw` = 平局；`unfinished` 不进入已完成局数
- `status`, `elapsed_ms`, `move_nodes`, `terminal_ply`, `record_checksum`
- 原始数据必须保持合法走子次序，不能写入手机号、设备识别号、聊天数据或其他私人数据。

## B. 已存在的产品内置紧凑格式 v1（**兼容基线**）

```json
{
  "format": "veillink.native-gomoku-real-selfplay.v1",
  "engineRevision": "bc919b454379841180fb8698a9e0addec87e7af0",
  "count": 2000,
  "fnv1a64": "29e9808a4a69618b",
  "records": [{"s": 0, "r": "a", "m": "<BASE64_OF_MOVE_INDEX_BYTES>"}]
}
```

示例中 `m` 为字段占位符，**不是实际可重放记录**。`s` 为按从 0 递增的记录序号；`r` 是 `a` = 白/guest 胜、`h` = 黑/host 胜、`d` = 和棋；`m` 是每个手的 0..224 棋位索引一个 UInt8，然后整体 Base64。按**准确的** ASCII 文本 `"${s}|${r}|${m}\n"` 依次计算 FNV1a64，初值 `14695981039346656037`、乘数 `1099511628211`、无符号 UInt64 模 2^64。v1 产品校验器还要求 `engineRevision` 等于固定 SHA、`1 <= count <= 10000`、原始包 <3MB，随后按真实 `GomokuState.apply` 完全重放检查胜负。没有过校验的记录一律不能自动导入。**SHA-256 是额外完整性检查，不应把 FNV 误说成密码学签名。**

## C. 50k+ 数据不能只拼接 v1

先提出分片包/manifest 和版本升级建议，外部单局 ID 与批次 ID 双层防重；每一片 checksum、总清单 SHA-256；事务提交成功才计数。要兼容已有 `gomoku-native-selfplay-v1.json`、个人学习库和 Xiangqi 独立存储，不做破坏式覆盖或历史重置。不要无授权擅改数据库 schema、导入格式或信任边界。

## D. 样本量与标签口径

- `total_executed_attempts` 与 `complete_native_matches` 分开；异常局 0 有效。
- `unique_full_sequences` 对 move 串精确去重；`symmetry_unique_sequences` 须明确旋转/镜像归一方法；`unique_pre_move_positions` 按 canonical FNV/hash 统计。
- `training_label` 为真实规则终局结果，非模型推测价值；局面对应的已选走子可用于有监督排序或经验加权，但不能称为深度强化学习除非真的执行对应算法并评价。
- `count=2000`、`sha256=9f7ddf5c847d6beb972c5a98ad83daa66df189f82171988ac1da68d6142188e0` 仅对旧 v1 当前**原始字节文件**成立，不要对新数据复用旧哈希。
