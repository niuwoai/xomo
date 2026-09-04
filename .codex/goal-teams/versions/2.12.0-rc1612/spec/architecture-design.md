# rc1612 Architecture Design

## 模型层

- `ImageEditorSlice` 增加 `offsetForCanvasResize(offset:sourceCanvasSize:targetCanvasSize:) throws -> ImageEditorSlice?`。
- 先验证 raw/标准化几何、源画布整数可见交集与全部源 preset；再用完整浮点标准化边加 offset，一次 integral 后与目标求交。
- 空交集返回 nil 表示合法移除；存活项验证目标 preset 后只替换 frame。非法几何与 preset 使用独立错误分支抛出。
- 不调用 `normalized`，不抽取 Slice/Hotspot 泛型，避免扩大版本范围。

## 单事务接线

`resizeCanvas` 在 `pushUndo()` 前预计算全部 Slice 与 Hotspot，以及现有图层、参考线和其它画布状态。任一 Slice 抛错只设置既有 resize invalid 状态并返回；合法 nil 由 throwing compact map 移除。

成功后一次性写入 Slice 数组并调用现有非抛 Slice scope 协调；全部 preset 已在提交前验证，因此协调不会造成失败窗口。Undo/Redo 继续通过现有 Slice history 同步入口按恢复后的 frame 投影。
