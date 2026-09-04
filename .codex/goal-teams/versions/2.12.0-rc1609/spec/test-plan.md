# Test Plan

## 直接命令

- Direct Crop `100×80` 裁 `(20,10,50,40)`：同时覆盖完整保留、部分裁切、完全删除、顺序/元数据、选择回退及单事务 Undo/Redo。
- Crop to Selection：证明共同漏斗按提交后的选区像素 bounds 变换热点并使用专属 history。
- Trim Transparent：以可见层 bounds 驱动裁剪，验证热点不参与 trim bounds。
- Reveal All：用越界可见图层触发向左/下扩画布，热点等量平移、不缩放、不重排，Undo/Redo 往返。
- 只有越界热点时 Reveal 不可用；Reveal 遇到平移后仍完全越界的几何合法热点时也原子拒绝。
- 为 Crop 家族和 Reveal 注入 NaN/Infinity/零面积热点，验证文档、Undo/Redo、history、选择和面板完全不变。

## Automation

新增独立 `XomoAutomationHotspotCropRevealTests.swift`：覆盖 `xomo.canvas.crop_to_selection`，以及 `xomo.canvas.transform` 的 `cropCenter`、`trimTransparent`、`revealAll`，执行后通过 `xomo.hotspot.list` 验证共享入口。

## 相邻回归

- 整套 `ImageEditorCanvasCommandTests`。
- rc1607 Image Size 与 rc1608 Canvas Size 两套热点 Automation。
- 热点 HTML exporter、项目热点 round-trip、组件库系统箭头 cursor。
