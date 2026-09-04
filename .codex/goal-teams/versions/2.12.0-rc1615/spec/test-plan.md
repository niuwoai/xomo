# rc1615 Test Plan

## 新测试

- `ImageEditorSliceOrthogonalTransformTests.swift`：五种精确几何、负尺寸小数、部分越界、metadata/Optional、preset 源/目标边界、scope 矩阵、完整原子失败及单事务 Undo/Redo。
- `XomoAutomationSliceOrthogonalTransformTests.swift`：五个现有 action 后通过 Slice list 与导出计划验证真实共享入口。

## 关键夹具

- 源画布 `100×80`，Slice `(30.75,24.25,-12.5,-8.5)`；期望 CW `(55,18,10,13)`、CCW `(15,69,10,13)`、180 `(69,55,13,10)`、FH `(69,15,13,10)`、FV `(18,55,13,10)`。
- 部分越界 `(-10.2,10.4,30.4,20.2)` 使用完整 frame 变换并最终裁切，证明不能先裁源。
- `40×20` Slice 在 CW 后成为 `20×40`；fixed width `9` 为源非法、`81` 为目标非法，fixed width `80` 命中目标 `4×` 边界。
- scope 用真实 90° frame 变化并断言倍率 `1→2`，避免只调用同步逻辑造成假绿。
- 原子快照覆盖 document、Undo/Redo、export settings、Hotspot 选择、六面板、canvas offset、anchor 与四个尺寸控件；status 单独断言。

## 相邻回归

- Hotspot Direct/Automation 正交测试。
- Slice Image Size、Canvas Size、Crop/Trim、Reveal All 及对应 Automation。
- Slice export/project round-trip、组件库 arrow/真实 pan cursor、CLI/MCP 与发布契约。

rc1615 非 rc1640 门禁，不执行 Release、全量 UI 冒烟或 `/Applications` 覆盖。
