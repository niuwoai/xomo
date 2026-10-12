# rc1808 Dodge/Burn/Sponge ROI

## 范围

Dodge、Burn 与 Sponge 之前复用 `retouchStrokeAlpha` 生成画布尺寸 alpha 数组，再逐像素扫描整张画布。普通笔划只改变笔触附近的像素。rc1808 为非气刷笔划生成紧凑 `StrokeMask`，将像素调整循环限制到其画布坐标 bounds；输出仍是完整画布，因此文档图层、合成与 Undo/Redo 语义不变。带气刷脉冲的 Dodge/Burn 暂留旧全帧路径，避免改变脉冲叠加行为。

## 回归

新增 `toneBrushStrokeMasksMatchFullFrameAtCenterAndCanvasEdge`，覆盖中心与左上边缘的压感/普通笔划，逐行比较 ROI alpha 与旧全帧 alpha，并验证 Dodge 的目标像素变化、ROI 外像素不变。`toneBrushAndSpongeROIBrushesRemainSingleUndoRedoTransactions` 确认两种操作各自产生一个撤销快照，Undo 恢复操作前 PNG，Redo 恢复编辑后 PNG。既有气刷渐变回归继续守住未改路径。

## 验证

- `ImageEditorToneAirbrushTests` 6/6、`ImageEditorToolSmokeTests` Sponge 相关 20/20、气刷兼容回归 3/3 通过；中心/画布边缘 ROI alpha 与旧全帧结果逐行一致，Dodge 与 Sponge 各自 Undo/Redo 集成通过。
- 发布合同 10/30 断言、CLI 发布构建合同 7/24、产品概览归档合同 3/30、隔离测试运行器合同通过；`git diff --check` 通过。
- rc1840 仍为下一次完整构建、全量测试、桌面冒烟与安装门槛；本版不覆盖 `/Applications`。
