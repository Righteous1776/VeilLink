# M5 Known Limits

1. 语言与推理范围仅覆盖 VeilLink、SQLiteVault 的小型合成语法，不是通用中文模型。
2. 词元编码依赖显式领域词汇；同义改写、错别字、跨句指代和长上下文可能进入 `S_UNKNOWN` 或漏检。
3. 测试集满分源于任务窄、标签确定且语法受控；不得用作真实世界准确率声明。
4. 状态组合测试与训练组合隔离，但底层词项和规则语义相同，不能证明强组合泛化。
5. 推理器与 RNN 为 FP32；尚未进行 INT8 语言量化、NEON 优化或能耗测试。
6. 训练仍在 Python/NumPy 中完成；Native C 负责推理，不宣称 Native 训练。
7. Python 仍承担 tokenization、模型加载、渲染和 attestation 编排。
8. 当前渲染词表受限，无法生成自由形式长文本。
9. 未在 iPhone、ARM64、XCFramework、Accelerate 或真实 thermal 环境验证。
10. 未使用真实 VeilLink / SQLiteVault 标注数据；`REAL_WORLD_VALIDATION = NOT_PERFORMED`。
11. 模型没有数据库、BLE、消息、Agent 或游戏控制权限；`MUTATION_AUTHORITY = 0`。
12. M5 只能影子挂载，不能接管生产灵核。
