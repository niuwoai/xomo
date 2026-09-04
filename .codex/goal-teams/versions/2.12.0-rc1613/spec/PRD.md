# rc1613 PRD

## 目标

让所有缩画布 Crop 家族与 Canvas Trim 在同一事务中同步投影 Slice，并保证 Fireworks 风格交付元数据和 Sketch/Figma 式导出选择保持可用。

## 验收标准

1. Direct Crop、Crop Center、Crop to Selection 和 Canvas Trim 均按最终 committed pixel bounds 平移、裁切或移除 Slice。
2. 半像素、负尺寸和历史部分越界使用完整浮点标准化边，平移后只做一次 integral。
3. 源与目标最终 frame 双重校验 scale/width/height preset；非法几何或 preset 在 Undo 前整单拒绝。
4. 幸存顺序与全部元数据保持，nil 与显式空 preset 数组不互相改写。
5. valid/removed/nil/stale/empty Slice scope 正确协调，非 Slice scope 完整不变。
6. 单事务 Undo/Redo、Redo 清空和 Crop/Crop Selection/Trim 各自 History 不变。
7. Automation 复用现有真实入口，Slice list 与导出计划观察到相同结果；Layer Trim 负向回归不动 Slice。
