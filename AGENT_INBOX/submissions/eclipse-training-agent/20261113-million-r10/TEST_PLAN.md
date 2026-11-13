# 实际验证与剩余门

已经执行：

- 两份Owner FNV、种子FNV/SHA、逐手合法终局重放；片段隔离。
- D4完整棋谱族分组、跨集局面隔离、棋盘动作联合对称去重；最终1848616条实际拟合。
- 训练／验证参数选择与测试分离；48条独立规则teacher复核。
- 9024次编译Swift特征、浮点预测及整数分数对照，零差异。
- 82条真实最终模型战术检查；50盘面原始PR193与未启用模型的重构版本选择/评分/节点/PV一致。
- 100个独立盘面的同预算反事实原生决策，55个实际落子改变。
- 最终模型400盘同节点预算换色对战；另做等时间对战，结果见Arena/RESULTS。
- 四档420盘真实原生换色对战，独立Python重放零非法/截断。
- 完整生产GomokuBot→bridge→kernel→model编译和两色/四档/必胜必挡/预算/真实标签验证；编译前后源SHA一致。
- 6文件PATCH在main的git apply --check通过，在隔离目录实际应用并逐字读回6/6一致。

尚未执行（不能宣称完成）：

- Xcode/iOS SDK编译、完整现有XCTest、模拟器和实体iPhone运行。
- 真机CPU/内存/电池/热表现；完整宗师/V9/V10全预算与第三方强引擎的统计对战。
- Governor冲突裁决、产品分支应用、main合并或发行。

复现入口：FILES/Training/README.md、FILES/Arena/README.md、FILES/Difficulty/DIFFICULTY_REPORT.md、FILES/IntegrationTests/README.md。
