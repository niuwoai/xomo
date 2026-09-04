# rc1615 Architecture Design

## 模型 helper

为 `ImageEditorSlice` 新增非可选 `transformedForOrthogonalCanvas(_:sourceCanvasSize:) throws`。它复用 `ImageEditorCanvasOrthogonalTransform`，但保留 Slice 的部分越界规则：

1. 验证 source canvas、raw frame 与标准化四边。
2. `standardizedFrame.integral.intersection(sourceBounds)` 验证源可见区及全部 preset。
3. 用完整浮点标准化 frame 套用五种既有公式。
4. 目标完整 frame 只执行一次 `.integral`，再与 target bounds 相交。
5. 验证目标 frame 及全部 preset，只替换 Slice frame。

错误使用 Slice 私有 geometry/preset 类型；不调用 `normalized`，不清洗 metadata，不返回 Optional。

## 事务接线

在 `ImageEditorViewModel.transformCanvas` 的现有 do/catch 中依次预计算 target canvas、稳定 `map` 的 Slices 与 Hotspots；随后预计算并校验 Layers。全部成功后才 `pushUndo()`，再一次写入 canvas/layers/slices/hotspots，协调 Slice scope、Hotspot 选择、尺寸控件并追加调用方 History。

## 后置

不改 Hotspot 严格源边界、UI、本地化、项目 schema、Automation payload、Selection/Alpha/Guide/Path 正交语义或通用 Canvas transaction 架构。
