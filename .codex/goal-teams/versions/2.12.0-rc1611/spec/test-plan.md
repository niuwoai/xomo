# rc1611 Test Plan

## 新测试文件

- `ImageEditorSliceImageSizeTransformTests.swift`：模型几何、两 Slice 直接命令、三类 preset、选择协调、完整 Undo/Redo、Redo 清空、导出计划与损坏输入原子拒绝。
- `XomoAutomationSliceResizeTests.swift`：`xomo.canvas.resize_image` 后经 `xomo.slice.list` 验证真实共享入口，并检查 ViewModel 的 preset 与导出投影。

主矩阵使用 `320 × 240 → 160 × 480`，比例 `0.5 × 2`。frame `(20.4,40.4,64.4,38.6)` 与等价负尺寸 frame 均期待 `(10,80,33,78)`；preset 使用 width PNG 99、height JPEG 117、scale PDF 1，目标 resolved scales 分别为 3、1.5、1。

## 原子失败

覆盖非法源画布、零面积/NaN/无穷/溢出/完全越界 Slice、超限或不支持 preset，以及缩放后倍率越界。比较 document、Undo/Redo、History、Export Settings、面板、canvasOffset 与四个尺寸控件，仅允许失败状态改变。

## 相邻回归

- 完整 `ImageEditorCanvasCommandTests` 与 Hotspot Automation resize
- Guide、固定文本框非等比 Image Size
- Slice preset 增删/重排/约束/导出计划与项目 round-trip
- Figma Slice preset round-trip/selection
- 组件库系统箭头与生命周期 cursor
- CLI/MCP 与静态 release contracts

rc1611 不运行 rc1640 才要求的完整 Release、全量冒烟或 `/Applications` 覆盖。
