# rc1613 Test Plan

## 新测试

- `ImageEditorSliceCropTransformTests.swift`：Direct Crop 的保留/裁切/删除、committed bounds、半像素负尺寸、源/目标 preset、删除前源校验、完整原子快照、scope 矩阵、单事务 Undo/Redo、Crop Center、Crop to Selection、Canvas Trim 与 Layer Trim 负向回归。
- `XomoAutomationSliceCropTrimTests.swift`：复用 `xomo.canvas.crop_to_selection` 与 canvas `trimTransparent`，通过 `xomo.slice.list` 和选中 Slice 导出计划验证共享入口。

## 关键夹具

- `100×80` 裁 `(20,10,50,40)`，同时覆盖完整保留、部分裁切、边界相切及完全越界移除。
- 反向小数裁剪框与负尺寸小数 Slice，验证 committed bounds、负尺寸标准化与最终裁切；非整数 offset 下的单次 integral 算法约束继续由 rc1612 helper 级回归证明。
- fixed width preset 使实际投影经历 `2→4→2→4`，证明 Crop、Undo、Redo 均重新投影。
- Canvas Trim 由 `(30,22,20,16)` 不透明图层决定，Slice 不参与 bounds，并分别保留、裁切和删除。

## 相邻回归

- 完整 `ImageEditorCanvasCommandTests` 与 Hotspot Crop/Reveal Automation。
- rc1611 Image Size、rc1612 Canvas Size 的 Slice 直接与 Automation 测试。
- Slice preset/export/project round-trip。
- 组件库系统箭头与真实画布平移 cursor。
- CLI/MCP、发布契约、隔离测试器和发布结构校验。

rc1613 不运行 rc1640 才要求的完整 Release、全量 UI 冒烟或 `/Applications` 覆盖。
