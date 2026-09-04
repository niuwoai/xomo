# rc1614 Test Plan

## 新测试

- `ImageEditorSliceRevealAllTransformTests.swift`：右/上/左/四向扩展、历史部分越界重新显露、metadata/Optional 保真、preset 边界及源/目标非法、损坏/源全越界原子拒绝、Slice bounds 隔离、scope 矩阵、无 preset、单事务 Undo/Redo。
- `XomoAutomationSliceRevealAllTests.swift`：现有 Reveal action 后通过 Slice list 和导出计划验证真实共享入口。

## 关键夹具

- `100×80` 旧画布；四向可见层 `(-10,-6,130,96)` 产生 `130×96` target 与 `(10,6)` offset。
- 历史 Slice `(-20,16,60,20)` 在左扩 20px 后，从旧画布内可见 40px 恢复为完整 60px；同组验证 `exportPresets == nil` 与显式空数组保持可区分。
- 上述历史 Slice 的 fixed width `160` 命中源可见 frame 的 `4×` 合法边界，`161` 构成源非法；fixed width `10` 在源可见 frame 为 `0.25×` 合法、完整恢复后为 `1/6×`，构成目标非法。
- Undo/Redo 使用右侧历史 Slice `(95,20,20,10)`；左扩后目标裁为宽 5，fixed width `20` 的当前投影显式观察 `1→4→1→4`。
- scope 矩阵全部使用四向 offset `(10,6)`，并断言 Slice frame 从 `(10,20,20,10)`、`(40,20,10,10)` 实际移动为 `(20,26,20,10)`、`(50,26,10,10)`。
- Slice-only no-op 预置非空 Undo/Redo、Slice export scope、面板/锚点/尺寸控件状态，通过不含 status 的完整快照验证 Slice 不参与 Reveal bounds。

## 相邻回归

- Canvas Commands 与 Hotspot Crop/Reveal。
- rc1611 Image Size、rc1612 Canvas Size、rc1613 Crop/Trim 的 Slice 直接与 Automation 测试。
- Slice preset/export/project round-trip，以及组件库 arrow/真实 pan cursor。
- CLI/MCP、发布契约、隔离测试器与发布结构校验。

rc1614 不运行 rc1640 才要求的 Release、全量 UI 冒烟或 `/Applications` 覆盖。
